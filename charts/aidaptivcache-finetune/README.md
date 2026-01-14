# Finetune Helm Chart

This Helm chart is used to run AI model fine-tuning jobs.

## Features

- Execute a single Kubernetes Job for model fine-tuning
- Mount configuration files via ConfigMaps
- Support GPU resource allocation
- Customizable training parameters and dataset configuration

## Installation

```bash
helm install my-finetune ./finetune -f custom-values.yaml
```

## Configuration

### Required Fields

Before using this chart, you need to configure the following fields in `values.yaml`:

- `modelPvc.name`: Name of the PVC containing the model
- `envConfig.pathSettings.modelNameOrPath`: Model path (within PVC mount)
- `envConfig.pathSettings.nvmePath`: NVMe temporary storage path
- `envConfig.pathSettings.outputDir`: Output directory for model weights
- `envConfig.pathSettings.logName`: Log file name

### Main Configuration Parameters

#### Image Configuration
- `image.repository`: Container image repository
- `image.tag`: Image tag
- `image.pullPolicy`: Image pull policy

#### PVC Configuration
- `modelPvc.name`: Name of the PVC containing the model
- `modelPvc.mountPath`: Mount path for the model PVC (default: `/models`)

#### GPU Configuration
- `expConfig.processSettings.numGpus`: Number of GPUs to use
- `expConfig.processSettings.specifyGpus`: Specific GPU IDs (e.g., "0,1,2,3")
- `expConfig.processSettings.masterPort`: Master port for distributed training

#### Training Parameters
- `expConfig.runSettings.perDeviceTrainBatchSize`: Batch size per device
- `expConfig.runSettings.numTrainEpochs`: Number of training epochs
- `expConfig.runSettings.maxSeqLen`: Maximum sequence length
- `expConfig.runSettings.lrScheduler.learningRate`: Learning rate

#### Training Data
- `trainDataConfig`: Training dataset configuration content

## Usage Example

Create a `custom-values.yaml`:

```yaml
modelPvc:
  name: "model-storage-pvc"
  mountPath: "/models"

envConfig:
  pathSettings:
    modelNameOrPath: "/models/llama-2-7b"
    nvmePath: "/mnt/nvme0"
    outputDir: "/output/finetuned-model"
    logName: "finetune-20260113.log"

expConfig:
  processSettings:
    numGpus: 2
    specifyGpus: "0,1"
  
  runSettings:
    numTrainEpochs: 3
    perDeviceTrainBatchSize: 8

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
  limits:
    nvidia.com/gpu: 2
  requests:
    nvidia.com/gpu: 2
```

Then install:

```bash
helm install my-finetune ./finetune -f custom-values.yaml
```

## Monitoring Job Status

```bash
# View Job status
kubectl get jobs

# View Pod logs
kubectl logs -f job/my-finetune-finetune
```

## Uninstall

```bash
helm uninstall my-finetune
```
