# aiDAPTIVCache Inference Helm Chart

This Helm chart deploys a high-performance LLM inference service using aiDAPTIV Cache and vLLM within Kubernetes clusters.

## Features

- High-throughput LLM inference based on vLLM
- Tensor parallelism support (Multi-GPU)
- KV Cache offloading to SSD/DRAM
- Dynamic LoRA loading
- OpenAI-compatible API
- **OCI Image Volume** for instant model loading (Kubernetes 1.31+)
- Legacy initContainer model loading for older clusters

## Prerequisites

- **aiDAPTIVCache Operator**: Must be installed to enable `phison.com/ai100` device allocation.
- **Kubernetes 1.31+** with `ImageVolume` feature gate enabled (for `modelImage` volume).
  - If running Kubernetes < 1.31, use the legacy `initContainer` approach instead.

## Installation

```bash
helm install llama-inference ./aidaptivcache-inference -f custom-values.yaml
```

## Configuration

### Image Configuration

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_3_03_AA
  pullPolicy: IfNotPresent
```

### Model Image Volume (Recommended)

Mount an OCI image containing model weights directly as a read-only volume.

```yaml
modelImage:
  enabled: true
  reference: "registry.example.com/models/llama3.1-8b-instruct:v1"
  pullPolicy: IfNotPresent
  mountPath: /data/model
```

| Parameter | Description |
|-----------|-------------|
| `enabled` | Enable OCI image volume for model loading |
| `reference` | Full OCI image reference including tag |
| `pullPolicy` | Image pull policy (`IfNotPresent` / `Always` / `Never`) |
| `mountPath` | Mount path inside the container (must match `vllm.args.model`) |

**Building a model OCI image**:

```dockerfile
FROM scratch
COPY ./Meta-Llama-3.1-8B-Instruct/ /
```

```bash
docker build -t registry.example.com/models/llama3.1-8b-instruct:v1 .
docker push registry.example.com/models/llama3.1-8b-instruct:v1
```

### Init Container (Legacy)

For clusters without `ImageVolume` support (Kubernetes < 1.31):

```yaml
modelImage:
  enabled: false

initContainer:
  enabled: true
  image:
    repository: ubuntu
    tag: 24.04
  sharedDataPath: /data

prescript: |
  apt update && apt install -y nfs-common
  mkdir -p /mnt/data
  mount -t nfs4 -o nfsvers=4.1 10.102.197.0:/volumes/_nogroup/models /mnt/data
  cp -rf /mnt/data/model/Meta-Llama-3.1-8B-Instruct /data/model/
```

### vLLM Configuration

#### Environment Variables

```yaml
vllm:
  env:
    vllmUseV1: "1"
    vllmWorkerMultiprocMethod: "spawn"
    # tiktokenEncodingsBase: "https://example.com/encodings/"
```

`tiktokenEncodingsBase` is only injected as an env var when non-empty.

#### Command Line Arguments

```yaml
vllm:
  args:
    model: /data/model/
    nvmePath: /mnt/nvme0
    gpuMemoryUtilization: 0.9
    maxModelLen: 8192
    tensorParallelSize: 1
    dramKVOffloadGb: 0
    ssdKVOffloadGb: 500
    noResumeKVCache: true
    enableChunkedPrefill: true
```

| Parameter | Description |
|-----------|-------------|
| `model` | Model path (must match `modelImage.mountPath` or `initContainer.sharedDataPath`) |
| `nvmePath` | NVMe cache path for KV Cache offloading |
| `gpuMemoryUtilization` | GPU memory utilization ratio (0.0-1.0) |
| `maxModelLen` | Maximum sequence length |
| `tensorParallelSize` | Number of GPUs for tensor parallelism (must match `otterscale.com/vgpu`) |
| `dramKVOffloadGb` | KV Cache offload to DRAM (GB) |
| `ssdKVOffloadGb` | KV Cache offload to SSD (GB) |

**Boolean flags** (set to `true` to enable, omit or comment out to disable):

`disableGpuReuse`, `disableLongToken`, `resumeKVCache`, `cleanObsoleteKVCache`, `enablePrefixCaching`, `enforceEager`, `disableKVCache`

**Note**: The vLLM server port is derived from `service.targetPort` — there is no separate port argument.

#### LoRA Configuration

```yaml
vllm:
  lora:
    enable: true
    modules: "lora=/mnt/data/lora-adapters/llama3.1-8B-lora/"
    maxRank: 32
```

### Service Configuration

```yaml
service:
  type: NodePort
  port: 8000
  targetPort: 8000
  # nodePort: 30299
```

`targetPort` is used as both the container port and the `--port` argument to vLLM.

### Volume Configuration

```yaml
volumes:
  dshm:
    enabled: true
    sizeLimit: 16Gi
  pvc:
    enabled: false
    claimName: ""
    mountPath: /mnt/data
    readOnly: false
```

- `dshm`: Shared memory mount at `/dev/shm` (required for vLLM multi-process)
- `pvc`: Mount an existing PVC (e.g., for LoRA adapters)

### Resource Configuration

```yaml
resources:
  requests:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 60
    phison.com/ai100: 1
  limits:
    otterscale.com/vgpu: 1
    otterscale.com/vgpumem-percentage: 60
    phison.com/ai100: 1
```

For multi-GPU: `otterscale.com/vgpu` must equal `vllm.args.tensorParallelSize`.

## Usage Examples

### Model Image Volume (Recommended)

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_3_03_AA

modelImage:
  enabled: true
  reference: "registry.example.com/models/llama3.1-8b-instruct:v1"
  mountPath: /data/model

vllm:
  args:
    model: /data/model/
    gpuMemoryUtilization: 0.9
    maxModelLen: 8192
    ssdKVOffloadGb: 500
    enableChunkedPrefill: true

service:
  type: NodePort
  port: 8000
  targetPort: 8000

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

### Multi-GPU with LoRA

```yaml
modelImage:
  enabled: true
  reference: "registry.example.com/models/llama3.1-8b-instruct:v1"
  mountPath: /data/model

vllm:
  args:
    model: /data/model/
    tensorParallelSize: 4
    maxModelLen: 8192
    gpuMemoryUtilization: 0.85
  lora:
    enable: true
    modules: "lora=/mnt/data/lora-adapters/llama3.1-8B-lora/"
    maxRank: 32

volumes:
  pvc:
    enabled: true
    claimName: "lora-adapters-pvc"
    mountPath: /mnt/data
    readOnly: true

resources:
  requests:
    otterscale.com/vgpu: 4
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 2
  limits:
    otterscale.com/vgpu: 4
    otterscale.com/vgpumem-percentage: 80
    phison.com/ai100: 2
```

## Accessing the API

### Health Check

```bash
curl http://<NODE_IP>:<NODE_PORT>/health
```

### Chat Completions

```bash
curl http://<NODE_IP>:<NODE_PORT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Meta-Llama-3.1-8B-Instruct",
    "messages": [
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
    messages=[{"role": "user", "content": "Explain quantum computing"}],
    max_tokens=150,
)
print(response.choices[0].message.content)
```

## Uninstall

```bash
helm uninstall llama-inference
```
