{ pkgs }:

let
  python = pkgs.python312;
  pythonPackages = python.pkgs;

  # zinolib is not in nixpkgs, package it from PyPI
  zinolib = pythonPackages.buildPythonPackage rec {
    pname = "zinolib";
    version = "1.3.4";
    format = "pyproject";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/d0/be/d8efee4e06bf41001b86968acfb9d45587dc73d774eb5dad0d37af412d2a/zinolib-1.3.4.tar.gz";
      sha256 = "0gzrdyi4n0z0l187qqs0g2xfql4q54zbcmx2wwfsrny39x7c83mj";
    };

    build-system = [
      pythonPackages.setuptools
      pythonPackages.setuptools-scm
    ];

    dependencies = [
      pythonPackages.pydantic
    ];

    # Tests require network access
    doCheck = false;

    meta = {
      description = "Python library for interfacing with Zino";
      homepage = "https://pypi.org/project/zinolib/";
      license = pkgs.lib.licenses.asl20;
    };
  };

in pythonPackages.buildPythonApplication rec {
  pname = "curitz";
  version = "0.9.22";
  format = "pyproject";

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/6b/2a/dbeca809adf8e0e64d8473e1f2dbc2e5f6f8cba1ced3de5e54df0b7e4a96/curitz-0.9.22.tar.gz";
    sha256 = "037njfppzifb6b2mjzp284g4p8g61jmidrsv73zgc818m9yyagy1";
  };

  build-system = [
    pythonPackages.setuptools
    pythonPackages.setuptools-scm
  ];

  dependencies = [
    zinolib
    pythonPackages.dnspython
  ];

  buildInputs = [ pkgs.ncurses ];

  # Tests require network access
  doCheck = false;

  # Disable runtime dependency check - curitz specifies zinolib<1.0 but works with 1.x
  dontCheckRuntimeDeps = true;

  # Wrap with proper ncurses/terminfo paths
  makeWrapperArgs = [
    "--prefix" "TERMINFO_DIRS" ":" "${pkgs.ncurses}/share/terminfo"
  ];

  # Patch to use terminal's default background color instead of black
  postPatch = ''
    substituteInPlace src/curitz/cli.py \
      --replace-warn "curses.start_color()" "curses.start_color(); curses.use_default_colors()" \
      --replace-warn "curses.COLOR_RED, curses.COLOR_BLACK)" "curses.COLOR_RED, -1)" \
      --replace-warn "curses.COLOR_YELLOW, curses.COLOR_BLACK)" "curses.COLOR_YELLOW, -1)" \
      --replace-warn "curses.COLOR_CYAN, curses.COLOR_BLACK)" "curses.COLOR_CYAN, -1)" \
      --replace-warn "curses.COLOR_GREEN, curses.COLOR_BLACK)" "curses.COLOR_GREEN, -1)"
  '';

  meta = {
    description = "Python ncurses terminal client to Zino";
    homepage = "https://pypi.org/project/curitz/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "curitz";
  };
}
