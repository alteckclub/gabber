{
  description = "Gabber - NixOS systemd services";

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

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
    }:
    let
      inherit (nixpkgs) lib;

      # Load workspaces
      engineWorkspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./engine; };

      # Create overlays with all Python packages from the workspaces
      engineOverlay = engineWorkspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
    in
    flake-utils.lib.eachDefaultSystem (system: {
      packages =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python312;

          # Build the Python package set with overlays for engine
          enginePythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  engineOverlay
                ]
              );

          # Build the virtual environments
          gabber-engine-venv = enginePythonSet.mkVirtualEnv "gabber-engine-env" engineWorkspace.deps.default;

          # For kitten-tts, use nixpkgs packages to avoid building pytorch from source
          # Based on uv export output from services/kitten-tts
          # Override Python packages to disable tests for problematic dependencies
          kitten-tts-python = python.override {
            packageOverrides = self: super: {
              # Disable tests for packages that fail during test phase
              mercantile = super.mercantile.overridePythonAttrs (old: { doCheck = false; });
              xyzservices = super.xyzservices.overridePythonAttrs (old: { doCheck = false; });
              bokeh = super.bokeh.overridePythonAttrs (old: { doCheck = false; });
              wandb = super.wandb.overridePythonAttrs (old: { doCheck = false; });
              spacy = super.spacy.overridePythonAttrs (old: { doCheck = false; });
            };
          };

          kitten-tts-venv = kitten-tts-python.withPackages (ps: with ps; [
            # Direct dependencies
            fastapi
            uvicorn
            pydantic
            numpy

            # PyTorch and related (from nixpkgs to avoid building)
            pytorch

            # KittenTTS dependencies (from wheel metadata)
            huggingface-hub
            onnxruntime
            soundfile
            spacy
            num2words
            misaki
            # espeakng_loader - skip, not directly imported

            # Additional transitive dependencies that might not be auto-included
            filelock
            fsspec
            requests
            phonemizer            
            pyyaml
            tqdm
            transformers
            typing-extensions
            packaging
            regex

            pip  # Need pip to install kittentts wheel
          ]);

          # Download the kittentts wheel
          kittentts-wheel = pkgs.fetchurl {
            url = "https://github.com/KittenML/KittenTTS/releases/download/0.1/kittentts-0.1.0-py3-none-any.whl";
            sha256 = "sha256-WkmEIuwnX130G4dZLGxILmNyMP1WMDkZckTTlm0c55M=";
          };

          # Python engine package - built with uv2nix
          gabber-engine = pkgs.stdenv.mkDerivation {
            pname = "gabber-engine";
            version = "0.1.0";
            src = ./engine;

            dontBuild = true;

            installPhase = ''
              mkdir -p $out/bin $out/share/gabber-engine

              # Copy the source code
              cp -r . $out/share/gabber-engine/

              # Create a wrapper that uses the virtual environment
              cat > $out/bin/gabber-engine <<EOF
              #!${pkgs.bash}/bin/bash
              export PYTHONPATH="${gabber-engine-venv}/${enginePythonSet.python.sitePackages}"
              exec ${enginePythonSet.python.interpreter} "$out/share/gabber-engine/gabber/main.py" "\$@"
              EOF
              chmod +x $out/bin/gabber-engine
            '';
          };

          # Frontend package - use buildNpmPackage for pure build
          gabber-frontend = pkgs.buildNpmPackage {
            pname = "gabber-frontend";
            version = "0.1.0";
            src = ./frontend;

            npmDepsHash = "sha256-hj4w+wYaN/pakEfFi5b+hYNiu2Y0k4dcESEyBUCWiAw=";

            # Install node_modules and build
            npmBuildScript = "build";

            installPhase = ''
              mkdir -p $out/share/gabber-frontend
              # Copy everything including node_modules and build artifacts
              cp -r . $out/share/gabber-frontend/
            '';
          };

          # Kitten TTS package - using nixpkgs Python packages
          kitten-tts = pkgs.stdenv.mkDerivation {
            pname = "kitten-tts";
            version = "0.1.0";
            src = ./services/kitten-tts;

            nativeBuildInputs = [ pkgs.unzip ];
            buildInputs = [ kitten-tts-venv ];

            buildPhase = ''
              # Create a site-packages directory for kittentts
              mkdir -p $out/${kitten-tts-python.sitePackages}

              # Unzip the wheel directly into site-packages
              # Wheels are just zip files
              cd $out/${kitten-tts-python.sitePackages}
              ${pkgs.unzip}/bin/unzip -q ${kittentts-wheel}
            '';

            installPhase = ''
              mkdir -p $out/bin $out/share/kitten-tts

              # Copy the source code
              cp -r $src/. $out/share/kitten-tts/

              # Create a wrapper that uses the nixpkgs Python environment with kittentts installed
              cat > $out/bin/kitten-tts <<EOF
              #!${pkgs.bash}/bin/bash
              export PYTHONPATH="$out/${kitten-tts-python.sitePackages}:${kitten-tts-venv}/${kitten-tts-python.sitePackages}"
              exec ${kitten-tts-venv}/bin/python "$out/share/kitten-tts/main.py"
              EOF
              chmod +x $out/bin/kitten-tts
            '';
          };
        in
        {
          inherit
            gabber-engine
            gabber-frontend
            kitten-tts
            gabber-engine-venv
            kitten-tts-venv
            ;
          default = gabber-engine;
        };
    })
    // {

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;

        let
          cfg = config.services.gabber;
          gabber-engine = self.packages.${pkgs.system}.gabber-engine;
          gabber-frontend = self.packages.${pkgs.system}.gabber-frontend.overrideAttrs {                
                  NEXT_PUBLIC_REPOSITORY_URL="https://${cfg.apiHost}";
                  NEXT_PUBLIC_EDITOR_URL="wss://${cfg.publicHost}/editor";
                };
          kitten-tts = self.packages.${pkgs.system}.kitten-tts;

        in
        {
          options.services.gabber = {
            enable = mkEnableOption "Gabber services";

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/gabber";
              description = "Directory for Gabber data storage";
            };

            secretFile = mkOption {
              type = types.path;
              default = "/var/lib/gabber/.secret";
              description = "Path to the secret file";
            };

            publicHost = mkOption {
              type = types.str;
              default = "localhost";
              description = "Public hostname for Gabber frontend";
            };

            apiHost = mkOption {
              type = types.str;
              default = "localhost";
              description = "Hostname for Gabber API";
            };

            localLlmHost = mkOption {
              type = types.str;
              default = "localhost";
              description = "Local LLM host";
            };

            user = mkOption {
              type = types.str;
              default = "gabber";
              description = "User to run Gabber services";
            };

            group = mkOption {
              type = types.str;
              default = "gabber";
              description = "Group to run Gabber services";
            };
          };

          config = mkIf cfg.enable {
            users.users.${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              createHome = true;
            };

            users.groups.${cfg.group} = { };

            # LiveKit service
            systemd.services.gabber-livekit = {
              description = "LiveKit Server for Gabber";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                ExecStart = "${pkgs.livekit}/bin/livekit-server --dev --bind 0.0.0.0";
                Restart = "on-failure";
                RestartSec = "5s";
                Environment = [
                  "LIVEKIT_LOG_LEVEL=INFO"
                ];
              };
            };

            # Editor service
            systemd.services.gabber-editor = {
              description = "Gabber Editor Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = "${gabber-engine}/share/gabber-engine";
                ExecStart = "${gabber-engine}/bin/gabber-engine editor";
                Restart = "on-failure";
                RestartSec = "5s";
                Environment = [
                  "GABBER_SECRET_FILE=${cfg.secretFile}"
                  "GABBER_REPOSITORY_DIR=${cfg.dataDir}/.gabber"
                ];
              };
            };

            # Repository service
            systemd.services.gabber-repository = {
              description = "Gabber Repository Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = "${gabber-engine}/share/gabber-engine";
                ExecStart = "${gabber-engine}/bin/gabber-engine repository";
                Restart = "on-failure";
                RestartSec = "5s";
                Environment = [
                  "GABBER_SECRET_FILE=${cfg.secretFile}"
                  "GABBER_REPOSITORY_DIR=${cfg.dataDir}/.gabber"
                  "LIVEKIT_URL=ws://localhost:7880"
                  "GABBER_PUBLIC_LIVEKIT_URL=wss://${cfg.apiHost}/"
                  "GABBER_PUBLIC_HOST=${cfg.publicHost}"
                ];
              };
            };

            # Engine service
            systemd.services.gabber-engine = {
              description = "Gabber Engine Service";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network.target"
                "gabber-livekit.service"
                "gabber-kitten-tts.service"
              ];
              requires = [ "gabber-livekit.service" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = "${gabber-engine}/share/gabber-engine";
                ExecStart = "${gabber-engine}/bin/gabber-engine engine";
                Restart = "on-failure";
                RestartSec = "5s";
                Environment = [
                  "GABBER_SECRET_FILE=${cfg.secretFile}"
                  "GABBER_REPOSITORY_DIR=${cfg.dataDir}/.gabber"
                  "LIVEKIT_URL=ws://localhost:7880"
                  "LOCAL_LLM_HOST=${cfg.localLlmHost}"
                  "KITTEN_TTS_HOST=localhost"
                ];
              };
            };

            # Kitten TTS service
            systemd.services.gabber-kitten-tts = {
              description = "Kitten TTS Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = "${kitten-tts}/share/kitten-tts";
                ExecStart = "${kitten-tts}/bin/kitten-tts";
                Restart = "on-failure";
                RestartSec = "5s";
              };
            };

            # Frontend service
            systemd.services.gabber-frontend = {
              description = "Gabber Frontend Service";
              wantedBy = [ "multi-user.target" ];
              after = [
                "network.target"
                "gabber-editor.service"
                "gabber-repository.service"
                "gabber-engine.service"
                "gabber-livekit.service"
              ];
              path = [ pkgs.bash ];
              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = "${gabber-frontend}/share/gabber-frontend";
                ExecStart = "${pkgs.nodejs_24}/bin/npm start";
                Restart = "on-failure";
                RestartSec = "5s";
              };
            };

            # Open firewall ports
            networking.firewall.allowedTCPPorts = [
              3000
              7880
              7881
              8000
              8001
            ];
            networking.firewall.allowedUDPPorts = [ 7882 ];
          };
        };
    };
}
