/**
 * main.tf - AWS Batch Core Infrastructure für billing-data-aggregator
 */

# IRSA - IAM Roles for Service Accounts (EKS Migration Support)
module "irsa" {
  source  = "terraform-aws-modules/iam/aws/modules/iam-role-for-service-accounts"
  version = "6.2.1"

  name            = local.service
  use_name_prefix = false
  policies        = {}

  oidc_providers = {
    one = {
      provider_arn = nonsensitive(
        module.ssm_data.values["base"]["cluster"]["oidc_provider_arn"]
      )
      namespace_service_accounts = [
        "${local.selected_configuration["k8s_namespace"]}:${local.selected_configuration["k8s_sa_name"]}"
      ]
    }
  }

  tags = local.tags
}

# AWS Batch Module
module "batch" {
  source  = "terraform-aws-modules/batch/aws"
  version = "2.2.1"

  count = local.selected_configuration["batch_enabled"] ? 1 : 0

  # Compute Environment
  compute_environments = {
    main_ec2 = {
      name_prefix = "${local.service}-${local.client}-${local.environment}"

      compute_resources = {
        type = "EC2"

        subnets            = var.batch_ce_subnet_ids
        security_group_ids = var.batch_ce_security_group_ids

        launch_template = {
          launch_template_name = var.batch_launch_template_name
          version              = var.batch_launch_template_version
        }

        tags = merge(local.tags, {
          Name = "${local.service}-${local.client}-${local.environment}-batch"
          Type = "Ec2"
        })
      }
    }
  }

  # Job Queue
  job_queues = {
    default = {
      name     = "${local.service}-${local.client}-${local.environment}-queue"
      state    = "ENABLED"
      priority = 1

      compute_environment_order = {
        0 = {
          compute_environment_key = "main_ec2"
        }
      }

      tags = merge(local.tags, {
        JobQueue = "${local.service}-${local.client}-${local.environment}"
      })
    }
  }

  # Job Definition
  job_definitions = {
    (local.service) = {
      name           = "${local.service}-${local.client}-${local.environment}"
      propagate_tags = true
      type           = "container"

      container_properties = jsonencode({
        image = var.batch_container_image

        resourceRequirements = [
          {
            type  = "VCPU"
            value = tostring(var.batch_vcpu)
          },
          {
            type  = "MEMORY"
            value = tostring(var.batch_memory)
          }
        ]

        command = var.batch_command

        environment = [
          for k, v in var.batch_env : {
            name  = k
            value = v
          }
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/aws/batch/${local.service}"
            awslogs-region        = var.region
            awslogs-stream-prefix = local.service
          }
        }

        retryStrategy = {
          attempts = 2 # Retry once on failure
        }
      })
    }
  }

  tags = local.tags
}
