# sellease-flake

## NixOS

```nix
{
  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    sellease-flake.url = "github:kimhappy/sellease-flake";
  };

  outputs = { nixpkgs, sellease-flake, ... }: {
    nixosConfigurations.mymachine = nixpkgs.lib.nixosSystem {
      system  = "x86_64-linux";
      modules = [
        sellease-flake.nixosModules.default
        {
          nixpkgs.config.allowUnfree  = true;
          programs.selleaseagent.enable = true;
        }
      ];
    };
  };
}
```

### Home Manager

Home Manager's own `enabled-extensions` shadows the system-wide default, so
import this module to merge the AppIndicator extension into its list:

```nix
{
  imports = [ sellease-flake.homeModules.default ];
}
```
