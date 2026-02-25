output "repo_full_name" {
  value       = github_repository.course_repo.full_name
  description = "owner/name"
}

output "repo_url" {
  value       = github_repository.course_repo.html_url
  description = "URL репозитория"
}
