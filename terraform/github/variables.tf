variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token (PAT). Можно оставить пустым и задать через env GITHUB_TOKEN"
  default     = ""
  sensitive   = true
}

variable "github_owner" {
  type        = string
  description = "Владелец (username или org). Можно оставить пустым — owner будет взят из токена (если провайдер сможет)"
  default     = ""
}

variable "repo_name" {
  type        = string
  description = "Название репозитория (например DevOps-Core-Course)"
  default     = "DevOps-Core-Course"
}

variable "repo_description" {
  type        = string
  description = "Описание репозитория"
  default     = "DevOps course repository managed by Terraform"
}

variable "visibility" {
  type        = string
  description = "public/private/internal"
  default     = "public"
}
