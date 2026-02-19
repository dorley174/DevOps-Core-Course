provider "yandex" {
  # Можно передавать через переменные (terraform.tfvars), а можно через env:
  #   YC_CLOUD_ID, YC_FOLDER_ID, YC_TOKEN / YC_SERVICE_ACCOUNT_KEY_FILE
  # Если значения пустые, Terraform передаст null и провайдер попробует взять их из env.

  cloud_id  = var.cloud_id != "" ? var.cloud_id : null
  folder_id = var.folder_id != "" ? var.folder_id : null
  zone      = var.zone

  token                    = var.yc_token != "" ? var.yc_token : null
  service_account_key_file = var.service_account_key_file != "" ? var.service_account_key_file : null
}
