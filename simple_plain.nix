let
  /*
   * The terms used in the comments, terms used to refer to different things in
   * the Nix ecosystem, may be different from what the Nix community likes to
   * use. This is a consciuos choice, to make it easy for people to understand
   * the concepts, at least for those who are programmers, and for those who
   * are new to the Nix community. Specifically, the terms like `instantiate`,
   * `realise`, etc.  will not be used.
   */

  /*
   * Explicitly declare variables that refer to builtin features, to avoid
   * having to use `builtins` everytime. Although these are not necessary, it is
   * good to know which of the builtin features we depend on. Here "builtin"
   * means features compiled into the `nix` CLI.
   */
  currentSystem = builtins.currentSystem;
  derivation    = builtins.derivation;
  fetchGit      = builtins.fetchGit; # This will fail in Nix CLI versions below 2.0
  import        = builtins.import;
  toFile        = builtins.toFile;
  toString      = builtins.toString;

  # Use a specific version of Nixpkgs. We receive a `set` object.
  nixpkgs_set = fetchGit {
    url = "git@github.com:NixOS/nixpkgs.git";
    rev = "ce6aa13369b667ac2542593170993504932eb836";
  };

  # Evaluate the code in Nixpkgs. This returns a function.
  nixpkgs_function = import nixpkgs_set;

  # Execute the function to get the package definitions.
  nixpkgs_derivations = nixpkgs_function {};

  /*
   * Explicitly declare variables that hold the paths of the output of the
   * packages that we depend on. This is not necessary, and can be avoided by
   * using the following statement in the `in` block, below.
   *
   *     with nixpkgs_derivations
   *
   * And doing so will expose all package definitions to that block.
   * Consequently, those packages' paths can then be referenced in the
   * derivation with the following line.
   *
   *     inherit coreutils gcc;
   *
   * But it's better to not pollute the code with unnecessary names, and it's
   * also good to know exactly which parts of the package definiotn we are
   * using (paths here, vs. all the contents of the package definition).
   *
   * Moreover, since these varibles will be passed to the shell script, the
   * `builder`, it's better to use the `_path` suffix to signify what these
   * variables contain.
   *
   * Here we use the suffix `_xyz` in a variable's name to illustrate a
   * subtlety; please refer to the comments further below for an explanation of
   * that subtlety.
   */
  coreutils_path = toString nixpkgs_derivations.coreutils;
  gcc_xyz        = toString nixpkgs_derivations.gcc;

  /*
   * This is just an example that we can choose to keep the whole package
   * definition, instead of extracting just the path from it, and use the
   * package definition in other expressions, if we need to. Moreover, since we
   * don't need to use this package's path in our shell script, it's
   * unnecessary to extract and store its path in a variable.
   */
  bash = nixpkgs_derivations.bash;

  /*
   * Create a file by the name `builder.sh`, populate it with the contents of
   * the string we provide (as the second argument to `toFile`), store the file
   * in Nix Store with a unique name, and store the absolute path of that file
   * in the variable `builder`.
   *
   * Note that the values of the `$` variables used in the script are passed to
   * the script via environment variables; these variables do _not_ refer to
   * the Nix variables we declared above, even though they might be named the
   * same.
   *
   * To illustrate this subtle difference, above we have a Nix variable named
   * `gcc_xyz`, and we pass its value to the derivation, but choose to name the
   * derivation property as `gcc_path`. Hence, in the environment of the
   * builder, the environment variable will be named `gcc_path`.
   *
   * Those environment variables in the builder's environment are populated by
   * the `inherit` command we use in the derivation, below, or by explicitly
   * adding new poperties to the derivation.
   *
   * When writing shell scripts, make sure to use the safety mechanisms
   * provided by the shell used in the derivation's `builder` property. For
   * example, here we use `set -e` command to ensure that Bash shell stops
   * processing the script when it encounters an error, an we use `set -u` to
   * ensure that it's an error to use undefined variables.
   *
   * The next paragraph refers to the troubles you may experience if you use
   * the `nix repl` to try out the code. The `nix-build` command does not seem
   * to have this problem. When the build script gets too large, it's obviously
   * better to have it as separate file(s).
   *
   * It's better to specify the build script inline here, than to create a
   * separate file and include it using the relative path (e.g. `./builder.sh`)
   * in the `args` property of the derivation, below. Specifying the code here
   * is better since every change to the script will automatically force the
   * re-evaluation of our code. If the build script is specified in a separate
   * file, then a code change in that file does not get detected, and the older
   * (cached) version of the file gets used; and that leads to a lot of
   * anguish.
   *
   * Beware of using the `${variable_name}` construct in the inline build
   * script. Even though it's perfectly valid Bash syntax. The trouble is that
   * Nix considers this syntax insde strings as a placeholder, and replaces
   * this construct with the value of the Nix variable. If a Nix variable by
   * that name does not exist in your code, Nix throws an error. Thankfully,
   * the paths in Nix code are not allowed to contain whitespace, and other
   * characters that may cause trouble, hence it's safe to use just the
   * `$variable_name` construct (note the absence of `{` and `}`) in the inline
   * strings.
   */
  builder = toFile "builder.sh" ''

    # Exit on error
    set -e

    # Error on undefined variables
    set -u

    # Add path necessary to call `mkdir`.
    export PATH="$coreutils_path/bin":"$PATH"
    mkdir -p "$out"

    # Log/save the environment variables passed to us; for troubleshooting.
    export -p >> "$out"/exported_environment_variables.log

    # Add the compiler to the path, and build sources.
    export PATH="$gcc_path/bin":"$PATH"
    gcc -o "$out"/simple "$src"
  '';
in

  # This is _our_ package's definition.
  derivation {

    # Pass the value of coreutils_path as an environment variable
    inherit coreutils_path;

    # Pass the value of `gcc_xyz` variable, but name it `gcc_path` in the
    # builder's environment. This is just for illustrative purposes, as
    # described in the comment above.
    gcc_path = gcc_xyz;

    # These three are the only mandatory properties of a derivation
    name    = "simple";           # The name of our package
    system  = currentSystem;      # We're telling Nix that it's okay to build
                                  # our package on the "current" system,
                                  # whatever that might be; linux, darwin, etc.
    builder = "${bash}/bin/bash"; # This program will be used to build our
                                  # package. Note that the first `bash` here
                                  # refers to the package definition of Bash.
                                  # By using the `${}` construct inside the
                                  # string, we're extracting only the path of
                                  # where that package is (or, will be)
                                  # installed. So, it might have been better if
                                  # we had named the variable `bash_package`,
                                  # instead of just `bash`.

    # Pass the file containing our script as a command-line argument to the
    # `builder`, above.
    args = [ builder ];

    # Create a unique file in Nix store using the file simple.c, and pass its
    # absolute path to the `builder`, above, in an environment variable by the
    # name `src`.
    src = ./simple.c;
  }
