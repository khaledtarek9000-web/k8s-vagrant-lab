# Vagrantfile - single-node Kubernetes (minikube) for the iti_cicd project
# Requires: VirtualBox + Vagrant 2.3 or newer

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "k8s-lab"

  # Bigger disk (the default 10 GB is too small for Docker + Kubernetes)
  config.vm.disk :disk, size: "30GB", primary: true

  # App will be at http://127.0.0.1:8090 on your PC
  config.vm.network "forwarded_port", guest: 8082, host: 8090, host_ip: "127.0.0.1"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "k8s-lab"
    vb.memory = 6144
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "provision.sh", privileged: true
end
