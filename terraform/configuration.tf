/**
 * configuration.tf - Multi-Environment Konfiguration
 *
 * Umgebungsspezifische Konfiguration für billing-data-aggregator
 */

locals {
  configuration = {
    default = {
      k8s_namespace    = local.service
      k8s_sa_name      = local.service
      batch_enabled    = true
      schedule_enabled = true
    }
    lynqtech = {
      playground = {
        batch_enabled    = true
        schedule_enabled = false # Manuelles Testing
      }
      dev = {
        batch_enabled    = true
        schedule_enabled = false # Manuelles Testing
      }
    }
    enercity = {
      prod = {
        batch_enabled    = true
        schedule_enabled = true
      }
      stage = {
        batch_enabled    = true
        schedule_enabled = true
      }
    }
    q-cells = {
      prod  = {}
      stage = {}
    }
    purpur-energy = {
      prod  = {}
      stage = {}
    }
  }

  selected_configuration = merge(
    local.configuration["default"],
    try(local.configuration[local.client][local.environment], {})
  )
}
