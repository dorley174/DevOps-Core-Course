data "yandex_compute_image" "os" {
  family = var.image_family
}

resource "yandex_vpc_network" "lab_net" {
  name   = "${var.project_name}-net"
  labels = var.labels
}

resource "yandex_vpc_subnet" "lab_subnet" {
  name           = "${var.project_name}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.lab_net.id
  v4_cidr_blocks = [var.subnet_cidr]
  labels         = var.labels
}

resource "yandex_vpc_security_group" "vm_sg" {
  name        = "${var.project_name}-sg"
  description = "Security Group for Lab04 VM"
  network_id  = yandex_vpc_network.lab_net.id

  ingress {
    description    = "SSH from allowed CIDR"
    protocol       = "TCP"
    v4_cidr_blocks = [var.allowed_ssh_cidr]
    port           = 22
  }

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "App port (Flask)"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5000
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

  labels = var.labels
}

resource "yandex_compute_instance" "vm" {
  name        = "${var.project_name}-vm"
  platform_id = var.platform_id
  zone        = var.zone

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory_gb
    core_fraction = var.vm_core_fraction
  }

  scheduling_policy {
    preemptible = var.preemptible
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.id
      size     = var.disk_size_gb
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.vm_sg.id]
  }

  metadata = local.instance_metadata

  allow_stopping_for_update = true
  labels                    = var.labels
}
