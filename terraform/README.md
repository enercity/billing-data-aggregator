# Terraform für billing-data-aggregator

Terraform-Infrastruktur für AWS Batch Deployment des Billing Data Aggregators.

## Architektur

- **AWS Batch**: Container-basierte Job Execution
- **EventBridge**: Tägliches Scheduling (02:00 UTC)
- **CloudWatch Logs**: Logging und Monitoring
- **IRSA**: IAM Roles for Service Accounts (EKS Migration Support)

## Deployment

### Voraussetzungen

- Terraform >= 1.9
- AWS CLI konfiguriert
- Zugriff auf LynqTech Terraform Registry
- EC2 Launch Template bereits deployed

### Initialisierung

```bash
terraform init
```

### Planung

```bash
terraform plan \
  -var="batch_container_image=<ECR_IMAGE>:latest" \
  -var="batch_ce_subnet_ids=[\"subnet-xxx\",\"subnet-yyy\"]" \
  -var="batch_ce_security_group_ids=[\"sg-xxx\"]" \
  -var="batch_launch_template_name=batch-launch-template"
```

### Deployment

```bash
terraform apply \
  -var="batch_container_image=<ECR_IMAGE>:latest" \
  -var="batch_ce_subnet_ids=[\"subnet-xxx\",\"subnet-yyy\"]" \
  -var="batch_ce_security_group_ids=[\"sg-xxx\"]" \
  -var="batch_launch_template_name=batch-launch-template"
```

## Konfiguration

### Container Image

Das Container-Image muss in ECR verfügbar sein:

```bash
export ECR_REPO="<account-id>.dkr.ecr.eu-central-1.amazonaws.com/billing-data-aggregator"
export IMAGE_TAG="prod_1.0.0"

# Build und Push
docker build -t ${ECR_REPO}:${IMAGE_TAG} .
aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_REPO}
docker push ${ECR_REPO}:${IMAGE_TAG}

# Terraform Variable
terraform apply -var="batch_container_image=${ECR_REPO}:${IMAGE_TAG}"
```

### Environment Variables

Environment-spezifische Variablen werden über `batch_env` Map übergeben:

```hcl
batch_env = {
  BDA_CLIENT_ID    = "enercity"
  BDA_ENVIRONMENT  = "prod"
  BDA_LOG_LEVEL    = "info"
  BDA_DB_HOST      = "octopus.db.example.com"
  BDA_S3_BUCKET    = "billing-exports-prod"
}
```

**Wichtig**: Secrets (DB Passwort, AWS Keys) werden aus SSM Parameter Store geladen, nicht als Terraform-Variablen!

### Schedule

Standard: Täglich um 02:00 UTC (04:00 CET / 03:00 CEST)

```hcl
batch_job_schedule_cron = "cron(0 2 * * ? *)"
```

Weitere Beispiele:

```hcl
# Alle 6 Stunden
batch_job_schedule_cron = "cron(0 */6 * * ? *)"

# Werktags um 06:00 UTC
batch_job_schedule_cron = "cron(0 6 ? * MON-FRI *)"

# Schedule deaktivieren (manuelle Ausführung)
# Setze in configuration.tf: schedule_enabled = false
```

### Ressourcen

Standard: 1 vCPU, 2048 MB RAM

```hcl
batch_vcpu   = 2     # 2 vCPUs
batch_memory = 4096  # 4 GB RAM
```

## Multi-Environment

Konfiguration per Client/Environment in `configuration.tf`:

```hcl
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
```

## Outputs

```bash
# Job Queue ARN für manuelle Submission
terraform output batch_job_queue_arn

# Job Definition ARN
terraform output batch_job_definition_arn

# Schedule Rule ARN
terraform output schedule_rule_arn
```

## Manuelles Job Triggering

```bash
# Job manuell starten (ohne Schedule)
aws batch submit-job \
  --job-name "billing-data-aggregator-manual-$(date +%s)" \
  --job-queue $(terraform output -raw batch_job_queue_arn) \
  --job-definition $(terraform output -raw batch_job_definition_arn)
```

## Monitoring

### CloudWatch Logs

```bash
# Log Group
/aws/batch/billing-data-aggregator

# Log Streams
aws logs tail /aws/batch/billing-data-aggregator --follow
```

### Batch Job Status

```bash
# Aktive Jobs
aws batch list-jobs \
  --job-queue $(terraform output -raw batch_job_queue_arn) \
  --job-status RUNNING

# Job Details
aws batch describe-jobs --jobs <job-id>
```

## FluxCD Integration

Dieses Terraform wird von FluxCD/Terraform Controller verwaltet:

```yaml
# datalynq Repository: flux/apps/billing-data-aggregator/
apiVersion: infra.contrib.fluxcd.io/v1alpha2
kind: Terraform
metadata:
  name: billing-data-aggregator
  namespace: flux-system
spec:
  path: ./terraform
  sourceRef:
    kind: GitRepository
    name: billing-data-aggregator
  interval: 10m
  varsFrom:
    - kind: ConfigMap
      name: billing-data-aggregator-vars
```

## Troubleshooting

### Job Failed

```bash
# Job Logs anzeigen
JOB_ID="<job-id>"
aws batch describe-jobs --jobs $JOB_ID
aws logs tail /aws/batch/billing-data-aggregator --follow
```

### Schedule nicht getriggert

```bash
# EventBridge Rule Status
aws events describe-rule \
  --name billing-data-aggregator-enercity-prod-schedule

# Rule aktivieren
aws events enable-rule \
  --name billing-data-aggregator-enercity-prod-schedule
```

### Container startet nicht

```bash
# Job Definition prüfen
aws batch describe-job-definitions \
  --job-definition-name billing-data-aggregator-enercity-prod \
  --status ACTIVE

# Container Image prüfen
aws ecr describe-images \
  --repository-name billing-data-aggregator \
  --image-ids imageTag=prod_1.0.0
```

## Weiterführende Dokumentation

- [AWS Batch Documentation](https://docs.aws.amazon.com/batch/)
- [EventBridge Cron Expressions](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cron-expressions.html)
- [Terraform AWS Batch Module](https://registry.terraform.io/modules/terraform-aws-modules/batch/aws/)
