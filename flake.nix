{
  outputs =
    { ... }:
    let
      pname = "selleaseagent";
      version = "1.1.3";

      indicatorUuid = "appindicatorsupport@rgcjonas.gmail.com";

      mkPackage =
        pkgs:
        let
          meta = {
            description = "Sellease desktop agent for monitoring and tracking";
            homepage = "https://www.sellease.us";
            license = pkgs.lib.licenses.unfree;
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
            mainProgram = pname;
            platforms = [ "x86_64-linux" ];
          };

          updater = pkgs.writeShellScript "selleaseagent-updater" ''
            echo "SelleaseAgent self-update is disabled on Nix; update the flake input instead." >&2
            exit 1
          '';

          restorePyInstallerEnv = ''
            if [ -n "''${LD_LIBRARY_PATH_ORIG+x}" ]; then
              export LD_LIBRARY_PATH="$LD_LIBRARY_PATH_ORIG"
            else
              unset LD_LIBRARY_PATH
            fi
            unset LD_LIBRARY_PATH_ORIG _PYI_ARCHIVE_FILE _PYI_APPLICATION_HOME_DIR \
              _PYI_PARENT_PROCESS_LEVEL _PYI_LINUX_PROCESS_NAME
          '';

          xdgOpen = pkgs.writeShellScriptBin "xdg-open" ''
            ${restorePyInstallerEnv}
            exec ${pkgs.xdg-utils}/bin/xdg-open "$@"
          '';

          browser = pkgs.writeShellScript "selleaseagent-browser" ''
            ${restorePyInstallerEnv}
            exec ''${SELLEASEAGENT_BROWSER:-${xdgOpen}/bin/xdg-open} "$@"
          '';

          launcher = pkgs.writeShellScript "selleaseagent-launcher" ''
            if [ -n "''${BROWSER:-}" ]; then
              export SELLEASEAGENT_BROWSER="''${BROWSER%%:*}"
            fi
            export BROWSER=${browser}
            exec ${pname} "$@"
          '';

          unwrapped = pkgs.stdenvNoCC.mkDerivation {
            pname = "${pname}-unwrapped";
            inherit version meta;

            src = ./SelleaseAgent.deb;

            strictDeps = true;
            dontConfigure = true;
            dontBuild = true;
            dontStrip = true;
            dontPatchELF = true;

            nativeBuildInputs = [
              pkgs.dpkg
            ];

            unpackPhase = ''
              runHook preUnpack
              dpkg-deb -x "$src" .
              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall

              install -Dm0755 usr/bin/selleaseagent "$out/bin/selleaseagent"
              install -Dm0755 ${updater} "$out/lib/selleaseagent/updater.sh"
              install -Dm0644 usr/share/icons/hicolor/256x256/apps/selleaseagent.png \
                "$out/share/icons/hicolor/256x256/apps/selleaseagent.png"

              runHook postInstall
            '';
          };

          desktopItem = pkgs.makeDesktopItem {
            name = pname;
            desktopName = "SelleaseAgent";
            comment = "SelleaseAgent Application";
            exec = pname;
            icon = pname;
            categories = [ "Utility" ];
            terminal = false;
          };
        in
        pkgs.buildFHSEnv {
          inherit pname version meta;

          targetPkgs = pkgs: [
            unwrapped
            xdgOpen

            pkgs.zlib
            pkgs.glib
            pkgs.dbus
            pkgs.fontconfig
            pkgs.freetype
            pkgs.libGL
            pkgs.libglvnd
            pkgs.mesa
            pkgs.libdrm
            pkgs.libxkbcommon
            pkgs.wayland
            pkgs.alsa-lib
            pkgs.libpulseaudio
            pkgs.gst_all_1.gstreamer
            pkgs.gst_all_1.gst-plugins-base

            pkgs.libx11
            pkgs.libxext
            pkgs.libxrender
            pkgs.libxi
            pkgs.libxfixes
            pkgs.libxcursor
            pkgs.libxrandr
            pkgs.libxinerama
            pkgs.libxtst
            pkgs.libxcomposite
            pkgs.libxdamage
            pkgs.libsm
            pkgs.libice
            pkgs.libxcb
            pkgs.libxcb-util
            pkgs.libxcb-image
            pkgs.libxcb-keysyms
            pkgs.libxcb-render-util
            pkgs.libxcb-wm
            pkgs.libxcb-cursor

            pkgs.coreutils
            pkgs.procps
            pkgs.iproute2
            pkgs.util-linux
            pkgs.pciutils
            pkgs.dmidecode
            pkgs.xdotool
            pkgs.wmctrl
            pkgs.x11vnc
            pkgs.xrandr
          ];

          extraBwrapArgs = [
            ''--tmpfs "$HOME/.config/autostart"''
          ];

          runScript = launcher;

          extraInstallCommands = ''
            install -Dm0644 ${desktopItem}/share/applications/${pname}.desktop \
              "$out/share/applications/${pname}.desktop"
            substituteInPlace "$out/share/applications/${pname}.desktop" \
              --replace-fail "Exec=${pname}" "Exec=$out/bin/${pname}"
            install -Dm0644 ${unwrapped}/share/icons/hicolor/256x256/apps/${pname}.png \
              "$out/share/icons/hicolor/256x256/apps/${pname}.png"
          '';
        };
    in
    {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.selleaseagent;

          gnomeEnabled = config.services.desktopManager.gnome.enable;

          package = mkPackage pkgs;
        in
        {
          options.programs.selleaseagent.enable = lib.mkEnableOption "SelleaseAgent with login autostart and a GNOME Shell tray icon";

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [
              package
            ]
            ++ lib.optional gnomeEnabled pkgs.gnomeExtensions.appindicator;

            environment.etc."xdg/autostart/${pname}.desktop".source =
              "${package}/share/applications/${pname}.desktop";

            programs.dconf = lib.mkIf gnomeEnabled {
              enable = true;
              profiles.user.databases = [
                { settings."org/gnome/shell".enabled-extensions = [ indicatorUuid ]; }
              ];
            };
          };
        };

      homeModules.default = {
        dconf.settings."org/gnome/shell".enabled-extensions = [ indicatorUuid ];
      };
    };
}
