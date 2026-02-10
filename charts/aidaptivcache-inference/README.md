# aiDAPTIVCache Inference Helm Chart

This Helm chart deploys a high-performance LLM inference service using aiDAPTIV Cache and vLLM within Kubernetes clusters.

## Features

- High-throughput LLM inference based on vLLM
- Tensor parallelism support (Multi-GPU)
- KV Cache offloading to SSD/DRAM
- Dynamic LoRA loading
- OpenAI-compatible API
- Customizable pre/post execution scripts

## Prerequisites

**Required**: Before using this chart, you must install the **aiDAPTIVCache Operator** to enable Kubernetes to recognize and allocate Phison aiDAPTIVCache devices (`phison.com/ai100`).

## Installation

```bash
helm install llama-inference ./aidaptivcache-inference -f custom-values.yaml
```

## Configuration

### Image Configuration

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_3_03AA
  pullPolicy: IfNotPresent
```

- `repository`: Container image address
- `tag`: Image version tag
- `pullPolicy`: Image pull policy (IfNotPresent/Always/Never)

### Deployment Configuration

```yaml
deployment:
  name: vllm-api
  replicas: 1
```

- `name`: Kubernetes Deployment name
- `replicas`: Number of Pod replicas (typically 1 due to limited GPU resources)

### Scheduler Configuration

```yaml
schedulerName: "hami-scheduler"
```

- `schedulerName`: Kubernetes scheduler name (optional, set to empty string to use default scheduler)

### Init Container Configuration

```yaml
initContainer:
  enabled: true
  image:
    repository: ubuntu
    tag: 24.04
    pullPolicy: IfNotPresent
  sharedDataPath: /data
```

- `enabled`: Enable/disable init container (default: true)
- `image.repository`: Init container image repository
- `image.tag`: Init container image tag
- `image.pullPolicy`: Image pull policy
- `sharedDataPath`: Shared volume mount path between init container and main container

**Important Notes**:
- The init container runs with `privileged: true` security context (hardcoded in template)
- It executes the `prescript` before the main vLLM container starts
- Use it for NFS mounting, file preparation, or other setup tasks requiring elevated privileges
- Files copied to `sharedDataPath` are accessible to the main container
- The main container does NOT run with privileged mode for security

### vLLM Configuration

#### Environment Variables

```yaml
vllm:
  env:
    vllmUseV1: "1"
    vllmWorkerMultiprocMethod: "spawn"
    tiktokenEncodingsBase: ""
```

- `vllmUseV1`: Use vLLM v1 API
- `vllmWorkerMultiprocMethod`: Multi-process startup method (spawn/fork)

#### Command Line Arguments

```yaml
vllm:
  args:
    model: /data/model/Meta-Llama-3.1-8B-Instruct/
    nvmePath: /mnt/nvme0
    port: 8000
    gpuMemoryUtilization: 0.9
    maxModelLen: 8192
    tensorParallelSize: 1
    dramKvOffloadGb: 0
    ssdKvOffloadGb: 500
    noResumeKvCache: true
    disableGpuReuse: false
    enableChunkedPrefill: true
```

**Key Parameters**:
- `model`: Model path (must match container mount path)
- `nvmePath`: NVMe cache path for KV Cache offloading
- `port`: vLLM API service port
- `gpuMemoryUtilization`: GPU memory utilization ratio (0.0-1.0)
- `maxModelLen`: Maximum sequence length
- `tensorParallelSize`: Number of GPUs for tensor parallelism (must match `otterscale.com/vgpu`)
- `dramKvOffloadGb`: KV Cache offload to DRAM capacity (GB)
- `ssdKvOffloadGb`: KV Cache offload to SSD capacity (GB)
- `enableChunkedPrefill`: Enable chunked prefill for better long-text performance

**Optional Parameters** (commented by default):
- `disableLongToken`: Disable long token support
- `resumeKvCache`: Resume KV Cache
- `cleanObsoleteKvCache`: Clean obsolete KV Cache
- `enablePrefixCaching`: Enable prefix caching
- `enforceEager`: Force eager mode
- `disableKVCache`: Disable KV Cahe

#### LoRA Configuration

```yaml
vllm:
  lora:
    enable: false
    modules: ""
    maxRank: 32
