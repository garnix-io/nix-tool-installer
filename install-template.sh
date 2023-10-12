#!/usr/bin/env bash

# This is the install script for '@@toolName@@'.

set -euo pipefail

install_nix () {
  tmp=$(mktemp -d)
  curl -L https://nixos.org/nix/install -o $tmp/install.sh
  chmod u+x $tmp/install.sh
  $tmp/install.sh --yes
  . /home/vagrant/.nix-profile/etc/profile.d/nix.sh
}

test_nix_installation () {
  which nix > /dev/null &&
  nix --version > /dev/null &&
  true
}

if test_nix_installation; then
  echo Hooray, nix is already installed:
  nix --version
else
  echo \'@@toolName@@\' depends on nix to be installed,
  echo but it seems that you don\'t have a nix installation.
  read -p 'Should I install nix now? [y/n] ' shouldInstallNix
  if [[ $shouldInstallNix != 'y' ]]; then
    echo Cancelling installation.
    exit 0
  fi
  install_nix
fi
test_nix_installation

echo TODO: adding caches...

echo installing \'@@toolName@@\'...
nix --extra-experimental-features 'nix-command flakes' profile install @@flakeLocation@@
echo testing \'@@toolName@@\' installation...
@@testCommand@@
