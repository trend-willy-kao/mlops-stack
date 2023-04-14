# MLOps Setup Scripts
[(back to MLOps setup guide)](../docs/mlops-setup.md)

This directory contains setup scripts intended to automate CI/CD and ML resource config setup
for MLOps engineers.

The scripts set up CI/CD with GitHub Actions. If using another CI/CD provider, you can
easily translate the provided CI/CD workflows (GitHub Actions YAML under `.github/workflows`)
to other CI/CD providers by running the same shell commands, with a few caveats:

* Usages of the `run-notebook` Action should be replaced by [installing the Databricks CLI](https://github.com/databricks/databricks-cli#installation)
  and invoking the `databricks runs submit --wait` CLI
  ([docs](https://docs.databricks.com/dev-tools/cli/runs-cli.html#submit-a-one-time-run)).
* The model deployment CD workflows in `deploy-model-prod.yml` and `deploy-model-staging.yml` are currently triggered
  by the `notebooks/TriggerModelDeploy.py` helper notebook after the model training job completes. This notebook
  hardcodes the API endpoint for triggering a GitHub Actions workflow. Update `notebooks/TriggerModelDeploy.py`
  to instead hit the appropriate REST API endpoint for triggering model deployment CD for your CI/CD provider.

## Prerequisites

### Install CLIs
* Install the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli)
  * Requirement: `terraform >=1.2.7`
* Install the [Databricks CLI](https://github.com/databricks/databricks-cli): ``pip install databricks-cli``
    * Requirement: `databricks-cli >= 0.17`


### Verify permissions
To use the scripts, you must:
* Be a Databricks workspace admin in the staging and prod workspaces. Verify that you're an admin by viewing the
  [staging workspace admin console](https://6837671528024691.1.gcp.databricks.com#setting/accounts) and
  [prod workspace admin console](https://6837671528024691.1.gcp.databricks.com#setting/accounts). If
  the admin console UI loads instead of the Databricks workspace homepage, you are an admin.
* Be able to create Git tokens with permission to check out the current repository
* Have permission to manage AWS IAM users and attached IAM policies (`"iam:*"` permissions) in the current AWS account.
  If you lack sufficient permissions, you'll see an error message describing any missing permissions when you
  run the setup scripts below. If that occurs, contact your AWS account admin to request any missing permissions.

### Configure GCP auth
* Run `gcloud auth login` to configure an GCP CLI profile.
* Run `gcloud config set project $PROJECT_ID` to configure default GCP project.

### Configure Databricks auth
* Configure a Databricks CLI profile for your staging workspace by running
  ``databricks configure --token --profile "gcp-mlops-staging" --host https://6837671528024691.1.gcp.databricks.com``, 
  which will prompt you for a REST API token
* Create a [Databricks REST API token](https://docs.databricks.com/dev-tools/api/latest/authentication.html#generate-a-personal-access-token)
  in the staging workspace ([link](https://6837671528024691.1.gcp.databricks.com#setting/account))
  and paste the value into the prompt.
* Configure a Databricks CLI for your prod workspace by running ``databricks configure --token --profile "gcp-mlops-prod" --host https://6837671528024691.1.gcp.databricks.com``
* Create a Databricks REST API token in the prod workspace ([link](https://6837671528024691.1.gcp.databricks.com#setting/account)).
  and paste the value into the prompt

### Set up service principal user group
Ensure a group named `gcp-mlops-service-principals` exists in the staging and prod workspace, e.g.
by checking for the group in the [staging workspace admin console](https://6837671528024691.1.gcp.databricks.com#setting/accounts/groups) and
[prod workspace admin console](https://6837671528024691.1.gcp.databricks.com#setting/accounts/groups).
Create the group in staging and/or prod as needed.
Then, grant the `gcp-mlops-service-principals` group [token usage permissions](https://docs.databricks.com/administration-guide/access-control/tokens.html#manage-token-permissions-using-the-admin-console)
### Obtain a git token for use in CI/CD
The setup script prompts a Git token with both read and write permissions
on the current repo.

This token is used to:
1. Fetch ML code from the current repo to run on Databricks for CI/CD (e.g. to check out code from a PR branch and run it
during CI/CD).
2. Call back from
   Databricks -> GitHub Actions to trigger a model deployment deployment workflow when
   automated model retraining completes, i.e. perform step (2) in
   [this diagram](https://github.com/databricks/mlops-stack/blob/main/Pipeline.md#model-training-pipeline).
   
If using GitHub as your hosted Git provider, you can generate a Git token through the [token UI](https://github.com/settings/tokens/new);
be sure to generate a token with "Repo" scope. If you have SSO enabled with your Git provider, be sure to authorize your token.

## Usage

### Run the scripts
From the repo root directory, run:

```
python .mlops-setup-scripts/terraform/bootstrap.py
```
Then, run the following command, providing the required vars to bootstrap CI/CD.
```
python .mlops-setup-scripts/cicd/bootstrap.py \
  --var github_repo_url=https://github.com/<your-org>/<your-repo-name> \
  --var git_token=<your-git-token>
```

Take care to run the Terraform bootstrap script before the CI/CD bootstrap script. 

The first Terraform bootstrap script will:



Each `bootstrap.py` script will print out the path to a JSON file containing generated secret values
to store for CI/CD. **Note the paths of these secrets files for subsequent steps.** If either script
fails or the generated resources are misconfigured (e.g. you supplied invalid Git credentials for CI/CD
service principals when prompted), simply rerun and supply updated input values.


### Store generated secrets in CI/CD
Store each of the generated secrets in the output JSON files as
[GitHub Actions Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository),
where the JSON key
(e.g. `PROD_WORKSPACE_TOKEN`)
is the expected name of the secret in GitHub Actions and the JSON value
(without the surrounding `"` double-quotes) is the value of the secret. 

Note: The provided GitHub Actions workflows under `.github/workflows` assume that you will configure
[repo secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository),
but you can also use
[environment secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-an-environment)
to restrict access to production secrets. You can also modify the workflows to read secrets from another
secret provider.


### Add GitHub workflows to hosted Git repo
Create and push a PR branch adding the GitHub Actions workflows under `.github`:

```
git checkout -b add-cicd-workflows
git add .github
git commit -m "Add CI/CD workflows"
git push upstream add-cicd-workflows
```

Follow [GitHub docs](https://docs.github.com/en/actions/managing-workflow-runs/disabling-and-enabling-a-workflow#enabling-a-workflow)
to enable workflows on your PR. Then, open and merge a pull request based on your PR branch to add the CI/CD workflows to your hosted Git Repo.



Note that the CI/CD workflows will fail
until ML code is introduced to the repo in subsequent steps - you should
merge the pull request anyways.

After the pull request merges, pull the changes back into your local `main`
branch:

```
git checkout main
git pull upstream main
```


Finally, [create environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#creating-an-environment)
in your repo named "staging" and "prod"


### Secret rotation
The generated CI/CD
Databricks service principal REST API tokens have an [expiry of 100 days](https://github.com/databricks/terraform-databricks-mlops-aws-project#mlops-aws-project-module)
and will need to be rotated thereafter. To rotate CI/CD secrets after expiry, simply rerun `python .mlops-setup-scripts/cicd/bootstrap.py`
with updated inputs, after configuring auth as described in the prerequisites.

## Next steps
In this project, interactions with the staging and prod workspace are driven through CI/CD. After you've configured
CI/CD and ML resource state storage, you can productionize your ML project by testing and deploying ML code, deploying model training and
inference jobs, and more. See the [MLOps setup guide](../docs/mlops-setup.md) for details.
