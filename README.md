# `nix-tool-installer`

`nix-tool-installer` is a flakified library that can be used to create install scripts for arbitrary nix-based tools.
Those install scripts will:

1. Check whether nix is installed, and install it, if not.
2. Install the given tool (using nix).

You can create an install script like this:

```nix
{
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-tool-installer.url = "github:garnix-io/nix-tool-installer";

  outputs = { self, flake-utils, nix-tool-installer }:
    flake-utils.lib.eachDefaultSystem (system:
      {
        packages = {
          default = nix-tool-installer.lib.${system}.mkInstallScript {
            toolName = "hello";
            flakeLocation = "github:nixos/nixpkgs#hello";
            testCommand = "hello";
          };
        };
      }
    );
}
```

And then build it with:

```bash
nix build
```

This will symlink the generated script in `result`.

Then you can e.g. host the install script on `https://example.com/install.sh` and have users run it with:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://example.com/install.sh | bash
```