```

To enable LoRA:

```yaml
vllm:
  lora:
    enable: true
    modules: "lora=/mnt/data/lora-adapters/llama3.1-8B-lora/"
    maxRank: 32
```

### Pre-execution Script (prescript)

The `prescript` runs in a privileged init container before the main vLLM service starts. This is ideal for:
- Mounting NFS storage
- Preparing model files
- Setting up directories
- Any privileged operations

**Example: NFS Mount and Model Copy**

```yaml
prescript: |
  apt update && apt install -y nfs-common
  echo "Starting NFS mount process..."
  mkdir -p /mnt/data
  TIMEOUT=300
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    echo "Attempting to mount NFS to /mnt/data"
    mount -t nfs4 -o nfsvers=4.1 -v <NFS_SERVER> /mnt/data
    if mountpoint -q /mnt/data; then
      echo "NFS mount successful!"
      break
    else
      echo "Mount failed, retrying in 5 seconds... (${ELAPSED}s/${TIMEOUT}s)"
      sleep 5
      ELAPSED=$((ELAPSED + 5))
    fi
  done
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "NFS mount timeout after ${TIMEOUT} seconds. Exiting..."
    exit 1
  fi
  
  # Optional: Copy model to shared volume for faster access
  echo "Copying model to shared volume..."
  mkdir -p /data/model
  cp -rf /mnt/data/model/Meta-Llama-3.1-8B-Instruct /data/model/
  echo "Model copy completed"
```

Replace `<NFS_SERVER>` with your actual NFS server address (e.g., `10.102.197.0:/volumes/_nogroup/your-nfs-path`).

**Important Notes**: 
- The target path for copying files in the prescript must be `initContainer.sharedDataPath` (default is `/data`)
- This shared path is mounted to both the init container and the main vLLM container
- If you copy models to `/data`, update the vLLM `model` path accordingly:

```yaml
initContainer:
  sharedDataPath: /data  # Shared data path

vllm:
  args:
    model: /data/model/Meta-Llama-3.1-8B-Instruct/  # Use model from shared path
```

### Service Configuration

```yaml
service:
  type: NodePort
  port: 8000
  targetPort: 8000
  # nodePort: 30299
```

- `type`: Service type (NodePort/ClusterIP/LoadBalancer)
- `port`: Service external port
- `targetPort`: Container internal port
- `nodePort`: (Optional) Specify a fixed NodePort

### Volume Configuration

```yaml
volumes:
  dshm:
    enabled: true
    sizeLimit: 30Gi
```

- `dshm.enabled`: Enable /dev/shm (shared memory, required for vLLM)

### Resource Configuration

```yaml
resources:
  requests:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 1
  limits:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 1
