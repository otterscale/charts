# aiDAPTIVCache Finetune Helm Chart

This Helm chart runs LLM fine-tuning jobs using aiDAPTIV Cache within Kubernetes clusters. After training, the finetuned model is automatically packaged as an OCI image and pushed to a registry.

## Features

- Kubernetes Job-based model fine-tuning
- Distributed training support (Multi-GPU)
- LoRA fine-tuning support
- ConfigMap-based configuration management (env, exp, trainData)
- InitContainer-based model loading (same pattern as aidaptivcache-inference)
- **Automatic OCI image push** of finetuned model output via `crane`
- Automatic job cleanup with TTL

## Prerequisites

- **aiDAPTIVCache Operator**: Must be installed to enable `phison.com/ai100` device allocation.
- **Model OCI image**: Base model packaged as an OCI image with a shell (e.g., `FROM busybox`).
- **Registry access**: If `outputImage.enabled`, the pod must be able to push to the target registry.

## Installation

```bash
helm install ft1 ./aidaptivcache-finetune -f custom-values.yaml
```

## Architecture

```
Pod
├── initContainers
│   ├── model-loader     # Copies base model from OCI image → emptyDir
│   └── crane-setup      # Copies crane binary → tools volume
└── containers
    └── finetune          # Runs phisonai2 training, then pushes output as OCI image
```

**Volumes:**

| Volume | Type | Purpose |
|--------|------|---------|
| `shared-data` | emptyDir | Base model (input) + training output |
| `tools` | emptyDir | `crane` binary for OCI push |
| `docker-config` | Secret | Registry credentials (optional) |
| `env-config` | ConfigMap | phisonai2 environment config |
| `exp-config` | ConfigMap | phisonai2 experiment config |
| `train-data-config` | ConfigMap | Training data config |

## Configuration

### Model Loading (initContainer)

Same pattern as `aidaptivcache-inference` — the base model is packaged in an OCI image and copied into an emptyDir via initContainer.

```yaml
initContainer:
  enabled: true
  image:
    repository: docker.io/library/tinyllama-1.1b
    tag: latest
    pullPolicy: IfNotPresent
  modelSourcePath: /model
  sharedDataPath: /data
```

| Parameter | Description |
|-----------|-------------|
| `image.*` | OCI image containing the base model (must include a shell) |
| `modelSourcePath` | Path of the model inside the image |
| `sharedDataPath` | emptyDir mount path (shared with main container) |

`envConfig.pathSettings.modelNameOrPath` must match where the model lands after copy.

### Output Model OCI Push

After training completes successfully, the finetuned model at `envConfig.pathSettings.outputDir` is packaged as an OCI image and pushed to a registry using `crane`.

```yaml
outputImage:
  enabled: true
  repository: "registry.example.com/models/finetuned-model"
  tag: "latest"
  baseImage: "busybox:latest"
  crane:
    repository: gcr.io/go-containerregistry/crane
    tag: latest
  pushSecret: ""
```

| Parameter | Description |
|-----------|-------------|
| `repository` | Target OCI registry and repository |
| `tag` | Image tag for the finetuned model |
| `baseImage` | Base image layer (use `busybox:latest` so the output image is usable as an initContainer) |
| `crane.*` | Crane image for OCI operations |
| `pushSecret` | Name of a `kubernetes.io/dockerconfigjson` Secret for registry auth |

The output image can be directly used as the `initContainer.image` in `aidaptivcache-inference` to serve the finetuned model.

**Creating a push secret:**

```bash
kubectl create secret docker-registry my-registry-cred \
  --docker-server=registry.example.com \
  --docker-username=<user> \
  --docker-password=<password>
```

Then set `outputImage.pushSecret: "my-registry-cred"`.

### Job Configuration

```yaml
job:
  backoffLimit: 1
  restartPolicy: Never
  ttlSecondsAfterFinished: 60
```

### Environment Configuration (envConfig)

