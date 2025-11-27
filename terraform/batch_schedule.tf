/**
 * batch_schedule.tf - EventBridge Scheduling für billing-data-aggregator
 *
 * Diese Datei konfiguriert die zeitgesteuerte, automatische Ausführung
 * des Billing Data Aggregators via Amazon EventBridge (CloudWatch Events).
 *
 * Schedule:
 *   Täglich um 02:00 UTC (04:00 CET / 03:00 CEST)
 *   Cron Expression: cron(0 2 * * ? *)
 *
 * Komponenten:
 *   1. EventBridge Rule (aws_cloudwatch_event_rule)
 *      - Definiert Cron-Schedule
 *      - Kann per Configuration aktiviert/deaktiviert werden
 *
 *   2. IAM Role (aws_iam_role.events_invoke_batch)
 *      - Erlaubt EventBridge das Submitten von Batch Jobs
 *      - Minimal Permissions: batch:SubmitJob only
 *
 *   3. EventBridge Target (aws_cloudwatch_event_target)
 *      - Verbindet Rule mit Batch Queue
 *      - Definiert welche Job Definition verwendet wird
 *
 * Workflow:
 *   EventBridge Rule (cron trigger)
 *     ↓
 *   IAM Role (assume + permissions)
 *     ↓
 *   AWS Batch SubmitJob API Call
 *     ↓
 *   Job in Queue (waiting for compute)
 *     ↓
 *   Container Execution
 *     ↓
 *   CloudWatch Logs
 *
 * AWS Cron Format:
 *   cron(Minutes Hours Day Month DayOfWeek Year)
 *   - Minutes: 0-59
 *   - Hours: 0-23 (UTC!)
 *   - Day: 1-31 or ?
 *   - Month: 1-12 or JAN-DEC
 *   - DayOfWeek: 1-7 or SUN-SAT or ?
 *   - Year: 1970-2199
 *
 *   Wichtig: Entweder Day oder DayOfWeek muss ? sein
 *
 * Beispiel-Schedules:
 *   cron(0 2 * * ? *)        - Täglich 02:00 UTC
 *   cron(30 6 * * ? *)       - Täglich 06:30 UTC
 *   cron(0 star/6 * * ? *)      - Alle 6 Stunden
 *   cron(0 8 ? * MON-FRI *)  - Werktags 08:00 UTC
 *   cron(0 0 1 * ? *)        - Monatlich am 1. um Mitternacht
 *
 * Conditional Creation:
 *   Alle Ressourcen werden nur erstellt wenn:
 *   local.selected_configuration["schedule_enabled"] == true
 *
 *   Dies erlaubt umgebungs-spezifisches Aktivieren/Deaktivieren:
 *   - Production: schedule_enabled = true (automatisch)
 *   - Development: schedule_enabled = false (manuell)
 *
 * Schedule Deaktivieren:
 *   Option 1: In configuration.tf setzen:
 *     dev = { schedule_enabled = false }
 *
 *   Option 2: Via AWS CLI:
 *     aws events disable-rule \
 *       --name billing-data-aggregator-enercity-prod-schedule
 *
 *   Option 3: Terraform destroy für diese Ressourcen:
 *     terraform destroy -target=aws_cloudwatch_event_rule.batch_schedule
 *
 * Monitoring:
 *   CloudWatch Metrics unter AWS/Events namespace:
 *   - Invocations: Anzahl der Rule Triggers
 *   - FailedInvocations: Fehler beim Job Submit
 *   - TriggeredRules: Erfolgreiche Triggers
 *
 *   View Metrics:
 *   aws cloudwatch get-metric-statistics \
 *     --namespace AWS/Events \
 *     --metric-name Invocations \
 *     --dimensions Name=RuleName,Value=billing-data-aggregator-enercity-prod-schedule
 *
 * Debugging:
 *   1. Rule Status prüfen:
 *      aws events describe-rule \
 *        --name billing-data-aggregator-enercity-prod-schedule
 *
 *   2. Targets prüfen:
 *      aws events list-targets-by-rule \
 *        --rule billing-data-aggregator-enercity-prod-schedule
 *
 *   3. IAM Role Permissions prüfen:
 *      aws iam get-role-policy \
 *        --role-name billing-data-aggregator-enercity-prod-events-batch-role \
 *        --policy-name <policy-name>
 *
 *   4. CloudWatch Logs für EventBridge:
 *      aws logs tail /aws/events/billing-data-aggregator --follow
 *
 * Job Naming:
 *   Jeder automatisch gestartete Job erhält den Namen:
 *   {service}-{client}-{environment}-{service}
 *
 *   Beispiel: billing-data-aggregator-enercity-prod-billing-data-aggregator
 *
 * Multiple Executions:
 *   Wenn ein Job noch läuft und der Schedule triggert:
 *   - Ein neuer Job wird in die Queue gestellt
 *   - Jobs werden sequenziell verarbeitet (Queue Behavior)
 *   - Keine parallele Ausführung (Single Compute Environment)
 *
 * Timezone Consideration:
 *   EventBridge Cron verwendet IMMER UTC!
 *   - 02:00 UTC = 04:00 CET (Winter)
 *   - 02:00 UTC = 03:00 CEST (Sommer)
 *
 *   Für lokale Zeit-Synchronisation muss die Cron Expression
 *   bei Zeitumstellungen NICHT angepasst werden.
 *
 * Integration mit main.tf:
 *   Referenziert Ressourcen aus main.tf:
 *   - module.batch[0].job_queues["default"].arn
 *   - module.batch[0].job_definitions[local.service].arn
 *
 * Security:
 *   - IAM Role mit Minimal Permissions (batch:SubmitJob only)
 *   - Kein Zugriff auf DescribeJobs, TerminateJob, etc.
 *   - Trust Policy nur für events.amazonaws.com
 *
 * Copyright: LynqTech GmbH / Enercity AG
 * Maintainer: Billing Data / DevOps Team
 * Documentation: terraform/README.md, flux/README.md
 */

resource "aws_cloudwatch_event_rule" "batch_schedule" {
  count = local.selected_configuration["schedule_enabled"] ? 1 : 0

  name                = "${local.service}-${local.client}-${local.environment}-schedule"
  schedule_expression = var.batch_job_schedule_cron

  tags = local.tags
}

resource "aws_iam_role" "events_invoke_batch" {
  count = local.selected_configuration["schedule_enabled"] ? 1 : 0

  name = "${local.service}-${local.client}-${local.environment}-events-batch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "events_invoke_batch" {
  count = local.selected_configuration["schedule_enabled"] ? 1 : 0

  role = aws_iam_role.events_invoke_batch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["batch:SubmitJob"]
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_event_target" "batch_target" {
  count = local.selected_configuration["schedule_enabled"] ? 1 : 0

  rule      = aws_cloudwatch_event_rule.batch_schedule[0].name
  target_id = local.service

  arn      = module.batch[0].job_queues["default"].arn
  role_arn = aws_iam_role.events_invoke_batch[0].arn

  batch_target {
    job_definition = module.batch[0].job_definitions[local.service].arn
    job_name       = "${local.service}-${local.client}-${local.environment}-${local.service}"
  }
}
