Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
  end
  config.vm.provision "shell", inline: <<-SHELL
    sudo echo 'vagrant ALL=(ALL:ALL) ALL' > /etc/sudoers.d/vagrant
  SHELL
end
