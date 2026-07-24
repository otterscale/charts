# OtterScale Helm Chart

[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-otterscale-blue)](https://artifacthub.io)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A unified platform for simplified compute, storage, and networking.

## Prerequisites

- Kubernetes >= 1.25.0
- Helm >= 3.10.0
- (Optional) Envoy Gateway
- (Optional) `open-iscsi` on every node when `longhorn.enabled=true` — see [Storage (Longhorn)](#storage-longhorn)

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
# Download the example values (Envoy Gateway, HTTP via IP:port)
curl -o envoy-values.yaml https://raw.githubusercontent.com/otterscale/charts/refs/tags/otterscale-1.3.0/charts/otterscale/examples/envoy-values.yaml

helm repo add otterscale https://otterscale.github.io/charts
helm repo update

helm upgrade --install otterscale otterscale/otterscale \
  -n otterscale-system --create-namespace \
  --version 1.3.0 \
  -f envoy-values.yaml
```

Edit `envoy-values.yaml` to match your environment (at minimum, set `dashboard.externalURL` to your node IP) before installing.

### Install with HTTPS + custom domains

To serve OtterScale and Harbor over HTTPS on your own domains, use the
`envoy-values-domain-name.yaml` example instead. See
[TLS / HTTPS with custom domains](#tls--https-with-custom-domains) for the full
walkthrough.

```bash
curl -o envoy-values-domain-name.yaml https://raw.githubusercontent.com/otterscale/charts/refs/tags/otterscale-1.3.0/charts/otterscale/examples/envoy-values-domain-name.yaml

helm upgrade --install otterscale otterscale/otterscale \
  -n otterscale-system --create-namespace \
  --version 1.3.0 \
  -f envoy-values-domain-name.yaml
```

## Networking Modes

OtterScale is exposed through **Envoy Gateway** (path-based routing via the
Gateway API). `dashboard.externalURL` is always required — every
external-facing URL (OIDC issuer, CORS origins, server/tunnel URLs) is derived
from it.

### Envoy Gateway (recommended)

Single entry point with path-based routing via the [Kubernetes Gateway
API](https://gateway-api.sigs.k8s.io/). When `envoy.gateway.create` is `true`
(default), the chart provisions the `GatewayClass`, `EnvoyProxy`, `Gateway` and
`HTTPRoute` resources for you.

**HTTP, accessed by IP\:port** — see [`examples/envoy-values.yaml`](examples/envoy-values.yaml):

```yaml
dashboard:
  externalURL: "http://192.168.1.100:30080"

server:
  externalURL: "http://192.168.1.100:30080/api/"
  externalTunnelURL: "https://192.168.1.100:30300"
  tunnelService:
    type: NodePort
    nodePort: "30300"

harbor:
  externalURL: "http://192.168.1.100:32180"

envoy:
  enabled: true
  gatewayClassName: "eg"
  gateway:
    create: true
    name: "otterscale"
    namespace: "envoy-gateway-system"
```

Routing (single host, path-based):

```
http://<ip>:30080/        -> Dashboard
http://<ip>:30080/api/    -> Server API
http://<ip>:30080/auth/   -> Keycloak
http://<ip>:32180/        -> Harbor (its own NodePort)
```

### TLS / HTTPS with custom domains

Set `envoy.tls.enabled: true` to add an HTTPS listener (port 443, NodePort 30443) and serve OtterScale and Harbor on separate domains. The chart then also
generates a Harbor `HTTPRoute` and an HTTP→HTTPS 301 redirect. See
[`examples/envoy-values-domain-name.yaml`](examples/envoy-values-domain-name.yaml):

```yaml
dashboard:
  externalURL: "https://otterscale.phison.com"

server:
  externalURL: "https://otterscale.phison.com/api/"
  externalTunnelURL: "https://otterscale.phison.com:30300"
  tunnelService:
    type: NodePort
    nodePort: "30300"

harbor:
  externalURL: "https://cr.phison.com"

envoy:
  enabled: true
  gatewayClassName: "eg"
  gateway:
    create: true
    name: "otterscale"
    namespace: "envoy-gateway-system"
  tls:
    enabled: true
    redirectToHTTPS: true
    existingSecret: "phison-new-2026" # OR provide crt/key below
    # crt: |
    #   -----BEGIN CERTIFICATE-----
    #   ...
    # key: |
    #   -----BEGIN PRIVATE KEY-----
    #   ...
```

The certificate can be supplied two ways:

| Option              | How                                         | Notes                                                                                                                                       |
| ------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Existing Secret** | `envoy.tls.existingSecret: <name>`          | The `kubernetes.io/tls` Secret **must already exist in the Gateway namespace** (`envoy.gateway.namespace`, default `envoy-gateway-system`). |
| **Inline cert**     | `envoy.tls.crt` + `envoy.tls.key` (raw PEM) | The chart creates the Secret for you in the Gateway namespace. Takes priority over `existingSecret`.                                        |

**Before installing the HTTPS variant:**

1. **Envoy Gateway is installed** in the cluster (its controller lives in
   `envoy-gateway-system`).
2. **TLS Secret** exists in `envoy-gateway-system` when using `existingSecret`:

   ```bash
   kubectl create secret tls phison-new-2026 \
     --cert=tls.crt --key=tls.key -n envoy-gateway-system
   ```

3. **DNS** for both domains resolves to the cluster ingress (Envoy's 443 —
   NodePort `30443` or a fronting load balancer).

> **OIDC note:** Keycloak's hostname is pinned to `dashboard.externalURL` + the
> Keycloak relative path so the OIDC issuer always matches what the server and
> dashboard expect — no manual Keycloak hostname tuning is required.

## Parameters

### Global

| Parameter                 | Description                            | Default |
| ------------------------- | -------------------------------------- | ------- |
| `global.imageRegistry`    | Override image registry for all images | `""`    |
| `global.imagePullSecrets` | Global image pull secrets              | `[]`    |
| `global.nodeSelector`     | nodeSelector for every chart-rendered pod (subchart pods excluded; component-level entries win) | `{}` |
| `nameOverride`            | Override chart name in resource names  | `""`    |
| `fullnameOverride`        | Override full resource name prefix     | `""`    |

### Storage (Longhorn)

Setting `longhorn.enabled=true` deploys the [Longhorn](https://longhorn.io)
subchart: replicated block storage backed by each node's local disk. Volumes
survive node failures as long as a healthy replica remains (StorageClass name:
`longhorn`). Keys under `longhorn.*` other than `enabled` pass through to the
[Longhorn chart](https://github.com/longhorn/charts).

**Node prerequisites** (every node — verify with `longhornctl check preflight`):

- `open-iscsi` installed and the `iscsid` daemon running
  (Ubuntu: `apt-get install open-iscsi`; RHEL: `dnf install iscsi-initiator-utils && systemctl enable --now iscsid`)
- NFSv4 client (`nfs-common` / `nfs-utils`) — required for RWX volumes
- The data path filesystem must be ext4 or XFS
- On RHEL, blacklist Longhorn devices in `multipath.conf` if `multipathd` is enabled

| Parameter                                     | Description                                                | Default                   |
| --------------------------------------------- | ---------------------------------------------------------- | ------------------------- |
| `longhorn.enabled`                            | Deploy the Longhorn subchart                               | `false`                   |
| `longhorn.persistence.defaultClass`           | Set `longhorn` as cluster default StorageClass             | `false`                   |
| `longhorn.persistence.defaultClassReplicaCount` | Replicas per volume (set `1` on single-node clusters)    | `2`                       |
| `longhorn.persistence.reclaimPolicy`          | Reclaim policy: `Retain` or `Delete`                       | `Retain`                  |
| `longhorn.defaultSettings.defaultDataPath`    | Host path for replica storage                              | `/opt/otterscale/storage` |

#### Uninstalling with Longhorn enabled

Uninstalling destroys all data on Longhorn volumes, so Longhorn requires an
explicit confirmation flag first:

```bash
kubectl -n otterscale-system patch settings.longhorn.io deleting-confirmation-flag \
  --type merge -p '{"value":"true"}'

helm uninstall otterscale -n otterscale-system --timeout 15m
```

A chart pre-delete hook (`longhorn.uninstallCleanup`, enabled by default) then
enforces the teardown order automatically: it scales down the PVC consumers
and deletes all `longhorn`-class PVCs **while the CSI driver is still
running**, before Longhorn's own uninstaller runs. Without this ordering the
CSI driver disappears first and the uninstall hangs on pod/PVC finalizers.
Notes:

- If the flag is not set, the hook aborts the uninstall immediately with
  instructions — nothing gets deleted.
- A post-delete hook removes the `longhorn` StorageClass afterwards (it is
  created at runtime by longhorn-manager, so plain uninstall leaves it
  behind). Longhorn is deployed for otterscale's exclusive use.
- Use a generous `--timeout` (15m): the hook waits for volume teardown.
- `helm uninstall --no-hooks` bypasses both this hook and Longhorn's
  uninstaller — expect stuck finalizers if you use it.
- Never remove Longhorn with `helm upgrade --set longhorn.enabled=false`
  while volumes exist — pre-delete hooks do not run on upgrades and Longhorn
  CRs get stuck on finalizers.
- Longhorn upgrades must not skip minor versions.

#### Using a different StorageClass

The chart pins its PVCs to the `longhorn` StorageClass. To use another one,
override all of:

```yaml
keycloakx:
  database:
    persistence:
      storageClassName: "<your-storageclass>"
harbor:
  persistence:
    persistentVolumeClaim:
      registry: { storageClass: "<your-storageclass>" }
      database: { storageClass: "<your-storageclass>" }
      jobservice: { jobLog: { storageClass: "<your-storageclass>" } }
      redis: { storageClass: "<your-storageclass>" }
      trivy: { storageClass: "<your-storageclass>" }
```

#### Upgrading from a local-path release (chart <= 1.4.0-rc.1)

Releases that installed with `storage.localPath.enabled=true` have PVCs bound
to the `otterscale-local-path` StorageClass. `storageClassName` is immutable,
so a plain `helm upgrade` to this version **fails** when it tries to repoint
those PVCs at `longhorn`. Existing data is not touched — the upgrade is simply
rejected. Choose one of:

1. **Keep data in place (no replication):** upgrade with every storageClass
   value above set to `otterscale-local-path`. Bound hostPath volumes keep
   working without the provisioner, but new volumes can no longer be
   provisioned on that class.
2. **Migrate to Longhorn:** back up, scale each consumer down, copy data to a
   new Longhorn PVC (e.g. [pv-migrate](https://github.com/utkuozdemir/pv-migrate)
   or an rsync Job), then swap the claim.
3. **Reinstall:** if the data is reproducible (registry images can be
   re-pushed; the Keycloak realm is re-created by the chart), uninstall and
   install fresh with `longhorn.enabled=true`.

### Server

| Parameter                          | Description                                      | Default                         |
| ---------------------------------- | ------------------------------------------------ | ------------------------------- |
| `server.externalURL`               | Override server external URL for clients         | `""`                            |
| `server.externalTunnelURL`         | Override server external tunnel URL for agents   | `""`                            |
| `server.replicaCount`              | Number of replicas                               | `1`                             |
| `server.image.repository`          | Server image repository                          | `ghcr.io/otterscale/otterscale` |
| `server.image.tag`                 | Image tag                                        | `""`                            |
| `server.ports.http`                | HTTP API port                                    | `8299`                          |
| `server.ports.tunnel`              | Tunnel port                                      | `8300`                          |
| `server.service.type`              | HTTP Service type                                | `ClusterIP`                     |
| `server.tunnelService.type`        | Tunnel Service type                              | `ClusterIP`                     |
| `server.tunnelService.nodePort`    | NodePort for tunnel                              | `""`                            |
| `server.revisionHistoryLimit`      | ReplicaSet revision history limit                | `3`                             |
| `server.resources.requests.cpu`    | CPU request                                      | `500m`                          |
| `server.resources.requests.memory` | Memory request                                   | `512Mi`                         |
| `server.resources.limits.memory`   | Memory limit                                     | `1024Mi`                        |
| `server.autoscaling.enabled`       | Enable HPA                                       | `false`                         |
| `server.autoscaling.minReplicas`   | Minimum replicas                                 | `1`                             |
| `server.autoscaling.maxReplicas`   | Maximum replicas                                 | `5`                             |
| `server.pdb.create`                | Create PodDisruptionBudget                       | `false`                         |
| `server.networkPolicy.enabled`     | Create NetworkPolicy                             | `false`                         |
| `server.serviceMonitor.enabled`    | Create Prometheus ServiceMonitor                 | `false`                         |

### Dashboard

| Parameter                             | Description                                               | Default                        |
| ------------------------------------- | --------------------------------------------------------- | ------------------------------ |
| `dashboard.externalURL`               | Base external URL, e.g. `http://192.168.1.100` (required) | `""`                           |
| `dashboard.replicaCount`              | Number of replicas                                        | `1`                            |
| `dashboard.image.repository`          | Dashboard image repository                                | `ghcr.io/otterscale/dashboard` |
| `dashboard.image.tag`                 | Image tag                                                 | `""`                           |
| `dashboard.ports.http`                | HTTP port                                                 | `3000`                         |
| `dashboard.service.type`              | Service type                                              | `ClusterIP`                    |
| `dashboard.resources.requests.cpu`    | CPU request                                               | `100m`                         |
| `dashboard.resources.requests.memory` | Memory request                                            | `128Mi`                        |
| `dashboard.resources.limits.memory`   | Memory limit                                              | `256Mi`                        |
| `dashboard.autoscaling.enabled`       | Enable HPA                                                | `false`                        |
| `dashboard.pdb.create`                | Create PodDisruptionBudget                                | `false`                        |
| `dashboard.networkPolicy.enabled`     | Create NetworkPolicy                                      | `false`                        |
| `dashboard.serviceMonitor.enabled`    | Create Prometheus ServiceMonitor                          | `false`                        |

### Envoy Gateway (Gateway API)

> **Prerequisites:** Envoy Gateway must be installed in the cluster (it provides
> the [Gateway API](https://gateway-api.sigs.k8s.io/) CRDs and the controller in
> `envoy-gateway-system`).

| Parameter                   | Description                                                                   | Default                  |
| --------------------------- | ----------------------------------------------------------------------------- | ------------------------ |
| `envoy.enabled`             | Enable Envoy Gateway integration                                              | `false`                  |
| `envoy.gatewayClassName`    | GatewayClass name backed by the Envoy Gateway controller                      | `"eg"`                   |
| `envoy.httpRoute.hostnames` | Override HTTPRoute hostnames (defaults to the `externalURL` host when TLS on) | `[]`                     |
| `envoy.tls.enabled`         | Add an HTTPS listener (TLS termination at the Gateway)                        | `false`                  |
| `envoy.tls.crt`             | PEM certificate; chart creates the TLS Secret (raw PEM, not base64)           | `""`                     |
| `envoy.tls.key`             | PEM private key paired with `envoy.tls.crt`                                   | `""`                     |
| `envoy.tls.existingSecret`  | Reference an existing TLS Secret (must be in the Gateway namespace)           | `""`                     |
| `envoy.tls.redirectToHTTPS` | Add an HTTP→HTTPS 301 redirect HTTPRoute                                      | `true`                   |
| `envoy.gateway.create`      | Let the chart create the Gateway / GatewayClass / EnvoyProxy                  | `true`                   |
| `envoy.gateway.name`        | Gateway resource name                                                         | `"otterscale"`           |
| `envoy.gateway.namespace`   | Namespace for the Gateway, EnvoyProxy and chart-managed TLS Secret            | `"envoy-gateway-system"` |

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
