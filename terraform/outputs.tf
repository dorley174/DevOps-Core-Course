output "vm_id" {
  value       = yandex_compute_instance.vm.id
  description = "ID виртуальной машины"
}

output "internal_ip" {
  value       = yandex_compute_instance.vm.network_interface[0].ip_address
  description = "Внутренний IP (в подсети)"
}

output "public_ip" {
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
  description = "Публичный IP (NAT)"
}

output "ssh_command" {
  description = "Команда для подключения по SSH (подставьте путь к приватному ключу)"
  value       = "ssh -i ~/.ssh/id_ed25519 ${var.ssh_user}@${yandex_compute_instance.vm.network_interface[0].nat_ip_address}"
}

output "http_url" {
  description = "URL для HTTP (если вы поставите веб-сервер на VM)"
  value       = "http://${yandex_compute_instance.vm.network_interface[0].nat_ip_address}/"
}

output "app_url" {
  description = "URL для приложения на 5000 порту (если вы его запустите)"
  value       = "http://${yandex_compute_instance.vm.network_interface[0].nat_ip_address}:5000/"
}
