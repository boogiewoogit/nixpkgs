{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  tailscale,
  gtk4,
  gobject-introspection,
  libadwaita,
}:

buildGoModule rec {
  pname = "trayscale";
  version = "0.18.1";

  src = fetchFromGitHub {
    owner = "DeedleFake";
    repo = "trayscale";
    tag = "v${version}";
    hash = "sha256-zbqn0BBL/r03lpZsHszooFkLolS4FdXM8JC6mSlNlVg=";
  };

  vendorHash = "sha256-FifYgTWDfUFQShon4PyiiA0UgSQPmwwRaLdEKJrOZcc=";

  subPackages = [ "cmd/trayscale" ];

  ldflags = [
    "-s"
    "-w"
    "-X=deedles.dev/trayscale/internal/version.version=${version}"
  ];

  nativeBuildInputs = [
    pkg-config
    gobject-introspection
    wrapGAppsHook4
  ];
  buildInputs = [
    gtk4
    libadwaita
  ];

  # there are no actual tests, and it takes 20 minutes to rebuild
  doCheck = false;

  postInstall = ''
    sh ./dist.sh install $out
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : "${tailscale}/bin")
  '';

  meta = {
    changelog = "https://github.com/DeedleFake/trayscale/releases/tag/${src.rev}";
    description = "Unofficial GUI wrapper around the Tailscale CLI client";
    homepage = "https://github.com/DeedleFake/trayscale";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ sikmir ];
    mainProgram = "trayscale";
    platforms = lib.platforms.unix;
  };
}
