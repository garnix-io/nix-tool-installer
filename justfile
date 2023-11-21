test-run-in-vm: test-setup
  #!/usr/bin/env bash

  set -eu

  nix build -L .#exampleInstallerFiles
  nix run -L .#testFileServer &
  SERVER_PID=$!
  trap 'kill $SERVER_PID' SIGINT SIGTERM EXIT
  while ! nc -z localhost 8000; do
    sleep 0.1
  done
  nix run -L .#sshVm -- "echo ; echo ; echo ; sh <(curl --tlsv1.2 -sSf http://10.0.2.2:8000/install.sh)"

test-ssh: test-setup
  nix run -L .#sshVm

test-setup:
  #!/usr/bin/env bash

  set -eu

  if lsof -i tcp:2222; then
    echo Port 2222 is already in use...
    echo Assuming server is already running
    exit 0
  fi
  nix run -L .#bootVm

test-teardown:
  kill $(lsof -ti tcp:2222)
