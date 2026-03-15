{ config, lib, pkgs, ... }:

let
  cfg = config.services.gabber;

  # Reference to the gabber flake packages
  # Users should pass these via specialArgs or overlays
  gabber-engine = cfg.package;
  gabber-frontend = cfg.frontendPackage;
  kitten-tts = cfg.kittenTtsPackage;
in
{
  options.services.gabber = {
    enable = lib.mkEnableOption "Gabber AI Engine";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The gabber-engine package to use";
    };

    frontendPackage = lib.mkOption {
      type = lib.types.package;
      description = "The gabber-frontend package to use";
    };

    kittenTtsPackage = lib.mkOption {
      type = lib.types.package;
      description = "The kitten-tts package to use";
    };

    repositoryDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/gabber";
      description = "Directory for storing graphs and data";
    };

    secretFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to secrets file containing API keys";
      default = "";
    };

    publicHost = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Public hostname for WebSocket connections";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "gabber";
      description = "User account under which Gabber runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "gabber";
      description = "Group under which Gabber runs";
    };

    livekit = {
      enable = lib.mkEnableOption "LiveKit server";

      url = lib.mkOption {
        type = lib.types.str;
        default = "ws://localhost:7880";
        description = "LiveKit WebSocket URL";
      };

      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "devkey";
        description = "LiveKit API key";
      };

      apiSecret = lib.mkOption {
        type = lib.types.str;
        default = "secret";
        description = "LiveKit API secret";
      };
    };

    kittenTts = {
      enable = lib.mkEnableOption "Kitten TTS service";

      host = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Host for Kitten TTS service";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 7003;
        description = "Port for Kitten TTS service";
      };

      cacheDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/cache/gabber/huggingface";
        description = "HuggingFace cache directory for TTS models";
      };
    };

    frontend = {
      enable = lib.mkEnableOption "Gabber frontend";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for the frontend web application";
      };

      repositoryUrl = lib.mkOption {
        type = lib.types.str;
        default = "ws://localhost:8001";
        description = "WebSocket URL for the repository service";
      };

      editorUrl = lib.mkOption {
        type = lib.types.str;
        default = "ws://localhost:8000";
        description = "WebSocket URL for the editor service";
      };
    };

    editor = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
        description = "Port for the graph editor server";
      };
    };

    repository = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 8001;
        description = "Port for the repository server";
      };
    };

    localLlm = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Host for local LLM service (optional)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.repositoryDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.repositoryDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.kittenTts.cacheDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # LiveKit server service
    systemd.services.gabber-livekit = lib.mkIf cfg.livekit.enable {
      description = "LiveKit server for Gabber";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.livekit}/bin/livekit-server --dev --bind=0.0.0.0";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # Editor service
    systemd.services.gabber-editor = {
      description = "Gabber Graph Editor Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        GABBER_SECRET_FILE = cfg.secretFile;
        GABBER_REPOSITORY_DIR = cfg.repositoryDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.repositoryDir;
        ExecStart = "${gabber-engine}/bin/gabber-engine editor --port ${toString cfg.editor.port}";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.repositoryDir ];
      };
    };

    # Repository service
    systemd.services.gabber-repository = {
      description = "Gabber Repository Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optional cfg.livekit.enable "gabber-livekit.service";
      requires = lib.optional cfg.livekit.enable "gabber-livekit.service";

      environment = {
        GABBER_SECRET_FILE = cfg.secretFile;
        GABBER_REPOSITORY_DIR = cfg.repositoryDir;
        LIVEKIT_URL = cfg.livekit.url;
        GABBER_PUBLIC_HOST = cfg.publicHost;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.repositoryDir;
        ExecStart = "${gabber-engine}/bin/gabber-engine repository";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.repositoryDir ];
      };
    };

    # Engine service
    systemd.services.gabber-engine = {
      description = "Gabber AI Engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optional cfg.livekit.enable "gabber-livekit.service";
      requires = lib.optional cfg.livekit.enable "gabber-livekit.service";

      environment = {
        GABBER_SECRET_FILE = cfg.secretFile;
        GABBER_REPOSITORY_DIR = cfg.repositoryDir;
        LIVEKIT_URL = cfg.livekit.url;
        LOCAL_LLM_HOST = cfg.localLlm.host;
        KITTEN_TTS_HOST = lib.mkIf cfg.kittenTts.enable "http://${cfg.kittenTts.host}:${toString cfg.kittenTts.port}";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.repositoryDir;
        ExecStart = "${gabber-engine}/bin/gabber-engine engine";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.repositoryDir ];
      };
    };

    # Kitten TTS service
    systemd.services.gabber-kitten-tts = lib.mkIf cfg.kittenTts.enable {
      description = "Kitten TTS Service for Gabber";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        HF_HOME = cfg.kittenTts.cacheDir;
        TRANSFORMERS_CACHE = cfg.kittenTts.cacheDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.kittenTts.cacheDir;
        ExecStart = "${kitten-tts}/bin/kitten-tts";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ cfg.kittenTts.cacheDir ];
      };
    };

    # Frontend service
    systemd.services.gabber-frontend = lib.mkIf cfg.frontend.enable {
      description = "Gabber Frontend Web Application";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "gabber-editor.service"
        "gabber-repository.service"
        "gabber-engine.service"
      ];
      requires = [
        "gabber-editor.service"
        "gabber-repository.service"
        "gabber-engine.service"
      ];

      environment = {
        PORT = toString cfg.frontend.port;
        HOSTNAME = "0.0.0.0";
        NEXT_PUBLIC_REPOSITORY_URL = cfg.frontend.repositoryUrl;
        NEXT_PUBLIC_EDITOR_URL = cfg.frontend.editorUrl;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${gabber-frontend}/bin/gabber-frontend";
        Restart = "on-failure";
        RestartSec = 5;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # Open firewall ports if needed
    networking.firewall = lib.mkIf config.networking.firewall.enable {
      allowedTCPPorts =
        lib.optional cfg.frontend.enable cfg.frontend.port
        ++ lib.optional cfg.livekit.enable 7880
        ++ lib.optional cfg.livekit.enable 7881
        ++ [ cfg.editor.port cfg.repository.port ]
        ++ lib.optional cfg.kittenTts.enable cfg.kittenTts.port;

      allowedUDPPorts = lib.optional cfg.livekit.enable 7882;
    };
  };
}
