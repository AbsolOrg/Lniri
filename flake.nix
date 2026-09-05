{
  description = "Lniri: A scrollable-tiling Wayland compositor with Liquid Glass effects";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});

      lniriPackage =
        pkgs:
        let
          rustPlatform = pkgs.rustPlatform;
        in
        rustPlatform.buildRustPackage {
          pname = "lniri";
          version = "26.4.0";

          src = lib.fileset.toSource {
            root = ./.;
            fileset = lib.fileset.unions [
              ./niri-config
              ./niri-ipc
              ./niri-visual-tests
              ./resources
              ./src
              ./Cargo.toml
              ./Cargo.lock
            ];
          };

          postPatch = ''
            patchShebangs resources/lniri-session resources/niri-session
            substituteInPlace resources/lniri.service \
              --replace-fail 'ExecStart=/usr/local/bin/lniri' "ExecStart=$out/bin/lniri"
          '';

          cargoLock = {
            allowBuiltinFetchGit = true;
            lockFile = ./Cargo.lock;
          };

          strictDeps = true;

          nativeBuildInputs = [
            rustPlatform.bindgenHook
            pkgs.pkg-config
            pkgs.installShellFiles
          ];

          buildInputs = [
            pkgs.cairo
            pkgs.dbus
            pkgs.libGL
            pkgs.libdisplay-info
            pkgs.libinput
            pkgs.seatd
            pkgs.libxkbcommon
            pkgs.libgbm
            pkgs.pango
            pkgs.pipewire
            pkgs.systemd
            pkgs.wayland
          ];

          postInstall = ''
            installShellCompletion --cmd lniri \
              --bash <($out/bin/lniri completions bash) \
              --fish <($out/bin/lniri completions fish) \
              --nushell <($out/bin/lniri completions nushell) \
              --zsh <($out/bin/lniri completions zsh)

            ln -s $out/bin/lniri $out/bin/Lniri
            install -Dm644 resources/lniri.desktop -t $out/share/wayland-sessions
            install -Dm644 resources/lniri-portals.conf -t $out/share/xdg-desktop-portal
            install -Dm755 resources/lniri-session $out/bin/lniri-session
            install -Dm644 resources/lniri{.service,-shutdown.target} -t $out/lib/systemd/user
          '';

          env = {
            RUSTFLAGS = toString (
              map (arg: "-C link-arg=" + arg) [
                "-Wl,--push-state,--no-as-needed"
                "-lEGL"
                "-lwayland-client"
                "-Wl,--pop-state"
              ]
            );
          };

          meta = with lib; {
            description = "A scrollable-tiling Wayland compositor with Liquid Glass effects";
            homepage = "https://github.com/AbsolOrg/Lniri";
            license = licenses.gpl3Plus;
            mainProgram = "lniri";
            platforms = platforms.linux;
          };
        };

      packagesFor = system: rec {
        lniri = lniriPackage pkgsFor.${system};
        niri-glass = lniri;
        default = lniri;
      };
    in
    {
      packages = forAllSystems packagesFor;

      apps = forAllSystems (
        system:
        let
          pkgs = (packagesFor system).lniri;
        in
        {
          default = {
            type = "app";
            program = "${pkgs}/bin/lniri";
            meta.description = "Run the Lniri compositor";
          };
          lniri-session = {
            type = "app";
            program = "${pkgs}/bin/lniri-session";
            meta.description = "Run Lniri as a systemd user session";
          };
        }
      );

      overlays.default = final: _prev: {
        lniri = lniriPackage final;
        niri-glass = lniriPackage final;
      };

      nixosModules.default = import ./nix/nixos-module.nix self;
      homeManagerModules.default = import ./nix/home-manager-module.nix self;
    };
}
