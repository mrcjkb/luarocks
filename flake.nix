{
  description = "devShell for Neovim Lua plugins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    gen-luarc,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem = {system, ...}: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            gen-luarc.overlays.default
            self.overlays.default
          ];
        };
        luarc = pkgs.mk-luarc {
          plugins = with pkgs.lua51Packages; [
            luafilesystem
          ];
        };
      in {
        legacyPackages = pkgs;
        packages = rec {
          default = luarocks_bootstrap;
          inherit (pkgs.luajitPackages) luarocks_bootstrap;
        };
        devShells.default = pkgs.luajitPackages.luarocks.overrideAttrs (oa: {
          name = "lua devShell";
          shellHook = ''
            ln -fs ${pkgs.luarc-to-json luarc} .luarc.json
          '';
          buildInputs =
            oa.buildInputs
            ++ (with pkgs; [
              lua-language-server
              alejandra
              (luajit.withPackages (luaPkgs:
                with luaPkgs; [
                  luarocks
                  luacheck
                  busted
                ]))
            ]);
        });
      };
      flake = {
        overlays = {
          luaPackage-override = luaself: luaprev: {
            luarocks_bootstrap = luaprev.luarocks_bootstrap.overrideAttrs (oa: {
              version = "dev";
              src = self;
            });
            luarocks = luaprev.luarocks.overrideAttrs (oa: {
              version = "dev";
              src = self;
              knownRockspec = ./luarocks-dev-1.rockspec;
            });
          };

          default = final: prev: let
            luaPackage-override = {
              packageOverrides = self.overlays.luaPackage-override;
            };
          in {
            lua5_1 = prev.lua5_1.override luaPackage-override;
            lua51Packages = prev.lua51Packages // final.lua5_1.pkgs;
            lua5_2 = prev.lua5_2.override luaPackage-override;
            lua52Packages = prev.lua52Packages // final.lua5_2.pkgs;
            lua5_3 = prev.lua5_3.override luaPackage-override;
            lua53Packages = prev.lua53Packages // final.lua5_3.pkgs;
            lua5_4 = prev.lua5_4.override luaPackage-override;
            lua54Packages = prev.lua54Packages // final.lua5_4.pkgs;
            luajit = prev.luajit.override luaPackage-override;
            luajitPackages = prev.luajitPackages // final.luajit.pkgs;
          };
        };
      };
    };
}
