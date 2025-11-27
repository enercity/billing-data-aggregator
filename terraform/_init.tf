/**
 * _init.tf - Zentrale Initialisierung und Locals
 *
 * Diese Datei initialisiert das Terraform-Projekt mit fundamentalen
 * Konfigurationswerten und lädt zentrale Parameter aus AWS Systems Manager.
 *
 * Zweck:
 *   - Definition der Service-Identity (Name, Squad, Tags)
 *   - Laden von umgebungsübergreifenden Konfigurationen aus SSM
 *   - Bereitstellung von Standard-Tags für alle AWS-Ressourcen
 *   - Integration mit LynqTech Terraform Registry
 *
 * Service Identity:
 *   service = "billing-data-aggregator"
 *   squad   = "datalynx"
 *
 * Diese Werte werden in allen Ressourcen-Namen verwendet:
 *   - AWS Batch: billing-data-aggregator-enercity-prod-queue
 *   - IAM Roles: billing-data-aggregator-enercity-prod-events-batch-role
 *   - CloudWatch: /aws/batch/billing-data-aggregator
 *
 * SSM Parameter Integration:
 *   Das Modul lädt Konfiguration aus /config/base im Parameter Store:
 *   - clientId: Mandanten-Identifier (z.B. "enercity")
 *   - environment: Umgebungs-Name (z.B. "prod", "stage", "dev")
 *   - cluster.oidc_provider_arn: EKS OIDC Provider für IRSA
 *   - secrets_ssm_prefix: Basis-Pfad für Secrets
 *   - onePasswordVault: 1Password Vault Name
 *
 * Tagging Strategy:
 *   Alle Ressourcen erhalten automatisch folgende Tags:
 *   - client: Mandanten-ID für Cost Allocation
 *   - environment: Umgebung für Cost Allocation
 *   - service: Service-Name für Resource Grouping
 *   - squad: Verantwortliches Team für Ownership
 *   - backup/backupPlan: Optional für AWS Backup Integration
 *
 * Variable Overrides:
 *   Alle Werte können via Variablen überschrieben werden:
 *   - var.client (default: aus SSM)
 *   - var.environment (default: aus SSM)
 *   - var.secrets_ssm_prefix (default: aus SSM)
 *
 * Verwendung in anderen Dateien:
 *   local.service            -> "billing-data-aggregator"
 *   local.client             -> "enercity"
 *   local.environment        -> "prod"
 *   local.tags               -> Standard Tags Map
 *   local.secrets_ssm_prefix -> "/config/enercity/prod/secrets"
 *
 * Abhängigkeiten:
 *   - AWS Systems Manager Parameter Store (/config/base)
 *   - LynqTech Terraform Registry (terraform-registry.devops.lynqtech.lynq.tech)
 *   - IAM Permissions für SSM Parameter Read
 *
 * Copyright: LynqTech GmbH / Enercity AG
 * Maintainer: Billing Data / DevOps Team
 * Documentation: terraform/README.md
 */

locals {
  service            = "billing-data-aggregator"
  squad              = "datalynx"
  namespace          = "services"
  client             = var.client == null ? nonsensitive(module.ssm_data.values["base"]["clientId"]) : lower(var.client)
  environment        = var.environment == null ? nonsensitive(module.ssm_data.values["base"]["environment"]) : lower(var.environment)
  secrets_ssm_prefix = var.secrets_ssm_prefix == null ? nonsensitive(module.ssm_data.values["base"]["secrets_ssm_prefix"]) : var.secrets_ssm_prefix
  one_password_vault = var.one_password_vault == null ? nonsensitive(module.ssm_data.values["base"]["onePasswordVault"]) : var.one_password_vault
  backup_plan        = var.backup_plan == null ? nonsensitive(try(module.ssm_data.values["base"]["backup_plan"], null)) : var.backup_plan

  tags = merge(
    var.tags,
    {
      client      = lower(local.client)
      environment = lower(local.environment)
      service     = lower(local.service)
      squad       = lower(local.squad)
    },
    local.backup_plan != null ? {
      backup     = true
      backupPlan = local.backup_plan
    } : {}
  )
}

module "ssm_data" {
  source  = "terraform-registry.devops.lynqtech.lynq.tech/lynqtech/ssm_json_read/aws"
  version = "1.1.0"

  path  = var.config_map_base_path
  names = ["base"]
  lock  = local.service
}
