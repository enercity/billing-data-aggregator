/**
 * batch_schedule.tf - EventBridge Scheduling für billing-data-aggregator
 *
 * Täglich um 02:00 UTC (04:00 CET / 03:00 CEST)
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
