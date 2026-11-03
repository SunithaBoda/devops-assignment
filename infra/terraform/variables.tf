variable "project" {
  description = "Short name used in AWS resource names."
  type        = string
  default     = "devops-assignment"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the application VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "image_tag" {
  description = "Container image tag pushed by CI (git SHA)."
  type        = string
  default     = "latest"
}

variable "backend_cpu" {
  type    = number
  default = 256
}

variable "backend_memory" {
  type    = number
  default = 512
}

variable "frontend_cpu" {
  type    = number
  default = 256
}

variable "frontend_memory" {
  type    = number
  default = 512
}

variable "worker_cpu" {
  type    = number
  default = 256
}

variable "worker_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  description = "Desired ECS tasks per service."
  type        = number
  default     = 1
}

variable "redis_node_type" {
  description = "ElastiCache node class."
  type        = string
  default     = "cache.t3.micro"
}

variable "log_retention_days" {
  type    = number
  default = 14
}
