resource "github_repository" "course_repo" {
  name        = var.repo_name
  description = var.repo_description
  visibility  = var.visibility

  has_issues   = true
  has_projects = false
  has_wiki     = false

  # auto_init = true  # включите, если хотите создать repo с пустым коммитом
}
