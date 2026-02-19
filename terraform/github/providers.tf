provider "github" {
  # Можно передать token/owner через переменные, либо через env:
  #   GITHUB_TOKEN
  #   GITHUB_OWNER (не всегда поддерживается, обычно owner задают в provider block)

  token = var.github_token != "" ? var.github_token : null
  owner = var.github_owner != "" ? var.github_owner : null
}
