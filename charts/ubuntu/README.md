# Ubuntu Helm Chart

This Helm chart deploys Ubuntu containers with SSH access via NodePort, persistent storage, and customizable initialization scripts for Kubernetes clusters.

## Features

- **SSH Access**: Secure SSH access via NodePort for external connectivity
- **Persistent Storage**: StatefulSet with volumeClaimTemplates for persistent data
- **Customizable Initialization**: Pre/post scripts for system configuration and package installation
- **Resource Management**: Configurable CPU and memory limits/requests
- **Security**: Support for SSH key authentication and password-based access
- **Health Checks**: Exec-based liveness, readiness, and startup probes for the SSH service

## Prerequisites

- Kubernetes cluster 1.19+
- Helm 3.0+
- Storage provisioner for persistent volumes (if persistence is enabled)

## Installation

### Basic Installation

```bash
helm install my-ubuntu ./ubuntu
```

### Custom Installation

Create a `custom-values.yaml` file:

```yaml
ssh:
  rootPassword: "your-secure-password"
  nodePort: 30022

persistence:
  enabled: true
  size: 20Gi
  storageClassName: "standard"

resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 1000m
    memory: 2Gi
```

Install with custom values:

```bash
helm install my-ubuntu ./ubuntu -f custom-values.yaml
```

## Configuration

### Image Configuration

```yaml
image:
  repository: ubuntu
  tag: "24.04"
  pullPolicy: IfNotPresent
```

- `repository`: Ubuntu Docker image repository
- `tag`: Ubuntu version (24.04, 22.04, 20.04, etc.)
- `pullPolicy`: Image pull policy (IfNotPresent/Always/Never)

### SSH Configuration

```yaml
ssh:
  enabled: true
  rootPassword: "ubuntu"
  authorizedKeys: ""
  permitRootLogin: "yes"
  passwordAuthentication: "yes"
```

- `enabled`: Enable SSH server (default: true)
- `rootPassword`: Root password for SSH access (stored in Secret)
- `authorizedKeys`: SSH public keys for passwordless authentication
- `permitRootLogin`: Allow root login via SSH (yes/no/prohibit-password)
- `passwordAuthentication`: Enable password authentication (yes/no)

**Example with SSH Keys**:

```yaml
ssh:
  enabled: true
  rootPassword: "" # Disable password auth
  passwordAuthentication: "no"
  authorizedKeys: |
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@laptop
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@workstation
```

### Service Configuration

```yaml
service:
  type: NodePort
  port: 22
  targetPort: 22
  nodePort: 30022
  annotations: {}
```

- `type`: Service type (NodePort/ClusterIP/LoadBalancer)
- `port`: Service external port
- `targetPort`: Container internal port (SSH: 22)
- `nodePort`: Fixed NodePort (30000-32767), leave empty for auto-assignment
- `annotations`: Service annotations

### Persistent Storage

```yaml
persistence:
  enabled: true
  storageClassName: ""
  accessMode: ReadWriteOnce
  size: 10Gi
  mountPath: /data
  annotations: {}
```

- `enabled`: Enable persistent storage via PVC
- `storageClassName`: Storage class name ("" for default)
- `accessMode`: Access mode (ReadWriteOnce/ReadWriteMany/ReadOnlyMany)
- `size`: Storage size (e.g., 10Gi, 50Gi, 1Ti)
- `mountPath`: Mount path in container (default: /data)
- `annotations`: PVC annotations

### Precondition and Post Scripts

#### Prescript

Runs in the main container's startup command before the SSH server is launched. Use for:

- Installing packages
- System configuration
- Mounting external storage (NFS, etc.)
- Setting up dependencies

```yaml
prescript: |
  echo "=== Installing development tools ==="
  apt-get update
  apt-get install -y curl wget git vim nano build-essential
  apt-get install -y python3 python3-pip

  # Install Docker CLI
  apt-get install -y docker.io

  # Mount NFS (if needed)
  apt-get install -y nfs-common
  mkdir -p /mnt/nfs
  mount -t nfs4 -o nfsvers=4.1 10.0.0.100:/exports/data /mnt/nfs

  echo "=== Prescript completed ==="
```

#### Postscript

Runs in main container after SSH starts. Use for:

- Background services
- Monitoring tasks
- Post-initialization notifications

```yaml
postscript: |
  echo "=== Starting additional services ==="

  # Example: Start a simple web server
  # python3 -m http.server 8080 &

  # Example: Run monitoring script
  # /data/scripts/monitor.sh &

  echo "=== Ubuntu container ready ==="
```

