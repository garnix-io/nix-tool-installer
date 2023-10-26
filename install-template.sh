#!/usr/bin/env sh

# This is the install script for '@@toolName@@'.

set -eu

test_nix_installation () {
  nix --version 1> /dev/null 2> /dev/null
}

install_nix () {
  TMP=$(mktemp -d)

  curl --proto '=https' --tlsv1.2 -sSfL https://install.determinate.systems/nix/tag/v0.14.0 -o "$TMP/install.sh"
  chmod u+x "$TMP/install.sh"

  "$TMP/install.sh" \
    install \
    --no-confirm \
    --extra-conf "extra-substituters = https://cache.garnix.io" \
    --extra-conf "extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

  set +eu
  # shellcheck source=/dev/null
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -eu
}

test_cache_configured () {
  nixConfig=$(nix --extra-experimental-features 'nix-command flakes' show-config) &&
  (echo "$nixConfig" | grep --quiet "^substituters.*cache\.garnix\.io") &&
  (echo "$nixConfig" | grep --quiet "^trusted-public-keys.*cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=") &&
  true
}

configure_cache () {
  echo extra-substituters = https://cache.garnix.io | sudo tee -a /etc/nix/nix.conf > /dev/null
  echo extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= | sudo tee -a /etc/nix/nix.conf > /dev/null

  echo trying to restart the nix-daemon...
  # This ignores errors, for single-user installations.
  if test "$(uname)" = "Linux" ; then
    sudo systemctl restart nix-daemon.service || true
  elif test "$(uname)" = "Darwin" ; then
    sudo launchctl kickstart -k system/org.nixos.nix-daemon || true
  else
    echo "Unknown system: $(uname)"
    echo Cancelling installation.
    exit 1
  fi
}

echo
echo NIX INSTALLATION
echo ================

if test_nix_installation; then
  echo Hooray, nix is already installed:
  nix --version
else
  echo \'@@toolName@@\' depends on nix, but it seems that you don\'t have a nix installation.
  echo This installer will run the default nix installer \(version 2.17.1\) for you.
  echo That installer will ask for your admin password to install nix.
  echo For more information, see: https://nixos.org/download
  echo
  printf "Should I install nix now? [y/n] "
  read -r SHOULD_INSTALL_NIX
  if test "$SHOULD_INSTALL_NIX" != y; then
    echo Cancelling installation.
    exit 1
  fi
  install_nix
  test_nix_installation || (echo "Failed to install nix, cancelling installation." && exit 1)
  echo nix is now installed:
  nix --version
fi

echo
echo BINARY CACHE CONFIGURATION
echo ==========================

if test_cache_configured; then
  echo Hooray, the garnix cache is configured.
else
  echo For \'@@toolName@@\' to work well, nix needs to use the garnix.io binary
  echo cache. But the cache configuration cannot be found. This
  echo installer will modify /etc/nix/nix.conf to add the garnix.io binary cache.
  echo
  printf "Should I add the garnix.io binary cache to /etc/nix/nix.conf now (requires sudo)? [y/n] "
  read -r SHOULD_CONFIGURE_CACHE
  if test "$SHOULD_CONFIGURE_CACHE" != y; then
    echo Cancelling installation.
    exit 1
  fi
  configure_cache
  test_cache_configured || (echo "Failed to configure the garnix cache, cancelling installation." && exit 1)
  echo The garnix cache is now configured.
fi

echo "installing '@@toolName@@'..."
nix --extra-experimental-features 'nix-command flakes' profile install -L "@@flakeLocation@@"
echo "testing '@@toolName@@' installation..."
@@testCommand@@

echo "Success! '@@toolName@@' is now installed."
