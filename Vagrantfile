Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "lab05"

  # ВАЖНО: отключаем шаринг папки проекта в VM
  # (часто ломается из-за кириллицы/пробелов в пути + нам не нужен репозиторий в VM)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Пробрасываем порты на Windows-хост
  # host_ip "0.0.0.0" нужно, чтобы WSL мог подключиться к проброшенному порту через IP Windows-хоста.
  config.vm.network "forwarded_port", guest: 22, host: 2222, host_ip: "0.0.0.0", id: "ssh", auto_correct: true
  config.vm.network "forwarded_port", guest: 5000, host: 5000, host_ip: "0.0.0.0", id: "app", auto_correct: true

  config.ssh.insert_key = true

  config.vm.provider "virtualbox" do |vb|
    vb.name = "lab05-ansible"
    vb.memory = 2048
    vb.cpus = 2
  end
end
