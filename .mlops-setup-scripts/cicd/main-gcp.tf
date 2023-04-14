# resource "databricks_group" "mlops-service-principal-group-staging" {
#   display_name = "gcp-mlops-service-principals"
#   provider     = databricks.staging
# }

# resource "databricks_group" "mlops-service-principal-group-prod" {
#   display_name = "gcp-mlops-service-principals"
#   provider     = databricks.prod
# }

# resource "google_project_iam_member" "service_account_token_creator" {
#   project = var.gcp-project-id
#   role  = "roles/iam.serviceAccountTokenCreator"
#   member  = "serviceAccount:${google_service_account.databricks_service_account.email}"
# }

locals {
  git_org_name  = split("/", var.github_repo_url)[length(split("/", var.github_repo_url)) - 2]
  git_repo_name = split("/", var.github_repo_url)[length(split("/", var.github_repo_url)) - 1]
}

resource "google_service_account" "github_action_service_account" {
  account_id   = "github-action-sa"
  display_name = "Service Account for Github Actions"
  project      = var.gcp-project-id
}

resource "google_project_iam_member" "github_action_service_account" {
  project = var.gcp-project-id
  for_each = toset([
    "roles/storage.objectViewer",
    "roles/storage.objectAdmin"
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.github_action_service_account.email}"
}

module "gh_oidc" {
  source      = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  project_id  = var.gcp-project-id
  pool_id     = "github-action-pool"
  provider_id = "github-action-provider"
  sa_mapping = {
    "github-action-sa" = {
      sa_name   = "projects/${var.gcp-project-id}/serviceAccounts/github-action-sa@${var.gcp-project-id}.iam.gserviceaccount.com"
      attribute = "attribute.repository/${local.git_org_name}/${local.git_repo_name}"
    }
  }
  depends_on = [
    google_service_account.github_action_service_account
  ]
}
module "gcp_create_sp" {
  # depends_on = [databricks_group.mlops-service-principal-group-staging, databricks_group.mlops-service-principal-group-prod]
  source = "./terraform-databricks-mlops-gcp-project-with-sp-creation"
  providers = {
    databricks.staging = databricks.staging
    databricks.prod    = databricks.prod
  }
  gcp-project-id               = var.gcp-project-id
  service_principal_name       = "gcp-mlops-cicd"
  project_directory_path       = "/gcp-mlops"
  service_principal_group_name = "gcp-mlops-service-principals"
}

data "databricks_current_user" "staging_user" {
  provider = databricks.staging
}

provider "databricks" {
  alias = "staging_sp"
  host  = "https://6837671528024691.1.gcp.databricks.com"
  token = module.gcp_create_sp.staging_service_principal_token
}

provider "databricks" {
  alias = "prod_sp"
  host  = "https://6837671528024691.1.gcp.databricks.com"
  token = module.gcp_create_sp.prod_service_principal_token
}

module "staging_workspace_cicd" {
  source = "./common"
  providers = {
    databricks = databricks.staging_sp
  }
  git_provider    = var.git_provider
  git_token       = var.git_token
  env             = "staging"
  github_repo_url = var.github_repo_url
  # depends_on = [
  #   databricks_group.mlops-service-principal-group-prod,
  #   databricks_group.mlops-service-principal-group-staging
  # ]
}

module "prod_workspace_cicd" {
  source = "./common"
  providers = {
    databricks = databricks.prod_sp
  }
  git_provider    = var.git_provider
  git_token       = var.git_token
  env             = "prod"
  github_repo_url = var.github_repo_url
}



data "google_project" "default" {
  project_id = var.gcp-project-id
}

output "GOOGLE_CLOUD_WORKLOAD_IDENTITY_PROVIDER" {
  value     = module.gh_oidc.provider_name
  sensitive = false
}

output "GOOGLE_CLOUD_SERVICE_ACCOUNT" {
  value     = google_service_account.github_action_service_account.email
  sensitive = false
}
// We produce the service principal API tokens as output, to enable
// extracting their values and storing them as secrets in your CI system
//
// If using GitHub Actions, you can create new repo secrets through Terraform as well
// e.g. using https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_secret

output "STAGING_WORKSPACE_TOKEN" {
  value     = module.gcp_create_sp.staging_service_principal_token
  sensitive = true
}

output "PROD_WORKSPACE_TOKEN" {
  value     = module.gcp_create_sp.prod_service_principal_token
  sensitive = true
}
