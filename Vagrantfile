Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "lab05"

  # Disable project folder sharing inside the VM.
  # This avoids common Windows path issues (spaces, Cyrillic characters)
  # and is not needed for this lab workflow.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Forward ports to the Windows host.
  # host_ip "0.0.0.0" lets WSL2 reach the forwarded ports through the host.
  config.vm.network "forwarded_port", guest: 22, host: 2222, host_ip: "0.0.0.0", id: "ssh", auto_correct: true
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "0.0.0.0", id: "app", auto_correct: true

  config.ssh.insert_key = true

  config.vm.provider "virtualbox" do |vb|
    vb.name = "lab05-ansible"
    vb.memory = 2048
    vb.cpus = 2
  end
end
