/**
 * outputs.tf - Terraform Outputs
 */

output "irsa_role_arn" {
  description = "ARN of the IRSA role for Kubernetes ServiceAccount"
  value       = module.irsa.arn
}

output "batch_job_queue_arn" {
  description = "ARN of the Batch job queue"
  value       = try(module.batch[0].job_queues["default"].arn, null)
}

output "batch_job_definition_arn" {
  description = "ARN of the Batch job definition"
  value       = try(module.batch[0].job_definitions[local.service].arn, null)
}

output "batch_compute_environment_arn" {
  description = "ARN of the Batch compute environment"
  value       = try(module.batch[0].compute_environments["main_ec2"].arn, null)
}

output "schedule_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = try(aws_cloudwatch_event_rule.batch_schedule[0].arn, null)
}

output "service_name" {
  description = "Service name"
  value       = local.service
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}

output "client" {
  description = "Client identifier"
  value       = local.client
}