```yaml
envConfig:
  pathSettings:
    modelNameOrPath: "/data/model"
    nvmePath: "/mnt/nvme0"
    outputDir: "/data/output"
    trainDataPath:
      - /config/train_data/QA_dataset_config.yaml
    logName: "output.log"
```

| Parameter | Description |
|-----------|-------------|
| `modelNameOrPath` | Base model path (must be under `initContainer.sharedDataPath`) |
| `outputDir` | Training output directory (source for OCI push) |
| `nvmePath` | NVMe device path for temporary storage |
| `trainDataPath` | Paths to training data config YAML files |

### Experiment Configuration (expConfig)

```yaml
expConfig:
  processSettings:
    numGpus: 1
    masterPort: 8299
    multiNodeSettings:
      enable: false

  runSettings:
    taskType: "text-generation"
    taskMode: "train"
    perDeviceTrainBatchSize: 4
    perUpdateTotalBatchSize: 16
    numTrainEpochs: 1
    maxIter: 12
    maxSeqLen: 2048
    triton: true
    precisionMode: 1

    lrScheduler:
      mode: 1
      learningRate: 0.000007

    lora:
      enableLora: false
      loraRank: 8
      loraAlpha: 16
```

### Training Data Configuration

```yaml
trainDataConfig: |
  instruction-dataset:
    data_path: "HuggingFaceH4/instruction-dataset"
    strategy: "QA"
    system_prompt: "A chat between a curious user and an AI assistant."
    user_prompt: "{question}"
    question_key: "prompt"
    answer_key: "completion"
    exp_type: train
    label_key: "completion"
```

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

## Usage Examples

### Basic Finetune with Output Push

```yaml
initContainer:
  enabled: true
  image:
    repository: registry.example.com/models/tinyllama-1.1b
    tag: v1
  modelSourcePath: /model
  sharedDataPath: /data

outputImage:
  enabled: true
  repository: "registry.example.com/models/tinyllama-finetuned"
  tag: "v1"
  pushSecret: "my-registry-cred"

envConfig:
  pathSettings:
    modelNameOrPath: "/data/model"
    outputDir: "/data/output"
    nvmePath: "/mnt/nvme0"
    trainDataPath:
      - /config/train_data/QA_dataset_config.yaml
    logName: "output.log"

expConfig:
  runSettings:
    numTrainEpochs: 3
    maxIter: 100
    maxSeqLen: 2048

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

### LoRA Finetune

```yaml
expConfig:
  runSettings:
    lora:
      enableLora: true
      loraRank: 8
      loraAlpha: 16
      loraTaskType: "CAUSAL_LM"
```

### Multi-GPU Training

```yaml
expConfig:
  processSettings:
    numGpus: 4
    specifyGpus: "0,1,2,3"

resources:
  requests:
    otterscale.com/vgpu: 4
    phison.com/ai100: 2
  limits:
    otterscale.com/vgpu: 4
    phison.com/ai100: 2
```

### End-to-End Workflow: Finetune → Inference

1. **Build base model image:**

```dockerfile
FROM busybox:1.37
COPY ./TinyLlama-1.1B-Chat-v1.0/ /model/
```

```bash
docker build -t registry.example.com/models/tinyllama-1.1b:v1 .
docker push registry.example.com/models/tinyllama-1.1b:v1
```

2. **Run finetune Job** with `outputImage` pushing to `registry.example.com/models/tinyllama-finetuned:v1`

3. **Deploy inference** using the finetuned model:

```yaml
# aidaptivcache-inference values
initContainer:
  enabled: true
  image:
    repository: registry.example.com/models/tinyllama-finetuned
    tag: v1
  modelSourcePath: /
  sharedDataPath: /data

vllm:
  args:
    model: /data/
```

## Monitoring

```bash
kubectl get jobs
kubectl get pods
kubectl logs -f job/<job-name>
```

## Uninstall

```bash
helm uninstall ft1
```
