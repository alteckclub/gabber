# Gabber Engine package built with uv2nix
{ pkgs
, lib
, pythonSet
, workspace
, gabberEngineEnv
}:

pkgs.stdenv.mkDerivation {
  pname = "gabber-engine";
  version = "0.1.0";

  src = ../engine;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  buildInputs = [
    gabberEngineEnv
    pkgs.ffmpeg
    pkgs.git
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/gabber-engine

    # Copy the gabber package to the lib directory
    cp -r gabber $out/lib/gabber-engine/

    # Create wrapper script for the main CLI
    # PYTHONPATH includes both the package dir (for gabber imports)
    # and the gabber subdir (for services imports - main.py uses "from services import")
    makeWrapper ${gabberEngineEnv}/bin/python $out/bin/gabber-engine \
      --add-flags "-m gabber.main" \
      --prefix PATH : ${lib.makeBinPath [ pkgs.ffmpeg pkgs.git ]} \
      --set PYTHONPATH "$out/lib/gabber-engine:$out/lib/gabber-engine/gabber" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.vips pkgs.portaudio ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Gabber real-time AI engine";
    homepage = "https://github.com/gabber-dev/gabber";
    license = licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "gabber-engine";
  };
}
