variable "project_name" {
  type        = string
  description = "Префикс/название для ресурсов Lab04"
  default     = "lab04"
}

variable "labels" {
  type        = map(string)
  description = "Лейблы Yandex Cloud (опционально)"
  default = {
    project = "lab04"
  }
}

# --- Yandex Cloud provider config ---

variable "cloud_id" {
  type        = string
  description = "YC cloud_id (можно оставить пустым и задать через env YC_CLOUD_ID)"
  default     = ""
}

variable "folder_id" {
  type        = string
  description = "YC folder_id (можно оставить пустым и задать через env YC_FOLDER_ID)"
  default     = "b1g82kdcn5grlmu79ano"
}

variable "zone" {
  type        = string
  description = "Зона доступности (например, ru-central1-a)"
  default     = "ru-central1-a"
}

variable "yc_token" {
  type        = string
  description = "OAuth/IAM токен (можно оставить пустым и задать через env YC_TOKEN)"
  default     = ""
  sensitive   = true
}

variable "service_account_key_file" {
  type        = string
  description = "Путь к JSON-ключу сервисного аккаунта (можно оставить пустым и задать через env YC_SERVICE_ACCOUNT_KEY_FILE)"
  default     = ""
  sensitive   = true
}

# --- Network / Security ---

variable "subnet_cidr" {
  type        = string
  description = "CIDR подсети"
  default     = "10.10.0.0/24"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR, откуда разрешён SSH (желательно ваш белый IP /32)"
  # Чтобы не заблокировать себя на первом запуске, оставляем дефолт открытым.
  # В отчёте лучше указать ваш IP/32.
  default = "0.0.0.0/0"
}

# --- VM ---

variable "image_family" {
  type        = string
  description = "Семейство образа (data.yandex_compute_image.family)"
  default     = "ubuntu-2404-lts"
}

variable "platform_id" {
  type        = string
  description = "Платформа VM"
  default     = "standard-v2"
}

variable "vm_cores" {
  type        = number
  description = "vCPU"
  default     = 2
}

variable "vm_memory_gb" {
  type        = number
  description = "RAM (GB)"
  default     = 1
}

variable "vm_core_fraction" {
  type        = number
  description = "Доля CPU (5/20/50/100). 20 часто дешевле"
  default     = 20
}

variable "disk_size_gb" {
  type        = number
  description = "Размер диска (GB)"
  default     = 10
}

variable "disk_type" {
  type        = string
  description = "Тип диска (например network-hdd / network-ssd)"
  default     = "network-hdd"
}

variable "preemptible" {
  type        = bool
  description = "Преемптивная VM (дешевле, но может выключаться)"
  default     = false
}

# --- SSH keys ---

variable "ssh_user" {
  type        = string
  description = "Пользователь в образе (для Ubuntu обычно ubuntu)"
  default     = "ubuntu"
}

variable "ssh_public_key" {
  type        = string
  description = "Содержимое публичного ключа (ssh-ed25519 AAAA... comment). Можно не задавать, если задаёте ssh_public_key_path"
  default     = ""
}

variable "ssh_public_key_path" {
  type        = string
  description = "Путь к публичному ключу (например ~/.ssh/id_ed25519.pub). Используется, если ssh_public_key пустой"
  default     = ""
}
