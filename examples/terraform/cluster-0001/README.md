# Terraform EKS Example

This example shows how to run the EKS module directly with Terraform.

## Usage

Create a `terraform.tfvars` file:

```hcl
vpc_id = "vpc-xxxxx"
subnet_ids = [
  "subnet-xxxxx",
  "subnet-yyyyy",
]
```

Run Terraform:

```bash
terraform init
terraform plan
terraform apply
```

After the cluster is created, configure `kubectl`:

```bash
aws eks update-kubeconfig --region eu-central-1 --name cluster-0001
```
