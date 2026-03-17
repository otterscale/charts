# OtterScale Helm Chart

[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-otterscale-blue)](https://artifacthub.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A unified platform for simplified compute, storage, and networking.

## Prerequisites

- Kubernetes >= 1.25.0
- Helm >= 3.10.0
- (Optional) NGINX Ingress Controller or Istio service mesh

**Components:**

| Component     | Description                                  | Default |
| ------------- | -------------------------------------------- | ------- |
| **Server**    | Backend API + tunnel service                 | Enabled |
| **Dashboard** | Web UI frontend                              | Enabled |
| **Keycloak**  | OAuth2/OIDC identity provider                | Enabled |
| **Valkey**    | Redis-compatible session cache for Dashboard | Enabled |
| **Harbor**    | Container registry with image scanning       | Enabled |

## Default Credentials

| Service   | Username | Password   |
| --------- | -------- | ---------- |
| Dashboard | `admin`  | `password` |

> **Note:** You will be required to change the password on first login.

## Quick Start

### Install with Helm

```bash
helm repo add otterscale https://otterscale.github.io/charts
helm repo update

helm install otterscale otterscale/otterscale \
  --set dashboard.externalURL=http://<YOUR_NODE_IP>
```

### Install from source

```bash
cd charts/charts/otterscale
helm dependency build
helm install otterscale . \
  --set dashboard.externalURL=http://<YOUR_NODE_IP>
```

### Install with overrides

```bash
helm install otterscale . -f overrides.yaml
```

## Networking Modes

OtterScale supports three mutually exclusive networking modes:

### 1. NodePort (default)

Simplest setup. Services are exposed directly via NodePort.

```yaml
dashboard:
  externalURL: "http://192.168.1.100"

server:
  service:
    type: NodePort
    nodePorts:
      http: "30299"
      tunnel: "30300"
```

Access:

- API: `http://192.168.1.100:30299`
- Tunnel: `https://192.168.1.100:30300`

### 2. Kubernetes Ingress

Path-based routing through an Ingress Controller (e.g., NGINX).

```yaml
dashboard:
  externalURL: "http://192.168.1.100"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: ""
      paths:
        - path: /
          pathType: Prefix
          service: dashboard
        - path: /api
          pathType: Prefix
          service: server
          rewrite: true
        - path: /auth/
          pathType: Prefix
          service: keycloak
```

Access:

- Dashboard: `http://192.168.1.100/`
- API: `http://192.168.1.100/api/`
- Keycloak: `http://192.168.1.100/auth/`

### 3. Istio Service Mesh

Full service mesh with mTLS, traffic management, and observability.

```yaml
dashboard:
  externalURL: "https://192.168.1.100"

istio:
  enabled: true
  tls:
    existingSecret: "otterscale-tls"
  gateway:
    enabled: true
    hosts:
      - "otterscale.example.com"
```

## Local Development with KIND

### 1. Create cluster

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30299
        hostPort: 30299
        protocol: TCP
      - containerPort: 30300
        hostPort: 30300
        protocol: TCP
      - containerPort: 32180
        hostPort: 32180
        protocol: TCP
```

```bash
kind create cluster --config kind-config.yaml
```

### 2. Deploy NGINX Ingress Controller (KIND-specific)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 3. Install OtterScale

```yaml
# overrides.yaml
dashboard:
  externalURL: "http://192.168.1.100"

harbor:
  externalURL: http://192.168.1.100:32180

server:
  externalURL: "http://192.168.1.100:30299"
  externalTunnelURL: "https://192.168.1.100:30300"
  service:
    type: NodePort
    nodePorts:
      http: "30299"
      tunnel: "30300"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: ""
      paths:
        - path: /
          pathType: Prefix
          service: dashboard
        - path: /api
          pathType: Prefix
          service: server
          rewrite: true
        - path: /auth/
          pathType: Prefix
          service: keycloak
```

```bash
helm dependency build
helm install otterscale . -f overrides.yaml
```

### 4. Access

```
http://192.168.1.100/           -> Dashboard
http://192.168.1.100/api/       -> Server API
http://192.168.1.100/auth/      -> Keycloak
```

## Parameters

### Global

| Parameter                 | Description                            | Default |
| ------------------------- | -------------------------------------- | ------- |
| `global.imageRegistry`    | Override image registry for all images | `""`    |
| `global.imagePullSecrets` | Global image pull secrets              | `[]`    |
| `global.storageClass`     | Default StorageClass for all PVCs      | `""`    |
| `nameOverride`            | Override chart name in resource names  | `""`    |
| `fullnameOverride`        | Override full resource name prefix     | `""`    |

### Storage

| Parameter                            | Description                          | Default                   |
| ------------------------------------ | ------------------------------------ | ------------------------- |
| `storage.localPath.enabled`          | Deploy local-path-provisioner        | `false`                   |
| `storage.localPath.path`             | Host path for volume storage         | `/opt/otterscale/storage` |
| `storage.localPath.storageClassName` | StorageClass name                    | `otterscale-local-path`   |
| `storage.localPath.isDefault`        | Set as cluster default StorageClass  | `true`                    |
| `storage.localPath.reclaimPolicy`    | Reclaim policy: `Retain` or `Delete` | `Retain`                  |

### Server

| Parameter                          | Description                                    | Default                         |
| ---------------------------------- | ---------------------------------------------- | ------------------------------- |
| `server.externalURL`               | Override server external URL for clients       | `""`                            |
| `server.externalTunnelURL`         | Override server external tunnel URL for agents | `""`                            |
| `server.replicaCount`              | Number of replicas                             | `1`                             |
| `server.image.repository`          | Server image repository                        | `ghcr.io/otterscale/otterscale` |
| `server.image.tag`                 | Image tag (defaults to `appVersion`)           | `""`                            |
| `server.ports.http`                | HTTP API port                                  | `8299`                          |
| `server.ports.tunnel`              | Tunnel port                                    | `8300`                          |
| `server.service.type`              | Service type                                   | `ClusterIP`                     |
| `server.service.nodePorts.http`    | NodePort for HTTP                              | `""`                            |
| `server.service.nodePorts.tunnel`  | NodePort for tunnel                            | `""`                            |
| `server.revisionHistoryLimit`      | ReplicaSet revision history limit              | `3`                             |
| `server.resources.requests.cpu`    | CPU request                                    | `500m`                          |
| `server.resources.requests.memory` | Memory request                                 | `512Mi`                         |
| `server.resources.limits.memory`   | Memory limit                                   | `1024Mi`                        |
| `server.autoscaling.enabled`       | Enable HPA                                     | `false`                         |
| `server.autoscaling.minReplicas`   | Minimum replicas                               | `1`                             |
| `server.autoscaling.maxReplicas`   | Maximum replicas                               | `5`                             |
| `server.pdb.create`                | Create PodDisruptionBudget                     | `false`                         |
| `server.networkPolicy.enabled`     | Create NetworkPolicy                           | `false`                         |
| `server.serviceMonitor.enabled`    | Create Prometheus ServiceMonitor               | `false`                         |

### Dashboard

| Parameter                             | Description                                               | Default                        |
| ------------------------------------- | --------------------------------------------------------- | ------------------------------ |
| `dashboard.externalURL`               | Base external URL, e.g. `http://192.168.1.100` (required) | `""`                           |
| `dashboard.replicaCount`              | Number of replicas                                        | `1`                            |
| `dashboard.image.repository`          | Dashboard image repository                                | `ghcr.io/otterscale/dashboard` |
| `dashboard.image.tag`                 | Image tag (defaults to `appVersion`)                      | `""`                           |
| `dashboard.ports.http`                | HTTP port                                                 | `3000`                         |
| `dashboard.service.type`              | Service type                                              | `ClusterIP`                    |
| `dashboard.resources.requests.cpu`    | CPU request                                               | `100m`                         |
| `dashboard.resources.requests.memory` | Memory request                                            | `128Mi`                        |
| `dashboard.resources.limits.memory`   | Memory limit                                              | `256Mi`                        |
| `dashboard.autoscaling.enabled`       | Enable HPA                                                | `false`                        |
| `dashboard.pdb.create`                | Create PodDisruptionBudget                                | `false`                        |
| `dashboard.networkPolicy.enabled`     | Create NetworkPolicy                                      | `false`                        |
| `dashboard.serviceMonitor.enabled`    | Create Prometheus ServiceMonitor                          | `false`                        |

### Ingress

| Parameter                         | Description                         | Default                        |
| --------------------------------- | ----------------------------------- | ------------------------------ |
| `ingress.enabled`                 | Enable Kubernetes Ingress           | `false`                        |
| `ingress.className`               | IngressClass name                   | `""`                           |
| `ingress.annotations`             | Ingress annotations                 | `{}`                           |
| `ingress.hosts`                   | Host routing rules                  | See [values.yaml](values.yaml) |
| `ingress.hosts[].paths[].rewrite` | Strip path prefix before forwarding | `false`                        |
| `ingress.tls`                     | TLS configuration                   | `[]`                           |

### Istio

| Parameter                        | Description              | Default |
| -------------------------------- | ------------------------ | ------- |
| `istio.enabled`                  | Enable Istio integration | `false` |
| `istio.sidecarInjection.enabled` | Inject Istio sidecar     | `true`  |
| `istio.virtualService.enabled`   | Create VirtualService    | `true`  |
| `istio.tls.existingSecret`       | TLS Secret for Gateway   | `""`    |
| `istio.gateway.enabled`          | Create Gateway resource  | `true`  |
| `istio.gateway.existingGateway`  | Use existing Gateway     | `""`    |
| `istio.gateway.hosts`            | Gateway host match       | `["*"]` |

### Keycloak

| Parameter                             | Description                                       | Default                |
| ------------------------------------- | ------------------------------------------------- | ---------------------- |
| `keycloakx.enabled`                   | Deploy Keycloak                                   | `true`                 |
| `keycloakx.realm`                     | Realm name                                        | `otterscale`           |
| `keycloakx.auth.adminUser`            | Admin username                                    | `admin`                |
| `keycloakx.auth.adminPassword`        | Admin password (auto-generated if empty)          | `""`                   |
| `keycloakx.clients.dashboard.id`      | OIDC client ID for dashboard & server             | `otterscale-dashboard` |
| `keycloakx.clients.dashboard.secret`  | Dashboard client secret (auto-generated if empty) | `""`                   |
| `keycloakx.clients.harbor.id`         | OIDC client ID for Harbor                         | `otterscale-harbor`    |
| `keycloakx.clients.harbor.secret`     | Harbor client secret (auto-generated if empty)    | `""`                   |
| `keycloakx.database.persistence.size` | PostgreSQL PVC size                               | `5Gi`                  |

### Valkey

| Parameter                   | Description                        | Default |
| --------------------------- | ---------------------------------- | ------- |
| `dashboard-valkey.enabled`  | Deploy Valkey session cache        | `true`  |
| `dashboard-valkey.port`     | Valkey service port                | `6379`  |
| `dashboard-valkey.password` | Password (auto-generated if empty) | `""`    |

### Harbor

| Parameter                                                | Description                                                                             | Default                  |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------ |
| `harbor.enabled`                                         | Deploy Harbor registry                                                                  | `true`                   |
| `harbor.externalURL`                                     | Harbor external URL                                                                     | `http://127.0.0.1:32180` |
| `harbor.harborAdminPassword`                             | Admin password (auto-generated if empty)                                                | `""`                     |
| `harbor.expose.*`                                        | Harbor expose config ([see Harbor chart docs](https://github.com/goharbor/harbor-helm)) | `ingress`                |
| `harbor.persistence.persistentVolumeClaim.registry.size` | Registry storage                                                                        | `50Gi`                   |
| `harbor.oidc.enabled`                                    | Enable OIDC with Keycloak                                                               | `true`                   |

## Security

All pods run with hardened security contexts by default:

- Non-root user (UID 65532)
- Read-only root filesystem
- No privilege escalation
- All Linux capabilities dropped
- Seccomp profile: `RuntimeDefault`

Sensitive credentials (Keycloak admin, client secrets, Valkey password) are auto-generated on first install and persisted in Kubernetes Secrets via `lookup` to survive upgrades.

## Verify Installation

```bash
helm test otterscale
```

Retrieve Keycloak admin credentials:

```bash
kubectl get secret otterscale-keycloakx-admin \
  -o jsonpath="{.data.KC_BOOTSTRAP_ADMIN_PASSWORD}" | base64 -d
```

## Uninstall

```bash
helm uninstall otterscale
```

> **Note:** PersistentVolumeClaims are not deleted automatically. To fully clean up:
>
> ```bash
> kubectl delete pvc -l app.kubernetes.io/instance=otterscale
> ```

## License

Apache License 2.0 - see [LICENSE](https://github.com/otterscale/otterscale/blob/main/LICENSE) for details.
