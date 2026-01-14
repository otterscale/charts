# Inference Helm Chart

This Helm chart is used to deploy a vLLM API inference server for AI model serving.

## Features

- Deploy vLLM API server as a Kubernetes Deployment
- Configurable model serving parameters
- Support GPU resource allocation
- PVC-based model storage
- NodePort service for external access

## Installation

```bash
helm install my-inference ./inference -f custom-values.yaml
```

## Configuration

### Required Fields

Before using this chart, you need to configure the following fields in `values.yaml`:

- `volumes.model.pvcName`: Name of the PVC containing the model files

### Main Configuration Parameters

#### Image Configuration
- `image.repository`: Container image repository
- `image.tag`: Image tag
- `image.pullPolicy`: Image pull policy

#### Deployment Configuration
- `deployment.name`: Deployment name
- `deployment.replicas`: Number of replicas

#### vLLM Configuration
- `vllm.workingDir`: Working directory for the vLLM script
- `vllm.script`: Script filename to execute
- `vllm.args.model`: Path to the model (within PVC mount)
- `vllm.args.nvmePath`: NVMe path for KV cache offloading
- `vllm.args.port`: API server port
- `vllm.args.gpuMemoryUtilization`: GPU memory utilization ratio (0.0-1.0)
- `vllm.args.maxModelLen`: Maximum model sequence length
- `vllm.args.tensorParallelSize`: Number of GPUs for tensor parallelism
- `vllm.args.dramKvOffloadGb`: DRAM KV cache offload size in GB
- `vllm.args.ssdKvOffloadGb`: SSD KV cache offload size in GB

#### Service Configuration
- `service.type`: Service type (NodePort, ClusterIP, or LoadBalancer)
- `service.port`: Service port
- `service.targetPort`: Container port
- `service.nodePort`: (Optional) Specific NodePort to use

#### Volume Configuration
- `volumes.model.pvcName`: PVC name for model storage
- `volumes.model.mountPath`: Mount path for the model PVC
- `volumes.dshm.enabled`: Enable shared memory volume
- `volumes.dshm.sizeLimit`: Shared memory size limit

## Usage Example

Create a `custom-values.yaml`:

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_3_03BAA-1

deployment:
  replicas: 1

volumes:
  model:
    pvcName: "model-storage-pvc"
    mountPath: /mnt/model/

vllm:
  args:
    model: /mnt/model/gemma-3-27b-it/
    nvmePath: /mnt/nvme0
    port: 8299
    gpuMemoryUtilization: 0.9
    maxModelLen: 18000
    tensorParallelSize: 8
    ssdKvOffloadGb: 500

service:
  type: NodePort
  port: 8299
  nodePort: 30299

resources:
  requests:
    nvidia.com/gpu: 8
    phison.com/ai100: 4
  limits:
    nvidia.com/gpu: 8
    phison.com/ai100: 4
```

Then install:

```bash
helm install my-inference ./inference -f custom-values.yaml
```

## Monitoring Deployment Status

```bash
# View Deployment status
kubectl get deployments

# View Pod status
kubectl get pods -l app=vllm-api

# View Pod logs
kubectl logs -f deployment/my-inference-inference
```

## Accessing the API

If using NodePort service:

```bash
# Get the NodePort
kubectl get svc my-inference-inference

# Access the API (replace <NODE_IP> and <NODE_PORT> with actual values)
curl http://<NODE_IP>:<NODE_PORT>/v1/models
```

## Uninstall

```bash
helm uninstall my-inference
```
