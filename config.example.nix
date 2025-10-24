{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.gabber = {
    enable = true;
    apiHost = "api.gabber.example.com";
    publicHost = "gabber.example.com";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts = with config.private; {
      "api.gabber.${domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/.well-known/acme-challenge" = {
        };
        locations."/rtc" = {
          proxyWebsockets = true;
          proxyPass = "http://192.168.0.1:7880";
          extraConfig = ''
            allow 192.168.0.0/24;
            deny all;
          '';
        };
        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://192.168.0.1:8001";
          extraConfig = ''
            allow 192.168.0.0/24;
            deny all;
          '';
        };

      };
      "gabber.${domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/.well-known/acme-challenge" = {
        };
        locations."/editor" = {
          proxyWebsockets = true;
          proxyPass = "http://192.168.0.2:8000/ws";
          extraConfig = ''
            allow 192.168.0.0/24;
            deny all;
          '';
        };
        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://192.168.0.2:3000";

          extraConfig = ''
            allow 192.168.0.0/24;
            deny all;
          '';
        };
      };
    };
  };
}
