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

  # Fetch espeakng-loader from PyPI (not in nixpkgs)
  espeakngLoader = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/de/1e/25ec5ab07528c0fbb215a61800a38eca05c8a99445515a02d7fa5debcb32/espeakng_loader-0.2.4-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "sha256-CHIbryfRPUYfa+bu2aZSd+cNaCNP9IT9i5iXsiLNy20=";
  };

  # Build espeakng-loader package
  espeakng-loader = python312.pkgs.buildPythonPackage {
    pname = "espeakng-loader";
    version = "0.2.4";
    src = espeakngLoader;
    format = "wheel";
    dontBuild = true;
    doCheck = false;
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
      num2words
      spacy
      phonemizer
      espeakng-loader
      misaki
      onnxruntime
      soundfile
      numpy
    ];

    nativeBuildInputs = with python312.pkgs; [
      setuptools
    ];

    # espeak-ng runtime dependency
    propagatedNativeBuildInputs = [ pkgs.espeak ];

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
