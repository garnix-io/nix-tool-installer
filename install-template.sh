#!/usr/bin/env bash

# This is the install script for '@@toolName@@'.

set -euo pipefail

test_nix_installation () {
  which nix > /dev/null
  nix --version > /dev/null
}

install_nix () {
  tmp=$(mktemp -d)
  echo "extra-substituters = https://cache.garnix.io" >> $tmp/nix-extra-config
  echo "extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" >> $tmp/nix-extra-config

  curl -L https://releases.nixos.org/nix/nix-2.17.1/install -o $tmp/install.sh
  chmod u+x $tmp/install.sh

  $tmp/install.sh --nix-extra-conf-file $tmp/nix-extra-config --daemon --yes

  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
}

if test_nix_installation; then
  echo Hooray, nix is already installed:
  nix --version
else
  echo \'@@toolName@@\' depends on nix, but it seems that you don\'t have a nix installation.
  read -p 'Should I install nix now? [y/n] ' shouldInstallNix
  if [[ $shouldInstallNix != 'y' ]]; then
    echo Cancelling installation.
    exit 0
  fi
  install_nix
fi
test_nix_installation
echo nix is now installed:
nix --version

echo TODO: testing binary cache...
# is there a good way to test whether a binary cache is configured and available?

echo installing \'@@toolName@@\'...
nix --extra-experimental-features 'nix-command flakes' profile install -L @@flakeLocation@@
echo testing \'@@toolName@@\' installation...
@@testCommand@@

echo Success! \'@@toolName@@\' is now installed.
