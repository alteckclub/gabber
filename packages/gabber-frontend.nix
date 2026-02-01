# Gabber Frontend package built with buildNpmPackage
{ pkgs
, lib
, nodejs
}:

pkgs.buildNpmPackage {
  pname = "gabber-frontend";
  version = "0.1.0";

  src = ../frontend;

  # This hash needs to be updated after first build attempt
  # Run: nix build .#gabber-frontend 2>&1 | grep "got:"
  npmDepsHash = "sha256-ZV3C2LwcEpSXJoeEC3GWTHsVchL4POz9UC72b4RzqGA=";

  nodejs = nodejs;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # Enable standalone output in next.config.ts during build
  preBuild = ''
    # Enable standalone output mode for production deployment
    sed -i 's|// output: "standalone"|output: "standalone"|' next.config.ts
  '';

  buildPhase = ''
    runHook preBuild

    # Set production environment for optimized build
    export NODE_ENV=production
    npm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/gabber-frontend
    mkdir -p $out/bin

    # Copy the standalone build output
    cp -r .next/standalone/* $out/lib/gabber-frontend/

    # Copy static assets that Next.js standalone doesn't include
    mkdir -p $out/lib/gabber-frontend/.next/static
    cp -r .next/static/* $out/lib/gabber-frontend/.next/static/

    # Copy public assets if they exist
    if [ -d public ]; then
      cp -r public $out/lib/gabber-frontend/
    fi

    # Create wrapper script to start the server
    makeWrapper ${nodejs}/bin/node $out/bin/gabber-frontend \
      --add-flags "$out/lib/gabber-frontend/server.js" \
      --set NODE_ENV "production"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Gabber frontend web application";
    homepage = "https://github.com/gabber-dev/gabber";
    license = licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "gabber-frontend";
  };
}
