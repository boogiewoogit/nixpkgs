{
  stdenv,
  lib,
  fetchFromGitHub,
  gobject-introspection,
  pkg-config,
  cairo,
  glib,
  readline,
  libsysprof-capture,
  spidermonkey_115,
  meson,
  mesonEmulatorHook,
  dbus,
  ninja,
  which,
  libxml2,
}:

stdenv.mkDerivation rec {
  pname = "cjs";
  version = "6.4.0";

  src = fetchFromGitHub {
    owner = "linuxmint";
    repo = "cjs";
    rev = version;
    hash = "sha256-2lkIWroOo3hxu9/L/Ty7CADzVrZ0ohyHVmm65NoNlD4=";
  };

  outputs = [
    "out"
    "dev"
  ];

  strictDeps = true;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    which # for locale detection
    libxml2 # for xml-stripblanks
    dbus # for dbus-run-session
    gobject-introspection
  ]
  ++ lib.optionals (!stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    mesonEmulatorHook
  ];

  buildInputs = [
    cairo
    readline
    libsysprof-capture
    spidermonkey_115
  ];

  propagatedBuildInputs = [
    glib
  ];

  mesonFlags = lib.optionals stdenv.hostPlatform.isMusl [
    "-Dprofiler=disabled"
  ];

  postPatch = ''
    patchShebangs --build build/choose-tests-locale.sh
  '';

  meta = with lib; {
    homepage = "https://github.com/linuxmint/cjs";
    description = "JavaScript bindings for Cinnamon";

    longDescription = ''
      This module contains JavaScript bindings based on gobject-introspection.
    '';

    license = with licenses; [
      gpl2Plus
      lgpl2Plus
      mit
      mpl11
    ];

    platforms = platforms.linux;
    teams = [ teams.cinnamon ];
  };
}