```

- `otterscale.com/vgpu`: vGPU count (must match `tensorParallelSize`)
- `otterscale.com/vgpumem-percentage`: vGPU memory percentage (0-100)
- `phison.com/ai100`: Phison aiDAPTIVCache accelerator count

**Important**: For multi-GPU deployments, `otterscale.com/vgpu` must equal `vllm.args.tensorParallelSize`.

## Usage Examples

### Basic Inference Service

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_3_03AA
  pullPolicy: IfNotPresent

deployment:
  name: llama3-inference
  replicas: 1

schedulerName: "hami-scheduler"

vllm:
  env:
    vllmUseV1: "1"
    vllmWorkerMultiprocMethod: "spawn"
  
  args:
    model: /data/model/Meta-Llama-3.1-8B-Instruct/
    nvmePath: /mnt/nvme0
    port: 8000
    gpuMemoryUtilization: 0.9
    maxModelLen: 8192
    tensorParallelSize: 1
    ssdKvOffloadGb: 500
    enableChunkedPrefill: true
  
  lora:
    enable: false

service:
  type: NodePort
  port: 8000
  targetPort: 8000

prescript: |
  apt update && apt install -y nfs-common
  echo "Starting NFS mount process..."
  mkdir -p /mnt/data
  TIMEOUT=300
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    echo "Attempting to mount NFS to /mnt/data"
    mount -t nfs4 -o nfsvers=4.1 -v 10.102.197.0:/volumes/_nogroup/models /mnt/data
    if mountpoint -q /mnt/data; then
      echo "NFS mount successful!"
      break
    else
      echo "Mount failed, retrying in 5 seconds... (${ELAPSED}s/${TIMEOUT}s)"
      sleep 5
      ELAPSED=$((ELAPSED + 5))
    fi
  done
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "NFS mount timeout after ${TIMEOUT} seconds. Exiting..."
    exit 1
  fi
  # Copy model to shared volume
  mkdir -p /data/model
  cp -rf /mnt/data/model/Meta-Llama-3.1-8B-Instruct /data/model/

volumes:
  dshm:
    enabled: true
    sizeLimit: 30Gi

resources:
  requests:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 1
  limits:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 1
```

### Multi-GPU Inference with LoRA

```yaml
vllm:
  args:
    model: /data/model/Meta-Llama-3.1-8B-Instruct/
    tensorParallelSize: 4
    maxModelLen: 8192
    gpuMemoryUtilization: 0.85
  
  lora:
    enable: true
    modules: "lora=/data/lora-adapters/llama3.1-8B-lora/"
    maxRank: 32

resources:
  requests:
    otterscale.com/vgpu: 4  # Must match tensorParallelSize
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 2
  limits:
    otterscale.com/vgpu: 4
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 2
```

## Accessing the API

After deployment, use the OpenAI-compatible API:

### Health Check

```bash
curl http://<NODE_IP>:<NODE_PORT>/health
```

### Completions API

```bash
curl http://<NODE_IP>:<NODE_PORT>/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Meta-Llama-3.1-8B-Instruct",
    "prompt": "What is the capital of France?",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### Chat Completions API

```bash
curl http://<NODE_IP>:<NODE_PORT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Meta-Llama-3.1-8B-Instruct",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is machine learning?"}
    ],
    "max_tokens": 200
  }'
```

### Python Client

```python
from openai import OpenAI

client = OpenAI(
    base_url=f"http://{NODE_IP}:{NODE_PORT}/v1",
    api_key="dummy"
)

response = client.chat.completions.create(
    model="Meta-Llama-3.1-8B-Instruct",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms"}
    ],
    max_tokens=150,
    temperature=0.8
)

print(response.choices[0].message.content)
```

## Monitoring

```bash
# View deployment status
kubectl get deployment

# View pod logs
kubectl logs -f deployment/<deployment-name>

# Check service endpoint
kubectl get svc
```

## Performance Tuning

### Memory Optimization

- **Small models (< 7B)**:
  - `gpuMemoryUtilization: 0.9`
  - `ssdKvOffloadGb: 0`

- **Medium models (7B-13B)**:
  - `gpuMemoryUtilization: 0.85`
  - `ssdKvOffloadGb: 200-500`

- **Large models (> 13B)**:
  - `gpuMemoryUtilization: 0.8`
  - `ssdKvOffloadGb: 500-1000`
  - Multi-GPU: `tensorParallelSize: 2-4`

### Latency vs Throughput

- **Low latency**:
  ```yaml
  maxModelLen: 8192
  enableChunkedPrefill: false
  ssdKvOffloadGb: 0
  ```

- **High throughput**:
  ```yaml
  maxModelLen: 32768
  enableChunkedPrefill: true
  enablePrefixCaching: true
  ssdKvOffloadGb: 500
  ```

## Uninstall

```bash
helm uninstall llama-inference
```
