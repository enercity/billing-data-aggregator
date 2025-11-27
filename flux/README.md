# FluxCD Configuration für billing-data-aggregator

FluxCD-Integration für den Billing Data Aggregator AWS Batch Service.

## Struktur

```
flux/
├── app/
│   ├── kustomization.yaml      # FluxCD Kustomization
│   ├── terraform.yaml          # Terraform Controller Config
│   ├── components.yaml         # Namespace Definition
│   └── alert.yaml             # Monitoring Alerts (optional)
├── environment/
│   ├── billing-data-aggregator.yaml  # Environment Kustomization
│   └── _versions.yaml          # Version Management
└── README.md                   # Dieses File
```

## Setup

### 1. Versions-Management

Versions werden in `environment/_versions.yaml` definiert:

```yaml
version_billing_data_aggregator_tf: "~ 1.0.0"
```

Semantic Versioning Patterns:

- `"~ 0.1.0-0"` - Alle Dev/Pre-Release Versionen
- `"~ 1.0.0"` - Minor + Patch Updates (1.0.x)
- `"1.0.0"` - Exakte Version

### 2. Terraform Deployment

Der Terraform Controller deployt automatisch die AWS Batch Infrastruktur:

- **OCIRepository**: Lädt Terraform Code von ECR
- **Terraform Resource**: Führt Terraform aus
- **Backend**: S3 State Storage mit DynamoDB Locking

### 3. Integration in FluxCD Environment

Diese Konfiguration wird im `fluxcd-environment` Repository referenziert:

```bash
# Im fluxcd-environment Repository
flux-apps/service-stacks/billing-data-aggregator/
└── kustomization.yaml
```

## Tag Strategy

### Terraform Tags

```bash
# Development
git tag iac/v0.1.0-dev.1
git push origin iac/v0.1.0-dev.1

# Staging
git tag iac/v1.0.0-rc.1
git push origin iac/v1.0.0-rc.1

# Production
git tag iac/v1.0.0
git push origin iac/v1.0.0
```

### Container Tags

Container Images werden separat von CI/CD nach ECR gepusht und im Terraform als Variable referenziert.

## Monitoring

### Terraform Status

```bash
# Terraform Resource Status
kubectl get terraform -n flux-system

# Terraform Logs
kubectl logs -n flux-system -l app.kubernetes.io/name=billing-data-aggregator
```

### Batch Job Status

```bash
# Via AWS CLI
aws batch list-jobs \
  --job-queue billing-data-aggregator-enercity-prod-queue \
  --job-status RUNNING
```

## Rollback

### Terraform Rollback

```bash
# Versions in _versions.yaml auf vorherige Version setzen
version_billing_data_aggregator_tf: "1.0.0"

# Commit und Push
git commit -am "Rollback Terraform to 1.0.0"
git push
```

### Manual Intervention

```bash
# Terraform Plan anzeigen
kubectl get terraform billing-data-aggregator -n flux-system -o yaml

# Runner Pod Logs
kubectl logs -n flux-system -l infra.contrib.fluxcd.io/terraform=billing-data-aggregator
```

## Troubleshooting

### Terraform fails to apply

```bash
# Check Terraform Resource
kubectl describe terraform billing-data-aggregator -n flux-system

# Check Runner Pod
kubectl get pods -n flux-system -l infra.contrib.fluxcd.io/terraform=billing-data-aggregator

# View Logs
kubectl logs -n flux-system -l infra.contrib.fluxcd.io/terraform=billing-data-aggregator --tail=100
```

### Backend State Lock

```bash
# DynamoDB Lock Table
aws dynamodb scan --table-name lqt-tf-states-locks

# Force Unlock (DANGEROUS!)
terraform force-unlock <lock-id>
```

## Weiterführende Dokumentation

- [FluxCD Integration Guide](https://lynqtech.atlassian.net/wiki/x/DwD2Ww)
- [Terraform Controller Docs](https://flux-iac.github.io/tofu-controller/)
- [AWS Batch Documentation](https://docs.aws.amazon.com/batch/)
