# -*- mode: ruby -*-
# Phase 1 starter. This is a skeleton — the provisioning is yours to write.

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"   # TODO: pick/justify your base box

  # TODO: forward a port so you can reach the app from your host browser.
  # config.vm.network "forwarded_port", guest: ????, host: ????

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048   # TODO: five services on one VM — is this enough?
    vb.cpus = 2
  end

  # TODO: provision the full stack here. Must be idempotent and require
  # ZERO manual steps after `vagrant up`.
  # config.vm.provision "shell", path: "provision/setup.sh"
end
