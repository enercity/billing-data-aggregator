/**
 * variables.tf - Terraform Variable Definitions
 */

# Region
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

# SSM Configuration
variable "config_map_base_path" {
  description = "Base path for SSM configuration parameters"
  type        = string
  default     = "/config/base"
}

# Client & Environment (optional overrides)
variable "client" {
  description = "Client identifier (default: from SSM)"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name (default: from SSM)"
  type        = string
  default     = null
}

variable "secrets_ssm_prefix" {
  description = "SSM prefix for secrets (default: from SSM)"
  type        = string
  default     = null
}

variable "one_password_vault" {
  description = "1Password vault name (default: from SSM)"
  type        = string
  default     = null
}

variable "backup_plan" {
  description = "AWS Backup plan name (default: from SSM)"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# Batch Configuration
variable "batch_ce_subnet_ids" {
  description = "Subnet IDs for Batch Compute Environment"
  type        = list(string)
}

variable "batch_ce_security_group_ids" {
  description = "Security Group IDs for Batch Compute Environment"
  type        = list(string)
}

variable "batch_launch_template_name" {
  description = "Name of the EC2 Launch Template for Batch"
  type        = string
}

variable "batch_launch_template_version" {
  description = "Version of the EC2 Launch Template ($Latest, $Default, or version number)"
  type        = string
  default     = "$Latest"
}

# Container Configuration
variable "batch_container_image" {
  description = "Docker image for Batch job (ECR URI with tag)"
  type        = string
}

variable "batch_vcpu" {
  description = "Number of vCPUs for the Batch job"
  type        = number
  default     = 1
}

variable "batch_memory" {
  description = "Memory in MB for the Batch job"
  type        = number
  default     = 2048
}

variable "batch_command" {
  description = "Command to override container entrypoint (empty = use Docker CMD)"
  type        = list(string)
  default     = []
}

variable "batch_env" {
  description = "Environment variables for the Batch job container"
  type        = map(string)
  default     = {}
}

# Schedule Configuration
variable "batch_job_schedule_cron" {
  description = "Cron expression for EventBridge schedule (AWS format)"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 02:00 UTC
}