### Resource Configuration

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

- `limits.cpu`: Maximum CPU (in millicores or cores)
- `limits.memory`: Maximum memory (e.g., 4Gi, 8Gi)
- `requests.cpu`: Requested CPU for scheduling
- `requests.memory`: Requested memory for scheduling

### Health Probes

```yaml
livenessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - "ps aux | grep '[s]shd' && test -f /var/run/sshd.pid"
  initialDelaySeconds: 30
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - "netstat -tlnp | grep ':22 ' || ss -tlnp | grep ':22 '"
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - "ps aux | grep '[s]shd' && netstat -tlnp 2>/dev/null | grep ':22 ' || ss -tlnp 2>/dev/null | grep ':22 '"
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30
```

**Health Check Improvements:**

- **Exec-based probes** instead of TCP socket to avoid connection spam in SSH logs
- **Liveness probe**: Checks if sshd process is running and PID file exists
- **Readiness probe**: Verifies SSH is listening on port 22 using netstat/ss
- **Startup probe**: Allows up to 150 seconds (30 failures × 5s) for initial SSH installation and configuration

The exec-based approach is more reliable and doesn't create excessive "Connection closed" messages in SSH logs.

### Additional Configuration

```yaml
# Additional environment variables
env:
  - name: TZ
    value: "Asia/Taipei"
  - name: LANG
    value: "en_US.UTF-8"

# Node selector
nodeSelector:
  kubernetes.io/hostname: worker-01

# Tolerations
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "ubuntu"
    effect: "NoSchedule"

# Additional volumes
extraVolumes:
  - name: shared-storage
    emptyDir: {}

extraVolumeMounts:
  - name: shared-storage
    mountPath: /shared
```

## Usage Examples

### Example 1: Basic Development Environment

```yaml
image:
  repository: ubuntu
  tag: "24.04"

ssh:
  rootPassword: "dev123"
  nodePort: 30022

persistence:
  enabled: true
  size: 20Gi

prescript: |
  apt-get update
  apt-get install -y curl wget git vim python3 python3-pip nodejs npm
  pip3 install jupyter pandas numpy matplotlib

resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 1000m
    memory: 2Gi
```

Deploy:

```bash
helm install dev-ubuntu ./ubuntu -f dev-values.yaml
```

Access:

```bash
# Get the NodePort
kubectl get svc

# SSH into the container
ssh root@<node-ip> -p 30022
# Password: dev123
```

### Example 2: NFS-Backed Ubuntu with SSH Keys

```yaml
ssh:
  rootPassword: ""
  passwordAuthentication: "no"
  authorizedKeys: |
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... admin@laptop

persistence:
  enabled: true
  size: 50Gi
  storageClassName: "nfs-storage"

prescript: |
  apt-get update
  apt-get install -y nfs-common

  # Mount NFS share
  mkdir -p /mnt/shared
  mount -t nfs4 10.0.0.200:/exports/shared /mnt/shared

  # Verify mount
  df -h | grep /mnt/shared

  # Install utilities
  apt-get install -y htop tmux rsync

resources:
  limits:
    cpu: 2000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

Access:

```bash
ssh root@<node-ip> -p 30022 -i ~/.ssh/id_rsa
```

### Example 3: Build Server with Docker

```yaml
ssh:
  rootPassword: "build-secure-pwd"

securityContext:
  privileged: true # Required for Docker-in-Docker

persistence:
  enabled: true
  size: 100Gi

prescript: |
  apt-get update

  # Install Docker
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Install build tools
  apt-get install -y build-essential git make cmake

postscript: |
  # Start Docker daemon
  dockerd &
  sleep 5
  docker info

resources:
  limits:
    cpu: 8000m
    memory: 16Gi
  requests:
    cpu: 2000m
    memory: 4Gi
```

### Example 4: Data Science Workspace

```yaml
ssh:
  rootPassword: "datascience"

persistence:
  enabled: true
  size: 100Gi
  mountPath: /workspace

prescript: |
  apt-get update
  apt-get install -y python3 python3-pip python3-dev

  # Install data science packages
  pip3 install --upgrade pip
  pip3 install jupyter jupyterlab pandas numpy scipy matplotlib seaborn scikit-learn
  pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
  pip3 install tensorflow keras

  # Install additional tools
  apt-get install -y git curl wget vim

postscript: |
  # Start Jupyter Lab in background
  cd /workspace
  nohup jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root > /var/log/jupyter.log 2>&1 &
  echo "Jupyter Lab started on port 8888"

