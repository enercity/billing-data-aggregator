/**
 * _init.tf - Zentrale Initialisierung und Locals
 *
 * Copyright: LynqTech GmbH / Enercity AG
 * Maintainer: Billing Data / DevOps Team
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
