# AWS EKS Terraform Module

Terraform module for deploying a production-ready AWS EKS cluster with Karpenter autoscaling and AWS Load Balancer Controller.

## Features

- **EKS Cluster**: Fully managed Kubernetes cluster on AWS
- **Karpenter**: Kubernetes node autoscaling
- **AWS Load Balancer Controller**: Native AWS ALB/NLB integration
- **Fargate Support**: Serverless Kubernetes pods

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
}
```

### Terraform Example

If you want to run this module directly with Terraform, create a small root module and call this repository as a child module.

Example structure:

```bash
terraform-eks/
├── versions.tf
├── main.tf
└── outputs.tf
```

`versions.tf`:

```hcl
terraform {
  required_version = "~> 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}
```

`main.tf`:

```hcl
module "eks" {
  source = "git::https://github.com/AvolkoVolkov/aws-eks-terragrunt.git?ref=1.0.0"

  name               = "my-cluster"
  kubernetes_version = "1.33"

  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  eks_managed_node_groups = {
    default = {
      ami_type       = "BOTTLEROCKET_ARM_64"
      instance_types = ["t4g.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 1

      capacity_type = "ON_DEMAND"

      labels = {
        role = "default"
      }
    }
  }

  aws_lb_resources = {
    create = true
  }

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

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

`outputs.tf`:

```hcl
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
```

Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

After the cluster is created, configure `kubectl`:

```bash
aws eks update-kubeconfig --region eu-central-1 --name my-cluster
```

### Terragrunt Example

See [examples/terragrunt/cluster-0001](./examples/terragrunt/cluster-0001) for a complete Terragrunt configuration.

See [examples/terraform/cluster-0001](./examples/terraform/cluster-0001) for a complete Terraform configuration.

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

### 3. Karpenter (`main_04_karpenter.tf`)

Configures Karpenter for:
- Dynamic node provisioning
- Cost optimization
- Pod identity association
- SQS queue for node lifecycle events

## Fargate Configuration

The module supports running workloads on AWS Fargate:

```hcl
fargate_profiles = {
}
```

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

1. **Provider Configuration**: The module configures Helm and Kubernetes providers automatically
2. **Fargate Labels**: Controllers need `fargate_ready: "true"` label to run on Fargate

## Inputs

### EKS Variables
See [variables_01_eks.tf](./variables_01_eks.tf) for detailed EKS cluster configuration options.

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
├── terraform/
│   └── cluster-0001/
│       ├── README.md                # Terraform example instructions
│       ├── versions.tf              # Terraform and provider constraints
│       ├── variables.tf             # Example input variables
│       ├── main.tf                  # Terraform module configuration
│       └── outputs.tf               # Example outputs
└── terragrunt/
    └── cluster-0001/
        ├── terragrunt.hcl           # Main Terragrunt configuration
        ├── .terraform-version       # Terraform version pin
        └── .terragrunt-version      # Terragrunt version pin
```

## License

MIT

## Authors

Module managed by [AvolkoVolkov](https://github.com/AvolkoVolkov)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
