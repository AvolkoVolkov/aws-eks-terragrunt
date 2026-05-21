module "eks" {
  source = "../../.."

  name               = var.name
  kubernetes_version = "1.33"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

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
    node_iam_role_source_account_condition = false
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
