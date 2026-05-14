{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    flask
    prometheus-client
  ]);
in
pkgs.stdenv.mkDerivation {
  pname = "devops-info-service";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/devops-info-service
    cp app.py $out/share/devops-info-service/app.py

    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python $out/bin/devops-info-service \
      --add-flags $out/share/devops-info-service/app.py \
      --set HOST 0.0.0.0 \
      --set PORT 5000 \
      --set SERVICE_NAME devops-info-service \
      --set SERVICE_VERSION 1.0.0-nix \
      --set APP_ENV lab18-nix \
      --set VISITS_FILE /tmp/devops-info-service-visits

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "DevOps Info Service built reproducibly with Nix";
    mainProgram = "devops-info-service";
    platforms = platforms.linux;
  };
}
