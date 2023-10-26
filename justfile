test-run-in-vagrant: test-setup
  #!/usr/bin/env bash

  set -eu

  nix run -L .#testFileServer &
  SERVER_PID=$!
  trap 'kill $SERVER_PID' SIGINT SIGTERM EXIT
  vagrant ssh -c "echo ; echo ; echo ; sh <(curl --tlsv1.2 -sSf http://192.168.56.1:8000/install.sh)"

test-setup:
  vagrant up

test-teardown:
  vagrant destroy --force
