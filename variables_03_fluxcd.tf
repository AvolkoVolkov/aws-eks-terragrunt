variable "fluxcd" {
  description = "FluxCD variables"
  type = object({
    create             = optional(bool, true)
    tags               = optional(map(string), {})
    namespace          = optional(string, "flux-system")
    extra_command_arg  = optional(list(string), [])
    chart_repo         = optional(string, "https://fluxcd-community.github.io/helm-charts")
    chart_name         = optional(string, "flux2")
    chart_version      = optional(string, "2.13.0")
    helm_release_name  = optional(string, "flux2")
    path_to_values     = optional(string, "fluxcd-values.yaml")
    repo_credentials_configuration = object({
      type                           = optional(string, "deploy_key")
      repo_url                       = string
      secret_name                    = optional(string, "flux-git-deploy")
      githubAppID                    = optional(string, "")
      githubAppInstallationID        = optional(string, "")
      param_store_repository_ssk_key = string
    })
    git_repository = optional(object({
      name           = optional(string, "flux-system")
      url            = optional(string, "")
      branch         = optional(string, "main")
      path           = optional(string, "clusters")
      interval       = optional(string, "1m")
      reconcile_path = optional(string, "./")
    }))
    oidc_auth = optional(map(object({
      aws  = optional(string, "fluxcd-oidc-config")
      k8s  = optional(string, "fluxcd-oidc-config")
      data = optional(string, "clientSecret")
    })), {})
  })
}
