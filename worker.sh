#!/bin/bash
set -e

echo "*****************************"
echo " Kubernetes Worker Node Setup"
echo "*****************************"
echo

### [0] Preflight Checks ###
echo "[0/7] Performing system validation..."

# CPU core check
CORES=$(nproc)
if [ "$CORES" -lt 2 ]; then
  echo "ERROR: Minimum 2 CPU cores required. Found: $CORES"
  exit 1
else
  echo "CPU check passed: ${CORES} cores available."
fi

# Swap check
if swapon --show | grep -q 'partition'; then
  echo "Swap is enabled. Please disable swap and re-run."
  exit 1
else
  echo "Swap is disabled."
fi

echo

### [1] Updates ###
echo "[1/7] Updating packages..."
apt update -y && apt upgrade -y

### [2] Install Runtime & Kubernetes ###
echo "[2/7] Installing containerd & Kubernetes packages..."
apt install -y apt-transport-https ca-certificates curl gpg lsb-release software-properties-common

if [ ! -f /etc/apt/trusted.gpg.d/kubernetes.gpg ]; then
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  apt update -y
else
  echo "Kubernetes repo already exists."
fi

apt install -y containerd kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

### [3] Configure containerd ###
echo "[3/7] Configuring containerd..."
mkdir -p /etc/containerd
if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
  containerd config default | tee /etc/containerd/config.toml >/dev/null
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
  echo "containerd now uses SystemdCgroup."
else
  echo "containerd already configured for SystemdCgroup."
fi
systemctl enable containerd

### [4] Enable Networking Support ###
echo "[4/7] Enabling required kernel modules..."
modprobe overlay
modprobe br_netfilter
echo -e "overlay\nbr_netfilter" | tee /etc/modules-load.d/k8s.conf >/dev/null

echo "[5/7] Applying sysctl network settings..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

### [6] Disable swap state if still active ###
echo "[6/7] Verifying swap state..."
if swapon --show | grep -q 'partition'; then
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab
  echo "Swap disabled."
else
  echo "Swap already disabled."
fi


echo
echo "Worker setup complete!"
exec bash
