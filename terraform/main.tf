/**
 * main.tf - AWS Batch Core Infrastructure für billing-data-aggregator
 *
 * Diese Datei definiert die Kern-Infrastruktur für die AWS Batch-basierte
 * Ausführung des Billing Data Aggregators.
 *
 * Komponenten:
 *   1. IRSA (IAM Roles for Service Accounts)
 *      - Kubernetes ServiceAccount IAM Role für EKS Migration
 *      - Ermöglicht Pod-zu-AWS Authentifizierung ohne Credentials
 *
 *   2. AWS Batch Compute Environment
 *      - EC2-basierte Compute-Ressourcen
 *      - Verwendet externe Launch Template für EC2-Konfiguration
 *      - Netzwerk-Platzierung in Private Subnets mit Security Groups
 *
 *   3. AWS Batch Job Queue
 *      - Empfängt Job-Submissions von EventBridge oder manuell
 *      - Priorität 1 (Standard für Single-Queue Setup)
 *      - State: ENABLED (verarbeitet Jobs automatisch)
 *
 *   4. AWS Batch Job Definition
 *      - Container-basierte Job-Definition
 *      - Definiert: Image, CPU, Memory, Environment, Logging
 *      - Retry Strategy: 2 Versuche bei Fehler
 *
 * Architektur-Prinzipien:
 *   - Keine hardcodierten Werte (alles via Variablen oder SSM)
 *   - Externe Launch Template für EC2-Konfiguration
 *   - Container Image als Variable (injected by FluxCD)
 *   - Environment Variables als JSON Map (dynamisch)
 *
 * Ressourcen-Naming Convention:
 *   {service}-{client}-{environment}-{component}
 *   Beispiel: billing-data-aggregator-enercity-prod-queue
 *
 * Conditional Creation:
 *   Alle Ressourcen werden nur erstellt wenn:
 *   local.selected_configuration["batch_enabled"] == true
 *
 *   Dies erlaubt umgebungs-spezifisches Enable/Disable via
 *   configuration.tf ohne Code-Änderungen.
 *
 * External Dependencies:
 *   - EC2 Launch Template (muss vorher existieren)
 *   - VPC Subnets (aus var.batch_ce_subnet_ids)
 *   - Security Groups (aus var.batch_ce_security_group_ids)
 *   - ECR Container Image (aus var.batch_container_image)
 *
 * CloudWatch Logs:
 *   Alle Job-Logs werden automatisch nach CloudWatch geschrieben:
 *   - Log Group: /aws/batch/billing-data-aggregator
 *   - Log Stream: billing-data-aggregator/<container-id>
 *   - Retention: 30 days (konfigurierbar)
 *
 * Terraform Module:
 *   Verwendet terraform-aws-modules/batch/aws für Best Practices:
 *   - https://registry.terraform.io/modules/terraform-aws-modules/batch/aws
 *
 * Outputs:
 *   Siehe outputs.tf für exportierte Werte:
 *   - Job Queue ARN (für manuelle Submissions)
 *   - Job Definition ARN (für AWS CLI)
 *   - Compute Environment ARN (für Monitoring)
 *
 * Integration:
 *   Diese Infrastruktur wird von batch_schedule.tf ergänzt:
 *   - EventBridge Rule für tägliche Ausführung
 *   - IAM Role für EventBridge -> Batch Permissions
 *
 * Testing:
 *   Nach Deployment kann ein Job manuell getestet werden:
 *   aws batch submit-job \
 *     --job-name test-$(date +%s) \
 *     --job-queue $(terraform output -raw batch_job_queue_arn) \
 *     --job-definition $(terraform output -raw batch_job_definition_arn)
 *
 * Copyright: LynqTech GmbH / Enercity AG
 * Maintainer: Billing Data / DevOps Team
 * Documentation: terraform/README.md
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
