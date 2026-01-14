# aiDAPTIVCache-operator

## Overview

The **aiDAPTIVCache Operator** is a Kubernetes operator designed to manage and register AI100E M.2 SSDs within a Kubernetes cluster. The operator ensures that AI100 devices are detected, configured, and seamlessly integrated into your Kubernetes workloads, allowing applications to leverage advanced storage and computational capabilities.

---

## Features

- **Automatic Device Detection**: Deploys node-discover to automatically detect AI100 devices on cluster nodes.
- **Device Plugin**: Registers AI100 devices as Kubernetes resources, enabling targeted workload scheduling.
- **Configuration Management**: Centralized configuration to ensure proper device setup and operation.
- **NVMe Exporter**: Exposes metrics and cache information via an NVMe exporter.

---

## Getting Started

### Prerequisites

- **Kubernetes Cluster**: v1.26 or newer
- **kubectl**: Configured CLI for your cluster
- **Helm**: (Optional) For easier installation
- **AI100 Devices**: Physically present and connected to cluster nodes

---

### Installation

#### Using Local Files

```sh
tar zxvf aidaptivcache-operator.tar.gz
cd aidaptivcache-operator
helm install aidaptivcache-operator --namespace aidaptivcache-operator --create-namespace .
```

---

### Configuration

The operator consists of four main components, configurable via `values.yaml`:

- **phison operator**
- **phison node discovery**
- **phison device plugin**
- **phison nvme exporter**

| Parameter                             | Description                                            | Possible Values / Notes                                                                                                                                                             |
|----------------------------------------|--------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| global.namespace                      | Namespace for the operator                             |                                                                                                                                                                                     |
| phison_operator.replicaCount           | Number of operator replicas                            |                                                                                                                                                                                     |
| phison_operator.image.repository       | Operator container image repository                    |                                                                                                                                                                                     |
| phison_operator.image.tag              | Operator container image tag                           |                                                                                                                                                                                     |
| pnd.image.repository                   | Node discovery image repository                        |                                                                                                                                                                                     |
| pnd.image.tag                          | Node discovery image tag                               |                                                                                                                                                                                     |
| phison_device_plugin.image.repository  | Device plugin image repository                         |                                                                                                                                                                                     |
| phison_device_plugin.image.tag         | Device plugin image tag                                |                                                                                                                                                                                     |
| phison_device_plugin.arguments         | Device plugin arguments                                | `-m <path>`: AI100 device path<br> `-p <path>`: Pod mount path<br> `-f <fw>`: Specify firmware version<br> `-skip_firmware_check`: Skip firmware version check                     |

---

### Notes

- The operator creates an LVM from AI100 devices and mounts it by default to `/mnt/nvme0`. You can change the mount path via `phison_device_plugin.arguments`.
- By default, the operator checks that the firmware version is `EIFZ`. Use `-f` to specify a different required version.
- The `-skip_firmware_check` flag will register all NVMe devices, regardless of firmware.

---

## Exporter Endpoints

- **Get NVMe Information:**
  ```sh
  curl http://<IP>:9299/nvme
  ```

- **Get Metrics:**
  ```sh
  curl http://<IP>:9299/metrics
  ```

---

## Example Pod Configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: ubuntu
    command: ["sleep", "3600s"]
    securityContext:
      privileged: true
    resources:
      requests:
        phison.com/ai100: 2
      limits:
        phison.com/ai100: 2
```

---

## Roadmap

- **Health Monitoring**: Add device health monitoring and automatic recovery actions for failed devices.

---

## License

```
Copyright 2025 Shawn Tsai.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
````