terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      # Не фиксируем точную версию, чтобы не ломаться при обновлениях.
      # При желании можно зафиксировать (например, ">= 0.170.0").
      version = ">= 0.100.0"
    }
  }
}
