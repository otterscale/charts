# OtterScale Helm Chart

A Helm chart for deploying OtterScale - A comprehensive cloud infrastructure management platform on Kubernetes.

## Introduction

OtterScale is a cloud infrastructure management platform that provides:
- Kubernetes container orchestration
- Virtualization management
- Storage management
- GPU management
- MAAS and Juju integration
- Ceph storage
- AI-adaptive caching

## Prerequisites

- Kubernetes 1.30.0+
- Helm 3.0+
- Istio installed (if Istio features are enabled)
- OpenFeature Operator installed (if OpenFeature is enabled)

## Installation

### Basic Installation

```bash
helm install otterscale ./otterscale \
  --namespace otterscale \
  --create-namespace \
  --values my-values.yaml
```

### Installation with Custom Parameters

```bash
helm install otterscale ./otterscale \
  --namespace otterscale \
  --create-namespace \
  --set postgresql.auth.password=mypassword \
  --set keycloak.auth.adminPassword=myadminpass
```

## Configuration

### Required Parameters

The following parameters must be configured in values.yaml or via `--set`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.auth.password` | PostgreSQL password | `""` |
| `postgresql.auth.postgresPassword` | PostgreSQL admin password | `""` |
| `keycloak.auth.adminPassword` | Keycloak admin password | `""` |
| `otterscaleWeb.env.publicWebUrl` | Frontend URL | `""` |
| `otterscaleWeb.env.keycloakRealmUrl` | Keycloak Realm URL | `""` |
| `otterscaleWeb.env.keycloakClientID` | Keycloak Client ID | `""` |
| `otterscaleWeb.env.keycloakClientSecret` | Keycloak Client Secret | `""` |

### Core Component Configuration

#### OtterScale Backend

```yaml
otterscale:
  replicas: 1
  image:
    repository: ghcr.io/otterscale/otterscale/service
    tag: ""  # Uses appVersion as default
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  service:
    type: ClusterIP  # Options: ClusterIP, NodePort
    port: 8299
    nodePort: ""  # Only used when type is NodePort
```

#### OtterScale Frontend

```yaml
otterscaleWeb:
  replicas: 1
  image:
    repository: ghcr.io/otterscale/otterscale/web
    tag: ""
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
  service:
    type: ClusterIP  # Options: ClusterIP, NodePort
    port: 3000
    nodePort: ""  # Only used when type is NodePort
```

#### PostgreSQL Database

```yaml
postgresql:
  enabled: true
  auth:
    username: "otterscale"
    password: ""  # Must be set
    database: "otterscale"
```

#### Keycloak

```yaml
keycloak:
  enabled: true
  auth:
    adminUser: admin
    adminPassword: ""  # Must be set
```

### Istio Integration

```yaml
istio:
  enabled: true
  sidecarInjection:
    enabled: true
  gateway:
    enabled: true
    name: otterscale-gateway
  virtualService:
    enabled: true
```

### Resource Scheduling

```yaml
global:
  nodeSelector:
    node-role: application
  tolerations:
    - key: "application"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                    - otterscale
            topologyKey: kubernetes.io/hostname
```

### Environment Variable Injection

```yaml
otterscale:
  env:
    - name: CUSTOM_VAR
      value: "custom-value"
  envFrom:
    - secretRef:
        name: my-secret
    - configMapRef:
        name: my-config

otterscaleWeb:
  extraEnv:
    - name: DEBUG
      value: "true"
```

## Upgrade

```bash
helm upgrade otterscale ./otterscale \
  --namespace otterscale \
  --values my-values.yaml
```

## Uninstall

```bash
helm uninstall otterscale --namespace otterscale
```

## Common Use Cases

### 1. Development Environment

```yaml
# dev-values.yaml
postgresql:
  enabled: true
  auth:
    password: "devpassword"
    postgresPassword: "devpostgres"

keycloak:
  enabled: true
  auth:
    adminPassword: "devadmin"

otterscale:
  replicas: 1
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"

istio:
  enabled: false
```

### 2. Production Environment

```yaml
# prod-values.yaml
postgresql:
  enabled: true
  auth:
    password: "STRONG_PASSWORD_HERE"
    postgresPassword: "STRONG_POSTGRES_PASSWORD"

keycloak:
  enabled: true
  auth:
    adminPassword: "STRONG_ADMIN_PASSWORD"

otterscale:
  replicas: 1

otterscaleWeb:
  replicas: 1

istio:
  enabled: true
```

### 3. Using External Database

```yaml
# external-db-values.yaml
postgresql:
  enabled: false

otterscaleWeb:
  extraEnv:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: external-db-secret
          key: connection-string
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n otterscale
kubectl describe pod <pod-name> -n otterscale
kubectl logs <pod-name> -n otterscale
```

### Check Istio Configuration

```bash
kubectl get gateway -n istio-system
kubectl get virtualservice -n istio-system
kubectl describe virtualservice otterscale -n istio-system
```

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL is ready
kubectl get pods -n otterscale -l app.kubernetes.io/name=postgresql

# Test connection
kubectl run postgresql-client --rm --tty -i --restart='Never' \
  --namespace otterscale \
  --image docker.io/bitnami/postgresql:latest \
  --env="PGPASSWORD=yourpassword" \
  --command -- psql --host otterscale-postgresql -U otterscale -d otterscale -p 5432
```

## Maintainers

- Terry Wu <terrywu25@gmail.com>

## License

See LICENSE file.

## Links

- [GitHub Repository](https://github.com/otterscale/charts)
- [Homepage](https://github.com/otterscale)
