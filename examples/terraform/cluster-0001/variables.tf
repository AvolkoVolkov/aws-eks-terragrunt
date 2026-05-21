variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "name" {
  description = "EKS cluster name"
  type        = string
  default     = "cluster-0001"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the EKS cluster and node groups"
  type        = list(string)
}
