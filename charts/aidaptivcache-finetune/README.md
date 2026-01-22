# aiDAPTIVCache Finetune Helm Chart

This Helm chart enables efficient fine-tuning of Large Language Models (LLMs) using aiDAPTIVCache within Kubernetes clusters.

## Features

- Kubernetes Job-based model fine-tuning
- Distributed training support (Multi-GPU)
- LoRA fine-tuning support
- ConfigMap-based configuration management
- Customizable pre/post execution scripts
- Flexible resource allocation (vGPU, memory)
- Automatic job cleanup with TTL

## Prerequisites

**Required**: Before using this chart, you must install the **aiDAPTIVCache Operator** to enable Kubernetes to recognize and allocate Phison aiDAPTIVCache devices (`phison.com/ai100`).

## Installation

```bash
helm install ft1 ./aidaptivcache-finetune -f custom-values.yaml
```

## Configuration

### Image Configuration

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_2_05BA0
  pullPolicy: IfNotPresent
```

- `repository`: Container image address
- `tag`: Image version tag
- `pullPolicy`: Image pull policy (IfNotPresent/Always/Never)

### Job Configuration

```yaml
job:
  name: finetune-job
  backoffLimit: 1
  restartPolicy: Never
  ttlSecondsAfterFinished: 60
```

- `name`: Kubernetes Job name
- `backoffLimit`: Number of retry attempts on failure
- `restartPolicy`: Restart policy (Never/OnFailure)
- `ttlSecondsAfterFinished`: Time to retain Job after completion (seconds)

### Scheduler Configuration

```yaml
schedulerName: "hami-scheduler"
```

- `schedulerName`: Kubernetes scheduler name (optional, set to empty string to use default scheduler)

### Training Configuration

#### Experiment Configuration (expConfig)

**Process Settings**:

```yaml
expConfig:
  processSettings:
    numGpus: 1                    # Number of GPUs to use
    specifyGpus: null             # Specific GPU IDs (e.g., "0,1,2,3")
    masterPort: 8299              # Master port for distributed training
    multiNodeSettings:
      enable: false               # Enable multi-node training
      masterAddr: "127.0.0.1"     # Master node address
```

**Run Settings**:

```yaml
expConfig:
  runSettings:
    taskType: "text-generation"        # Task type
    taskMode: "train"                  # Mode: train/eval/inference
    perDeviceTrainBatchSize: 4         # Batch size per device
    perUpdateTotalBatchSize: 16        # Total batch size (gradient accumulation)
    numTrainEpochs: 1                  # Number of training epochs
    maxIter: 12                        # Maximum iterations
    maxSeqLen: 2048                    # Maximum sequence length
    triton: true                       # Enable Triton optimization
    precisionMode: 1                   # Precision mode (0: FP32, 1: Mixed)
```

**LoRA Settings**:

```yaml
expConfig:
  runSettings:
    lora:
      enableLora: false              # Enable LoRA fine-tuning
      loraRank: 8                    # LoRA rank
      loraAlpha: 16                  # LoRA alpha parameter
      loraTaskType: "CAUSAL_LM"      # Task type for LoRA
      loraTargetModules: null        # Target modules (null for auto)
```

**Learning Rate and Optimizer**:

```yaml
expConfig:
  runSettings:
    lrScheduler:
      mode: 1                        # LR scheduler mode
      learningRate: 0.000007         # Learning rate
    
    optimizer:
      beta1: 0.9                     # Adam beta1
      beta2: 0.95                    # Adam beta2
      eps: 0.00000001                # Epsilon
      weightDecay: 0.01              # Weight decay
```

#### Environment Configuration (envConfig)

```yaml
envConfig:
  pathSettings:
    modelNameOrPath: "/mnt/data/models/TinyLlama-1.1B-Chat-v1.0"  # Model input path
    nvmePath: "/mnt/nvme0"                                        # NVMe cache path
    outputDir: "/mnt/data/output"                                 # Training output path
    trainDataPath:                                                # Training data config
      - /config/train_data/QA_dataset_config.yaml
    logName: "output.log"                                         # Log file name
```

**Key Path Explanations**:
- `modelNameOrPath`: Path to the pre-trained model (container path)
- `outputDir`: Where fine-tuned model weights will be saved (must be on NFS for persistence)
- `nvmePath`: NVMe device path for temporary storage and cache
- `trainDataPath`: Path to training data configuration file(s)

#### Training Data Configuration (trainDataConfig)

```yaml
trainDataConfig: |
  instruction-dataset:
    data_path: "HuggingFaceH4/instruction-dataset"  # HuggingFace dataset or local path
    strategy: "QA"                                  # Data strategy (QA/Chat)
    system_prompt: "A chat between a curious user and an artificial intelligence assistant."
    user_prompt: "{question}"                       # User prompt template
    question_key: "prompt"                          # Column name for questions
    answer_key: "completion"                        # Column name for answers
    exp_type: train                                 # Experiment type: train/eval/inference
    label_key: "completion"                         # Label column (same as answer_key)
