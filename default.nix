{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  emacs ? pkgs.emacs,
  emacsPackages ? emacs.pkgs,
  melpaBuild ? emacsPackages.melpaBuild,
  magit-section ? emacsPackages.magit-section,
}:

melpaBuild {
  pname = "tokei";
  version = "0.2.1";
  src = lib.cleanSource ./.;
  packageRequires = [
    magit-section
  ];
  turnCompilationWarningToError = true;
}
