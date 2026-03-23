data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks[0].cluster_name
}

data "aws_ssm_parameter" "ssh_key" {
  name = var.fluxcd.repo_credentials_configuration.param_store_repository_ssk_key
}

data "aws_ssm_parameter" "github_token" {
  count = var.fluxcd.repo_credentials_configuration.type == "github_app" ? 1 : 0
  name  = var.fluxcd.repo_credentials_configuration.param_store_repository_ssk_key
}

data "aws_ssm_parameter" "oidc_config" {
  for_each = var.fluxcd.oidc_auth
  name     = each.value.aws
}
