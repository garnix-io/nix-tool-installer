{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/23.05";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        # { toolName: string, flakeLocation: string, testCommand: string } -> derivation
        # The derivation builds just one file which is the install script.
        # So you can copy the script to a web server and people can install nix and the given tool with:
        # $ curl -L https://example.com/install.sh | bash
        lib = { toolName, flakeLocation, testCommand }:
          pkgs.writeScript
            "installer"
            (pkgs.lib.replaceStrings
              [ "@@toolName@@" "@@flakeLocation@@" "@@testCommand@@" ]
              [ toolName flakeLocation testCommand ]
              (builtins.readFile ./install-template.sh));
        packages = {
          test-script = lib {
            toolName = "test-tool";
            flakeLocation = "github:nixos/nixpkgs/f098c1634d7bc427d9fe51e5f536c8aed65c1991#hello";
            testCommand = "hello";
          };
        };
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.vagrant
            ];
          };
        };
      }
    );
}