```

### NFS Mount Configuration

Configure `prescript` to mount NFS storage for model access and output storage:

```yaml
prescript: |
  apt install -y nfs-common
  echo "Starting NFS mount process..."
  mkdir -p /mnt/data
  TIMEOUT=300
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    echo "Attempting to mount NFS to /mnt/data"
    mount -t nfs4 -o nfsvers=4.1 -v 10.102.197.0:/volumes/_nogroup/your-nfs-path /mnt/data
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
```

Replace `10.102.197.0:/volumes/_nogroup/your-nfs-path` with your actual NFS server address.

**Optional Post-execution Script**:

```yaml
postscript: |
  echo "Training job completed"
  echo "Model saved to: $outputDir"
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

- `otterscale.com/vgpu`: vGPU count
- `otterscale.com/vgpumem-percentage`: vGPU memory percentage (0-100)
- `phison.com/ai100`: Phison aiDAPTIVCache accelerator count

## Usage Examples

### Basic Fine-tuning Job

```yaml
image:
  repository: docker.io/library/aidaptiv
  tag: vNXUN_2_05BA0
  pullPolicy: IfNotPresent

job:
  name: finetune-llama-job
  backoffLimit: 1
  restartPolicy: Never
  ttlSecondsAfterFinished: 60

schedulerName: "hami-scheduler"

securityContext:
  privileged: true

# NFS Mount Script (Required)
prescript: |
  apt install -y nfs-common
  echo "Starting NFS mount process..."
  mkdir -p /mnt/data
  TIMEOUT=300
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    echo "Attempting to mount NFS to /mnt/data"
    mount -t nfs4 -o nfsvers=4.1 -v 10.102.197.0:/volumes/_nogroup/my-nfs-path /mnt/data
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

envConfig:
  pathSettings:
    modelNameOrPath: "/mnt/data/models/TinyLlama-1.1B-Chat-v1.0"
    nvmePath: "/mnt/nvme0"
    outputDir: "/mnt/data/output"
    trainDataPath:
      - /config/train_data/QA_dataset_config.yaml
    logName: "finetune_output.log"

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
    maxIter: 100
    maxSeqLen: 2048
    triton: true
    
    lrScheduler:
      mode: 1
      learningRate: 0.000007
    
    lora:
      enableLora: false

trainDataConfig: |
  instruction-dataset:
    data_path: "HuggingFaceH4/instruction-dataset"
    strategy: "QA"
    system_prompt: "A chat between a curious user and an artificial intelligence assistant."
    user_prompt: "{question}"
    question_key: "prompt"
    answer_key: "completion"
    exp_type: train
    label_key: "completion"

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

### LoRA Fine-tuning

```yaml
expConfig:
  runSettings:
    lora:
      enableLora: true
      loraRank: 8
      loraAlpha: 16
      loraTaskType: "CAUSAL_LM"
      loraTargetModules: null

envConfig:
  pathSettings:
    lora:
      loraWeight: ""  # Leave empty for new LoRA training
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

## Installation

```bash
# Install with custom configuration
helm install ft1 ./aidaptivcache-finetune -f custom-values.yaml

# Install in a specific namespace
helm install ft1 ./aidaptivcache-finetune -f custom-values.yaml -n finetune-ns
```

## Monitoring

### Check Job Status

```bash
# View Job status
kubectl get jobs

# View Pod status
kubectl get pods

# View Pod logs
kubectl logs -f job/<job-name>
```

### Retrieve Fine-tuned Model

After training completes, the fine-tuned model will be saved in the path specified by `outputDir`:

```bash
# Access via the same NFS mount used during training
# Mount the NFS on your local machine or a node
mount -t nfs4 10.102.197.0:/volumes/_nogroup/your-nfs-path /mnt/nfs
ls /mnt/nfs/output/
```

## Troubleshooting

### Job Fails to Start

- Check if aiDAPTIVCache Operator is installed
- Verify resource availability (vGPU, phison.com/ai100)
- Check NFS mount configuration and accessibility

### NFS Mount Fails

- Verify NFS server address is correct
- Check network connectivity from cluster to NFS server
- Ensure NFS server allows connections from cluster nodes

### Out of Memory Errors

- Reduce `perDeviceTrainBatchSize`
- Reduce `maxSeqLen`
- Increase `otterscale.com/vgpumem-percentage`

## Uninstall

```bash
helm uninstall ft1
```
