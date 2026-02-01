{
  description = "Gabber - Real-time AI Engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        lib = pkgs.lib;

        # uv2nix workspace for the engine
        workspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = ./engine;
        };

        # Create overlay from workspace
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        # Python package set with overlay
        python = pkgs.python312;
        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              lib.composeManyExtensions [
                pyproject-build-systems.overlays.default
                overlay
                # Custom overrides for native dependencies
                (final: prev: {
                  gabber-engine = prev.gabber-engine.overrideAttrs (old: {
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                      pkgs.pkg-config
                    ];
                    buildInputs = (old.buildInputs or [ ]) ++ [
                      pkgs.vips
                      pkgs.portaudio
                    ];
                  });

                  # Override pyvips to find libvips
                  pyvips = prev.pyvips.overrideAttrs (old: {
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                      pkgs.pkg-config
                    ];
                    buildInputs = (old.buildInputs or [ ]) ++ [
                      pkgs.vips
                      pkgs.glib
                    ];
                  });

                  # Override opencv-python-headless
                  opencv-python-headless = prev.opencv-python-headless.overrideAttrs (old: {
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                      pkgs.pkg-config
                      pkgs.cmake
                    ];
                    buildInputs = (old.buildInputs or [ ]) ++ [
                      pkgs.opencv
                    ];
                  });
                })
              ]
            );

        # Build the virtual environment for gabber-engine
        gabberEngineEnv = pythonSet.mkVirtualEnv "gabber-engine-env" workspace.deps.default;

        # Import packages from separate files
        gabber-engine = pkgs.callPackage ./packages/gabber-engine.nix {
          inherit pkgs lib pythonSet workspace gabberEngineEnv;
        };

        gabber-frontend = pkgs.callPackage ./packages/gabber-frontend.nix {
          inherit pkgs lib;
          nodejs = pkgs.nodejs_20;
        };

        kitten-tts = pkgs.callPackage ./packages/kitten-tts.nix {
          inherit pkgs lib;
          python312 = pkgs.python312;
        };

      in
      {
        packages = {
          inherit gabber-engine gabber-frontend kitten-tts;
          default = gabber-engine;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.uv
            pkgs.python312
            pkgs.nodejs_20
            pkgs.ffmpeg
            pkgs.portaudio
            pkgs.vips
            pkgs.pkg-config
            pkgs.git
          ];

          shellHook = ''
            echo "Gabber development shell"
            echo "Run 'uv sync' in engine/ to install Python dependencies"
            echo "Run 'npm install' in frontend/ to install Node dependencies"
          '';
        };
      }
    ) // {
      # NixOS module
      nixosModules.default = import ./modules/gabber.nix;
      nixosModules.gabber = import ./modules/gabber.nix;

      # Overlay to make packages available
      overlays.default = final: prev: {
        gabber-engine = self.packages.${prev.system}.gabber-engine;
        gabber-frontend = self.packages.${prev.system}.gabber-frontend;
        kitten-tts = self.packages.${prev.system}.kitten-tts;
      };
    };
}
