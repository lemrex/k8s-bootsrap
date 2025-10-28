#!/bin/bash
set -e

echo "*****************************"
echo "  Kubernetes Control Plane"
echo "*****************************"
echo

### [0] System Validation ###
echo "[0/9] Running preflight checks..."

# Check CPU cores
CORES=$(nproc)
if [ "$CORES" -lt 2 ]; then
  echo "ERROR: Minimum 2 CPU cores required. Found: $CORES"
  exit 1
else
  echo "CPU cores check passed: $CORES cores available."
fi

# Check if swap is enabled
if swapon --show | grep -q 'partition'; then
  echo "ERROR: Swap is enabled. Disable swap before running this script."
  exit 1
else
  echo "Swap is disabled."
fi

# Check containerd SystemdCgroup setting if config exists
if [ -f /etc/containerd/config.toml ]; then
  if grep -q 'SystemdCgroup = true' /etc/containerd/config.toml; then
    echo "containerd uses systemd cgroup."
  else
    echo "containerd is not yet using systemd cgroup. Will fix later."
  fi
else
  echo "containerd config not found yet, will generate later."
fi
echo

### [1] Update packages ###
echo "[1/9] Updating packages..."
apt update -y && apt upgrade -y

### [2] Install dependencies ###
echo "[2/9] Installing dependencies..."
apt install -y apt-transport-https ca-certificates curl gpg lsb-release software-properties-common

### [3] Add Kubernetes repository ###
echo "[3/9] Adding Kubernetes repository..."
if [ ! -f /etc/apt/trusted.gpg.d/kubernetes.gpg ]; then
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  apt update -y
else
  echo "Kubernetes repo already configured."
fi

### [4] Install containerd and Kubernetes packages ###
echo "[4/9] Installing containerd and Kubernetes packages..."
apt install -y containerd kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

### [5] Configure containerd (SystemdCgroup=true) ###
echo "[5/9] Configuring containerd..."
mkdir -p /etc/containerd
if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
  containerd config default | tee /etc/containerd/config.toml >/dev/null
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
  echo "Updated containerd to use SystemdCgroup = true"
else
  echo "containerd already configured for SystemdCgroup."
fi
systemctl enable containerd

### [6] Enable kernel modules ###
echo "[6/9] Enabling kernel modules..."
modprobe overlay
modprobe br_netfilter
echo -e "overlay\nbr_netfilter" | tee /etc/modules-load.d/k8s.conf >/dev/null

### [7] Apply sysctl settings ###
echo "[7/9] Applying sysctl settings..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

### [8] Disable swap ###
echo "[8/9] Checking swap..."
if swapon --show | grep -q 'partition'; then
  echo "Disabling swap..."
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab
  echo "Swap disabled."
else
  echo "Swap already disabled."
fi

### [9] Initialize Kubernetes control plane ###
echo "[9/9] Initializing Kubernetes control plane..."
if ! kubectl get nodes >/dev/null 2>&1; then
  kubeadm init --pod-network-cidr=10.244.0.0/16
else
  echo "Cluster already initialized, skipping kubeadm init."
fi

### Configure kubectl for user ###
echo "Setting up kubeconfig for current user..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

### Apply Flannel ###
echo "Applying Flannel CNI network..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || true

echo
echo "Control plane setup complete!"
echo "Run the following on each worker node to join:"
echo
kubeadm token create --print-join-command
echo
exec bash
