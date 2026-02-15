{
  description = "CLI implementation of localsend";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      mkPackage =
        pkgs:
        let
          manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
        in
        pkgs.rustPlatform.buildRustPackage {
          pname = manifest.name;
          version = manifest.version;
          src = pkgs.lib.cleanSource (
            pkgs.lib.sources.sourceFilesBySuffices ./. [
              "Cargo.lock"
              "Cargo.toml"
              ".rs"
            ]
          );
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.stdenv.cc
          ];
          buildInputs = [ pkgs.openssl ];
          cargoLock.lockFile = ./Cargo.lock;
          meta.mainProgram = manifest.name;
        };
    in
    {
      overlays.default =
        final: prev:
        let
          pkg = mkPackage final;
        in
        {
          default = pkg;
        };
    }
    //
      flake-utils.lib.eachSystem
        [ flake-utils.lib.system.x86_64-linux flake-utils.lib.system.aarch64-linux ]
        (
          system:
          let
            pkgs = (
              import nixpkgs {
                inherit system;
                overlays = [ self.overlays.default ];
              }
            );
          in
          {
            devShells.default = pkgs.mkShell {
              inputsFrom = [ pkgs.default ];
              buildInputs = with pkgs; [
                rustc
                cargo
                clippy
                rust-analyzer
                rustfmt
                nixfmt-rfc-style
                treefmt
              ];
              # Environment variables
              RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
            };
            packages.default = pkgs.default;
            legacyPackages.pkgsStatic.default = pkgs.pkgsStatic.default;
            legacyPackages.pkgsCross = nixpkgs.lib.mapAttrs (_: v: {
              inherit (v) default;
              pkgsStatic = {
                # a horrible hack to avoid the whole pkgsCross.*.pkgsStatic mess
                default = v.default.overrideAttrs (_: {
                  env.RUSTFLAGS = "-C target-feature=+crt-static";
                });
              };
            }) pkgs.pkgsCross;
          }
        );
}