service:
  type: NodePort
  # Expose both SSH and potentially Jupyter

resources:
  limits:
    cpu: 8000m
    memory: 16Gi
  requests:
    cpu: 2000m
    memory: 8Gi
```

## Accessing the Ubuntu Container

### Via SSH

1. Get the NodePort:

```bash
kubectl get svc -l app.kubernetes.io/name=ubuntu
```

2. Get a node IP:

```bash
kubectl get nodes -o wide
```

3. SSH into the container:

```bash
# With password
ssh root@<node-ip> -p <nodePort>

# With SSH key
ssh root@<node-ip> -p <nodePort> -i ~/.ssh/id_rsa
```

### Via kubectl exec

```bash
# Get pod name
kubectl get pods -l app.kubernetes.io/name=ubuntu

# Execute bash
kubectl exec -it <pod-name> -- /bin/bash
```

## Working with Persistent Storage

Data stored in the `/data` directory (or your configured `mountPath`) persists across pod restarts:

```bash
# Inside the container
cd /data

# Create files
echo "persistent data" > /data/myfile.txt

# Install applications to /data
mkdir -p /data/apps
```

## Upgrading

```bash
helm upgrade my-ubuntu ./ubuntu -f custom-values.yaml
```

**Note**: Upgrading preserves persistent volumes but may restart pods.

## Uninstall

```bash
helm uninstall my-ubuntu
```

**Warning**: This deletes the StatefulSet but retains PersistentVolumeClaims by default. To delete PVCs:

```bash
kubectl delete pvc -l app.kubernetes.io/name=ubuntu
```

## Security Considerations

### Production Best Practices

1. **Use SSH Keys**: Disable password authentication in production

```yaml
ssh:
  passwordAuthentication: "no"
  authorizedKeys: |
    ssh-rsa AAAAB3NzaC1yc2E... admin@trusted-host
```

2. **Strong Passwords**: If using passwords, use strong, randomly generated passwords

```bash
# Generate random password
openssl rand -base64 32
```

3. **Network Policies**: Restrict SSH access with NetworkPolicies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ubuntu-ssh-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: ubuntu
  policyTypes:
    - Ingress
  ingress:
    - from:
        - ipBlock:
            cidr: 10.0.0.0/8 # Only internal network
      ports:
        - protocol: TCP
          port: 22
```

4. **Resource Limits**: Always set resource limits to prevent resource exhaustion

5. **Regular Updates**: Keep Ubuntu image updated

```bash
helm upgrade my-ubuntu ./ubuntu --set image.tag=24.04
```

6. **Audit Logging**: Enable SSH logging and monitor access

7. **Principle of Least Privilege**: Consider running as non-root user when possible

## Troubleshooting

### SSH Connection Refused

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=ubuntu

# Check pod logs
kubectl logs <pod-name>

# Check SSH service inside container
kubectl exec <pod-name> -- ps aux | grep sshd
kubectl exec <pod-name> -- netstat -tlnp | grep 22
```

### Persistent Volume Not Mounting

```bash
# Check PVC status
kubectl get pvc

# Describe PVC for events
kubectl describe pvc data-<statefulset-name>-0

# Check storage class
kubectl get storageclass
```

### Initialization Script Failures

```bash
# Check main container logs
kubectl logs <pod-name>
```

### Password Authentication Not Working

Ensure password authentication is enabled:

```yaml
ssh:
  passwordAuthentication: "yes"
  permitRootLogin: "yes"
```

And verify inside container:

```bash
kubectl exec <pod-name> -- grep PasswordAuthentication /etc/ssh/sshd_config
```

## Advanced Configuration

### Multiple StatefulSet Replicas

For multiple Ubuntu instances:

```yaml
replicaCount: 3
```

Each pod gets its own PVC: `data-<name>-0`, `data-<name>-1`, `data-<name>-2`

### Custom SSH Port

```yaml
service:
  port: 2222
  targetPort: 2222
  nodePort: 30222
```

Update prescript to configure SSH on custom port:

```yaml
prescript: |
  sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
```

### Using External Secrets

For GitOps with sealed secrets:

```yaml
ssh:
  rootPassword: "" # Remove from values
  authorizedKeys: ""
```

Create external secret:

```bash
kubectl create secret generic ubuntu-ssh-override \
  --from-literal=root-password='your-password' \
  --from-file=authorized-keys=~/.ssh/id_rsa.pub
```

## Contributing

Contributions are welcome! Please submit issues or pull requests.
