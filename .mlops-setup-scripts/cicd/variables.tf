variable "git_token" {
  type        = string
  description = "Git token used to (1) checkout ML code to run during CI and (2) call back from Databricks -> GitHub Actions to trigger a model deployment CD workflow when automated model retraining completes. Must have read and write permissions on the Git repo containing the current ML project"
  sensitive   = true
  validation {
    condition     = length(var.git_token) > 0
    error_message = "The git_token variable cannot be empty"
  }
}

variable "git_provider" {
  type        = string
  description = "Hosted Git provider, as described in https://docs.databricks.com/dev-tools/api/latest/gitcredentials.html#operation/create-git-credential. For example, 'gitHub' if using GitHub."
  default     = "gitHub"
}

variable "staging_profile" {
  type        = string
  description = "Name of Databricks CLI profile on the current machine configured to run against the staging workspace"
  default     = "gcp-mlops-staging"
}

variable "prod_profile" {
  type        = string
  description = "Name of Databricks CLI profile on the current machine configured to run against the prod workspace"
  default     = "gcp-mlops-prod"
}

variable "github_repo_url" {
  type        = string
  description = "URL of the hosted git repo containing the current ML project, e.g. https://github.com/myorg/myrepo"
  validation {
    condition     = length(var.github_repo_url) > 0
    error_message = "The github_repo_url variable cannot be empty"
  }
}

variable "gcp-project-id" {
  type        = string
  description = "GCP Project ID."
}
