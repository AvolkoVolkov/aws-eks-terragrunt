provider "helm" {
  kubernetes = {
    host                   = module.eks[0].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = concat(["eks", "get-token", "--cluster-name", module.eks[0].cluster_name, "--output", "json"], var.fluxcd.extra_command_arg)
    }
  }
}

provider "kubernetes" {
  host                   = module.eks[0].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = concat(["eks", "get-token", "--cluster-name", module.eks[0].cluster_name, "--output", "json"], var.fluxcd.extra_command_arg)
  }
}

resource "kubernetes_namespace_v1" "fluxcd" {
  count = var.fluxcd.create && var.create ? 1 : 0
  metadata {
    name = var.fluxcd.namespace
  }
}

resource "kubernetes_secret_v1" "oidc_secret" {
  for_each = var.fluxcd.oidc_auth
  metadata {
    name      = each.value.k8s
    namespace = var.fluxcd.namespace
    labels = {
      "app.kubernetes.io/part-of" = "flux-system"
    }
  }
  data = {
    "${each.value.data}" = data.aws_ssm_parameter.oidc_config[each.key].value
  }
}

resource "kubernetes_secret_v1" "repository_secret_deployment_key" {
  count = var.fluxcd.create && var.fluxcd.repo_credentials_configuration.type == "deploy_key" && var.create ? 1 : 0
  metadata {
    name      = var.fluxcd.repo_credentials_configuration.secret_name
    namespace = kubernetes_namespace_v1.fluxcd[0].id
  }
  data = {
    identity       = data.aws_ssm_parameter.ssh_key.value
    "identity.pub" = ""
    known_hosts    = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl\ngithub.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=\ngithub.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
  }
}

resource "kubernetes_secret_v1" "repository_secret_github_app" {
  count = var.fluxcd.create && var.fluxcd.repo_credentials_configuration.type == "github_app" && var.create ? 1 : 0
  metadata {
    name      = var.fluxcd.repo_credentials_configuration.secret_name
    namespace = kubernetes_namespace_v1.fluxcd[0].id
  }
  data = {
    username = "git"
    password = "x-access-token:${data.aws_ssm_parameter.github_token.value}"
  }
}

resource "helm_release" "fluxcd" {
  count      = var.fluxcd.create && var.create ? 1 : 0
  repository = var.fluxcd.chart_repo
  chart      = var.fluxcd.chart_name
  version    = var.fluxcd.chart_version

  name      = var.fluxcd.helm_release_name
  namespace = kubernetes_namespace_v1.fluxcd[0].id
  values = [
    file(var.fluxcd.path_to_values)
  ]
}

resource "kubernetes_manifest" "git_repository" {
  count = var.fluxcd.create && var.create && var.fluxcd.git_repository != null ? 1 : 0

  depends_on = [helm_release.fluxcd]

  manifest = {
    apiVersion = "source.toolkit.fluxcd.io/v1"
    kind       = "GitRepository"
    metadata = {
      name      = var.fluxcd.git_repository.name
      namespace = kubernetes_namespace_v1.fluxcd[0].id
    }
    spec = {
      interval = var.fluxcd.git_repository.interval
      url      = var.fluxcd.git_repository.url
      ref = {
        branch = var.fluxcd.git_repository.branch
      }
      secretRef = {
        name = var.fluxcd.repo_credentials_configuration.secret_name
      }
    }
  }
}

resource "kubernetes_manifest" "kustomization" {
  count = var.fluxcd.create && var.create && var.fluxcd.git_repository != null ? 1 : 0

  depends_on = [kubernetes_manifest.git_repository]

  manifest = {
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name      = var.fluxcd.git_repository.name
      namespace = kubernetes_namespace_v1.fluxcd[0].id
    }
    spec = {
      interval = var.fluxcd.git_repository.interval
      sourceRef = {
        kind = "GitRepository"
        name = var.fluxcd.git_repository.name
      }
      path  = var.fluxcd.git_repository.path
      prune = true
    }
  }
}
