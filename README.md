Learn Plain Nix Packaging
=========================

The file `simple_plain.nix` contains code, and comments explaining the code,
that shows how the plain Nix language can be used to create your own packages.

Use the command `nix-build simple_plain.nix` to build and install the package
defined in `simple_plain.nix`.

Reason
------

The Nix language has some great abilities, but also some unintuitive features.
The Nixpkgs, the de-facto library of Nix packages, abuses the unintuitive
features extensively, and witout adhering to any standards, so the code in
Nixpkgs discourages newcomers from trying to write their own packages in Nix.
In other words, the `stdenv` of Nixpkgs, despite its name, has no "standards",
or very low standards.

The problem is exacerbated by new/cryptic terms (e.g. derivation,
instantiation, etc.), and the tools, like nix-shell, that fail to provide a
clean working environment for developing Nix packages; even `nix-shell --pure`
does not provide you with a clean-enough environment.

Solution
--------

The code in this project serves to show that one can use the plain Nix
language, the builtin features, and _some_ of its command-line utilities, to
create one's own packages, in a clean environment. This project also aims to
_not_ use the cryptic terms for explanations.

