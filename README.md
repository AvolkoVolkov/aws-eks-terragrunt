# AWS EKS Terraform Module with FluxCD

Terraform module for deploying a production-ready AWS EKS cluster with integrated FluxCD GitOps, Karpenter autoscaling, and AWS Load Balancer Controller.

## Features

- **EKS Cluster**: Fully managed Kubernetes cluster on AWS
- **FluxCD**: GitOps continuous delivery for Kubernetes
- **Karpenter**: Kubernetes node autoscaling
- **AWS Load Balancer Controller**: Native AWS ALB/NLB integration
- **Fargate Support**: Serverless Kubernetes pods
- **GitHub App/SSH Key Integration**: Secure Git repository access
- **OIDC Authentication**: Optional OIDC configuration support

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.14 |
| aws | ~> 6.28 |
| helm | ~> 3.1 |
| kubernetes | ~> 3.0 |
| tls | ~> 4.1 |
| time | ~> 0.9 |

## Usage

### Basic Example

```hcl
module "eks" {
  source = "git::https://github.com/AvolkoVolkov/aws-eks-terragrunt.git?ref=1.0.0"

  name               = "my-cluster"
  kubernetes_version = "1.33"
  vpc_id             = "vpc-xxxxx"
  subnet_ids         = ["subnet-xxxxx", "subnet-yyyyy"]

  fluxcd = {
    repo_credentials_configuration = {
      type                           = "github_app"
      githubAppID                    = "12345"
      githubAppInstallationID        = "67890"
      repo_url                       = "https://github.com/myorg/k8s-infra.git"
      param_store_repository_ssk_key = "/path/to/github/token"
    }
    git_repository = {
      name   = "flux-system"
      url    = "https://github.com/myorg/k8s-infra.git"
      branch = "main"
      path   = "clusters/production"
    }
  }
}
```

### Terragrunt Example

See [examples/terragrunt/cluster-0001](./examples/terragrunt/cluster-0001) for a complete Terragrunt configuration.

## Module Components

### 1. EKS Cluster (`main_01_eks.tf`)

Creates an EKS cluster with:
- Managed node groups
- Fargate profiles
- EKS add-ons (VPC-CNI, CoreDNS, kube-proxy, EBS CSI driver, Pod Identity Agent)
- IRSA (IAM Roles for Service Accounts)
- Access entries for cluster admin

### 2. AWS Load Balancer Controller (`main_02_aws_lb_resources.tf`)

Deploys AWS Load Balancer Controller for:
- Application Load Balancer (ALB) ingress
- Network Load Balancer (NLB) services
- Target Group Binding

### 3. FluxCD (`main_03_fluxcd.tf`)

Installs FluxCD with:
- Helm chart deployment
- GitRepository CRD for source control
- Kustomization CRD for reconciliation
- SSH key or GitHub App authentication
- Support for private repositories

### 4. Karpenter (`main_04_karpenter.tf`)

Configures Karpenter for:
- Dynamic node provisioning
- Cost optimization
- Pod identity association
- SQS queue for node lifecycle events

## FluxCD Configuration

### Authentication Methods

#### GitHub App (Recommended)

```hcl
fluxcd = {
  repo_credentials_configuration = {
    type                           = "github_app"
    githubAppID                    = "123456"
    githubAppInstallationID        = "789012"
    repo_url                       = "https://github.com/org/repo.git"
    param_store_repository_ssk_key = "/path/to/ssm/parameter"
  }
}
```

#### SSH Deploy Key

```hcl
fluxcd = {
  repo_credentials_configuration = {
    type                           = "deploy_key"
    repo_url                       = "git@github.com:org/repo.git"
    param_store_repository_ssk_key = "/path/to/ssh/private/key"
  }
}
```

### FluxCD Helm Values

Customize FluxCD deployment in `fluxcd-values.yaml`:

```yaml
installCRDs: true
logLevel: info
watchAllNamespaces: true

helmController:
  create: true
  imagePullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 100m
      memory: 64Mi
  labels:
    fargate_ready: "true"
```

## Fargate Configuration

The module supports running workloads on AWS Fargate:

```hcl
fargate_profiles = {
  flux-system = {
    selectors = [
      {
        namespace = "flux-system"
        labels = {
          fargate_ready = "true"
        }
      }
    ]
  }
}
```

Ensure your FluxCD controller pods have the label `fargate_ready: "true"` to run on Fargate.

## Karpenter Configuration

Enable Karpenter for automatic node scaling:

```hcl
karpenter = {
  create_pod_identity_association = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore   = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ebs_csi_role                   = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }
  queue_managed_sse_enabled = false
  queue_kms_master_key_id   = "alias/aws/sqs"
}
```

## Important Notes

1. **AWS SSM Parameter Store**: Store sensitive data (SSH keys, GitHub tokens) in AWS Systems Manager Parameter Store
2. **FluxCD Namespace**: Default namespace is `flux-system`
3. **Provider Configuration**: The module configures Helm and Kubernetes providers automatically
4. **Fargate Labels**: Controllers need `fargate_ready: "true"` label to run on Fargate

## Inputs

### EKS Variables
See [variables_01_eks.tf](./variables_01_eks.tf) for detailed EKS cluster configuration options.

### FluxCD Variables
See [variables_03_fluxcd.tf](./variables_03_fluxcd.tf) for FluxCD configuration options.

### Karpenter Variables
See [variables_04_karpenter.tf](./variables_04_karpenter.tf) for Karpenter configuration options.

### AWS Load Balancer Variables
See [variables_02_aws_lb_resources.tf](./variables_02_aws_lb_resources.tf) for AWS LB Controller options.

## Outputs

The module outputs include:
- `cluster_arn` - EKS cluster ARN
- `cluster_endpoint` - Kubernetes API endpoint
- `cluster_name` - EKS cluster name
- `cluster_oidc_issuer_url` - OIDC provider URL
- `karpenter_*` - Karpenter resource outputs
- And many more - see [outputs.tf](./outputs.tf)

## Examples

### Complete Terragrunt Setup

```bash
examples/
└── terragrunt/
    └── cluster-0001/
        ├── terragrunt.hcl           # Main Terragrunt configuration
        ├── fluxcd-values.yaml       # FluxCD Helm values
        ├── .terraform-version       # Terraform version pin
        └── .terragrunt-version      # Terragrunt version pin
```

## Migration from ArgoCD

This module was migrated from ArgoCD to FluxCD. Key differences:
- FluxCD uses GitRepository + Kustomization instead of Application/AppOfApps pattern
- Image automation is built into FluxCD (ImageRepository, ImagePolicy, ImageUpdateAutomation)
- FluxCD has better GitOps-native features and active development

## License

MIT

## Authors

Module managed by [AvolkoVolkov](https://github.com/AvolkoVolkov)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
