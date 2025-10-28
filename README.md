
# Kubernetes Cluster Installation Scripts

This repository contains installation scripts to set up a **Kubernetes cluster** with separate **control plane (master) nodes** and **worker nodes** on Ubuntu-based systems. The scripts automate the installation of all required dependencies, container runtime, and Kubernetes components.



## Table of Contents

- [Prerequisites](#prerequisites)  
- [Cluster Setup](#cluster-setup)  
  - [Control Plane Node](#control-plane-node)  
  - [Worker Node](#worker-node)  
- [Scripts Overview](#scripts-overview)  
- [Post Installation](#post-installation)  
- [Troubleshooting](#troubleshooting)  
- [License](#license)  


## Prerequisites

- Ubuntu 22.04 / 24.04 or compatible OS  
- Minimum hardware:
  - **Control plane:** 2 CPU, 4GB RAM
  - **Worker node:** 1 CPU, 2GB RAM  
- Internet connectivity for downloading packages (unless using local mirrors)  
- Swap must be disabled on all nodes  
- Hostname configured on each node (unique for each node)  
- SSH access for running the scripts  



## Cluster Setup

### Control Plane Node

Run the control plane script to:

1. Install dependencies (containerd, kubelet, kubeadm, kubectl)  
2. Configure container runtime (containerd with systemd cgroup)  
3. Enable required kernel modules and sysctl settings  
4. Initialize the Kubernetes control plane (`kubeadm init`)  
5. Apply CNI plugin (Flannel)  
6. Generate admin kubeconfig for cluster access  

Example:

```bash
sudo ./install-control-plane.sh
````

> The script outputs the `kubeadm join` command to add worker nodes.



### Worker Node

Run the worker node script to:

1. Install dependencies (containerd, kubelet, kubeadm)
2. Configure container runtime (containerd with systemd cgroup)
3. Enable required kernel modules and sysctl settings
4. Join the cluster using the token provided by the control plane

Example:

```bash
sudo ./install-worker.sh 
```

> Run the `<kubeadm-join-command>` with the actual command generated on the control plane.



## Scripts Overview

| Script                     | Purpose                                                      |
| -------------------------- | ------------------------------------------------------------ |
| `control-plane.sh` | Sets up the Kubernetes control plane node                    |
| `worker.sh`        | Sets up a Kubernetes worker node and joins it to the cluster |




## Post Installation

* Verify cluster status:

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl cluster-info
```

* Apply additional storage classes if needed:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```



## Troubleshooting

* **API server TLS errors**: Ensure your `--apiserver-cert-extra-sans` contains all required IPs and hostnames.
* **Kubelet fails to start**: Verify swap is disabled, containerd is running, and required kernel modules are loaded.
* **Worker node stuck in `NotReady`**: Ensure network connectivity to control plane and correct `kubeadm join` token is used.

## References

* [Install kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* [Configure cgroup driver](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/)
* [Containerd setup](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
* [Create cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
* [Rancher Local Path Provisioner](https://github.com/rancher/local-path-provisioner)


## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.


## Author

Raphael ([@lemrex](https://github.com/lemrex))






