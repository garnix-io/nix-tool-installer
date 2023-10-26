{
  description = "Install scripts for nix-based tools";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/23.05";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        # { toolName: string, baseUrl: string, flakeLocation: string, testCommand: string } -> derivation
        #
        # The derivation builds a set of files which contain the install script
        # and other needed files. So you can copy the files to a web server to
        # host the files and people can install nix and the given tool with:
        #
        # $ sh <(curl --proto '=https' --tlsv1.2 -sSf https://example.com/install.sh)
        #
        # Example usage:
        #   lib.mkInstallScriptFiles {
        #     toolName = "test-tool";
        #     baseUrl = "https://example.com";
        #     flakeLocation = "github:nixos/nixpkgs/f098c1634d7bc427d9fe51e5f536c8aed65c1991#hello";
        #     testCommand = "hello";
        #   }
        lib.mkInstallScriptFiles = { toolName, baseUrl, allowHttp ? false, flakeLocation, testCommand }:
          let
            files = {
              "install.sh" = pkgs.writeScript
                "install.sh"
                (pkgs.lib.replaceStrings
                  [
                    "@@toolName@@"
                    "@@baseUrl@@"
                    "@@flakeLocation@@"
                    "@@testCommand@@"
                    "@@additionalPrefix@@"
                    "@@forceHttpsOption@@"
                  ]
                  [
                    toolName
                    baseUrl
                    flakeLocation
                    testCommand
                    (if allowHttp then "export NIX_INSTALLER_FORCE_ALLOW_HTTP=true" else "")
                    (if allowHttp then "" else "--proto '=https'")
                  ]
                  (builtins.readFile ./install-template.sh));
              "nix-installer.sh" = pkgs.fetchurl {
                url = "https://github.com/DeterminateSystems/nix-installer/releases/download/v0.14.0/nix-installer.sh";
                hash = "sha256-zY5hgeiK1FvKag4db2XmS7rJrjEmn/aIul5sIgXEGE4=";
              };
            } //
            pkgs.lib.attrsets.mapAttrs'
              (name: hash: {
                inherit name;
                value = pkgs.fetchurl
                  {
                    url = "https://github.com/DeterminateSystems/nix-installer/releases/download/v0.14.0/${name}";
                    inherit hash;
                  };
              })
              {
                "nix-installer-x86_64-linux" = "sha256-1kqnlgk39OQmbw4ubewl586gw1JYYNzESIexjWWjKHs=";
                "nix-installer-aarch64-linux" = "sha256-wu/O7YGRrqNPHoaHW5wMfoiIsEvrlEA2FoIzphASxko=";
                "nix-installer-x86_64-darwin" = "sha256-PxttqPQ2BnAo8/KrL/W+zC8l0h1FC5y+n9XiSYJwJ2o=";
                "nix-installer-aarch64-darwin" = "sha256-DwjQsLVE3Nl9MmIlU14DGAXaHI7Ddm4jAI96ncukeQU=";
              };
          in
          pkgs.runCommand "install-files" { } (
            pkgs.lib.attrsets.foldlAttrs
              (acc: name: path: acc + "cp ${path} $out/${name}\n") "mkdir $out\n"
              files
          );
        packages = {
          exampleInstallerFiles = self.lib.${system}.mkInstallScriptFiles {
            toolName = "hello";
            baseUrl = "http://192.168.56.1:8000";
            allowHttp = true;
            flakeLocation = "github:nixos/nixpkgs/f098c1634d7bc427d9fe51e5f536c8aed65c1991#hello";
            testCommand = "hello";
          };
        };
        apps = {
          testFileServer = {
            type = "app";
            program =
              builtins.toString (pkgs.writeScript "test-file-server" ''
                cd ${packages.exampleInstallerFiles}
                exec ${pkgs.python3}/bin/python3 -m http.server 2> /dev/null
              '');
          };
        };
        checks = {
          shellCheck = pkgs.runCommand "shellcheck"
            { nativeBuildInputs = [ pkgs.shellcheck ]; }
            ''
              shellcheck ${packages.exampleInstallerFiles}/install.sh
              touch $out
            '';
        };
        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.shellcheck
              pkgs.vagrant
            ];
          };
        };
      }
    );
}
