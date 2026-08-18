{
  description = "farbenbuilds/zslay - A pure Zig WebSocket parser (wslay port)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        isLinux = pkgs.stdenv.isLinux;
        pkgsMusl =
          if isLinux
          then pkgs.pkgsMusl
          else null;

        zig = inputs.zig-overlay.packages.${system}."0.16.0" or pkgs.zig;

        mkDevShell = p:
          p.mkShell {
            packages = [
              zig
              p.zls
              p.gnutar
              p.bzip2
              p.gzip
              p.xz
            ];
          };

        mkZigBuild = name: target: p:
          p.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            nativeBuildInputs = [zig];
            buildPhase = ''
              export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
              zig build -Doptimize=ReleaseFast ${
                if target != ""
                then "-Dtarget=${target}"
                else ""
              }
            '';
            installPhase = ''
              mkdir -p $out
              cp -r zig-out/* $out/ 2>/dev/null || true
            '';
          };
      in {
        formatter = pkgs.alejandra;

        checks =
          {
            test-default = pkgs.stdenv.mkDerivation {
              name = "zslay-test-default";
              src = ./.;
              nativeBuildInputs = [zig];
              buildPhase = ''
                export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
                zig build test --summary all
              '';
              installPhase = "touch $out";
            };
          }
          // pkgs.lib.optionalAttrs isLinux {
            test-musl = pkgsMusl.stdenv.mkDerivation {
              name = "zslay-test-musl";
              src = ./.;
              nativeBuildInputs = [zig];
              buildPhase = ''
                export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
                zig build test --summary all
              '';
              installPhase = "touch $out";
            };
          };

        devShells =
          {
            default = mkDevShell pkgs;
          }
          // pkgs.lib.optionalAttrs isLinux {
            musl = mkDevShell pkgsMusl;
          };

        packages =
          {
            default = mkZigBuild "zslay-default" "" pkgs;

            "windows-x86_64" = mkZigBuild "zslay-windows-x86_64" "x86_64-windows-gnu" pkgs;
            "macos-x86_64" = mkZigBuild "zslay-macos-x86_64" "x86_64-macos" pkgs;
            "macos-aarch64" = mkZigBuild "zslay-macos-aarch64" "aarch64-macos" pkgs;

            "linux-x86_64-gnu" = mkZigBuild "zslay-linux-x86_64-gnu" "x86_64-linux-gnu" pkgs;
            "linux-aarch64-gnu" = mkZigBuild "zslay-linux-aarch64-gnu" "aarch64-linux-gnu" pkgs;

            "linux-x86_64-musl" = mkZigBuild "zslay-linux-x86_64-musl" "x86_64-linux-musl" pkgs;
            "linux-aarch64-musl" = mkZigBuild "zslay-linux-aarch64-musl" "aarch64-linux-musl" pkgs;
          }
          // pkgs.lib.optionalAttrs isLinux {
            musl = pkgsMusl.stdenv.mkDerivation {
              name = "zslay-musl-native";
              src = ./.;
              nativeBuildInputs = [zig];
              buildPhase = ''
                export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
                zig build -Doptimize=ReleaseFast
              '';
              installPhase = ''
                mkdir -p $out
                cp -r zig-out/* $out/ 2>/dev/null || true
              '';
            };
          };
      };
    };
}
