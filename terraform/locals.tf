locals {
  # Можно задать ключ прямо строкой (ssh_public_key), а можно указать путь к файлу (ssh_public_key_path).
  # try(...) нужен, чтобы terraform validate проходил даже без файла.
  ssh_public_key_resolved = trimspace(coalesce(
    (var.ssh_public_key != "" ? var.ssh_public_key : null),
    try(file(var.ssh_public_key_path), null),
    ""
  ))

  instance_metadata = local.ssh_public_key_resolved != "" ? {
    # Формат, который ожидает cloud-init в образах YC: "user:ssh_public_key"
    # (см. офиц. примеры/доки)
    "ssh-keys" = "${var.ssh_user}:${local.ssh_public_key_resolved}"
  } : {}
}
