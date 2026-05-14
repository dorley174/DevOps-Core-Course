{ pkgs ? import <nixpkgs> {} }:

let
  app = import ./default.nix { inherit pkgs; };
in
pkgs.dockerTools.buildLayeredImage {
  name = "devops-info-service-nix";
  tag = "1.0.0";

  contents = [ app ];

  # Fixed timestamp is required for reproducible image tarballs.
  created = "1970-01-01T00:00:01Z";

  extraCommands = ''
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Cmd = [ "${app}/bin/devops-info-service" ];
    Env = [
      "HOST=0.0.0.0"
      "PORT=5000"
      "SERVICE_NAME=devops-info-service"
      "SERVICE_VERSION=1.0.0-nix-docker"
      "APP_ENV=lab18-nix-docker"
      "VISITS_FILE=/tmp/devops-info-service-visits"
    ];
    ExposedPorts = {
      "5000/tcp" = {};
    };
  };
}
