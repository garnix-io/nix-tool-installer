test-run-in-vagrant: build-test-script
  vagrant ssh -c "echo ; echo ; echo ; /vagrant/test-script"

build-test-script:
  nix build -L .#test-script
  rm -f test-script
  cp result test-script
  chmod u+rw test-script

test-setup:
  vagrant up

test-teardown:
  vagrant destroy --force
