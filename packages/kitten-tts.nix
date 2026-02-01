# Kitten TTS service package
{ pkgs
, lib
, python312
}:

let
  # Fetch the kittentts wheel from GitHub releases
  # This hash needs to be updated after first build attempt
  kittenttsWheel = pkgs.fetchurl {
    url = "https://github.com/KittenML/KittenTTS/releases/download/0.1/kittentts-0.1.0-py3-none-any.whl";
    sha256 = "sha256-WkmEIuwnX130G4dZLGxILmNyMP1WMDkZckTTlm0c55M=";
  };

  # Build the kittentts package from the wheel
  kittentts = python312.pkgs.buildPythonPackage {
    pname = "kittentts";
    version = "0.1.0";
    src = kittenttsWheel;
    format = "wheel";

    # Wheel doesn't need building
    dontBuild = true;

    propagatedBuildInputs = with python312.pkgs; [
      torch
      transformers
      huggingface-hub
      safetensors
    ];

    # Skip tests as there are none in the wheel
    doCheck = false;
  };

  # Python environment with all dependencies
  pythonEnv = python312.withPackages (ps: with ps; [
    fastapi
    uvicorn
    pydantic
    numpy
    starlette
    kittentts
  ]);

in
pkgs.stdenv.mkDerivation {
  pname = "kitten-tts";
  version = "0.1.0";

  src = ../services/kitten-tts;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  buildInputs = [ pythonEnv ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/kitten-tts

    # Copy the main script
    cp main.py $out/lib/kitten-tts/

    # Create wrapper script
    makeWrapper ${pythonEnv}/bin/python $out/bin/kitten-tts \
      --add-flags "$out/lib/kitten-tts/main.py"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Kitten TTS service for Gabber";
    homepage = "https://github.com/KittenML/KittenTTS";
    license = licenses.unfree;
    platforms = platforms.linux;
    mainProgram = "kitten-tts";
  };
}
