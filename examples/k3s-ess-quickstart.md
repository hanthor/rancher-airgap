# K3s + Element Server Suite (ESS) Airgap Quickstart

This guide walks through deploying Element Server Suite Community Edition in an airgapped environment using K3s and Hauler. Supports Linux AMD64, Linux ARM64, Windows (WSL2), and macOS (via Docker Desktop/Rancher Desktop).

## Platform-Specific Requirements

### Linux (AMD64/ARM64)
- 2+ CPU cores, 4GB+ RAM
- Supported OS: Ubuntu 20.04+, RHEL 8+, Debian 11+
- Root or sudo access

### Windows (via WSL2)
- Windows 10/11 with WSL2 enabled
- 2+ CPU cores, 4GB+ RAM allocated to WSL2
- Ubuntu or other Linux distribution in WSL2

### macOS (Apple Silicon M1/M2/M3)
- macOS 12+ (Monterey or later)
- Docker Desktop or Rancher Desktop installed
- 4GB+ RAM allocated to Docker/Rancher Desktop

---

## Internet Connected Build Server

```bash
# Sudo to Root (Linux only, skip on macOS/Windows WSL2 if already admin)
sudo su

# Setup Directories
mkdir -p /opt/hauler
cd /opt/hauler

# Download and Install Hauler
curl -sfL https://get.hauler.dev | bash

# Fetch K3s and ESS Airgap Manifests
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/k3s/rancher-airgap-k3s.yaml
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/ess-helm/rancher-airgap-ess-helm.yaml
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/helm/rancher-airgap-helm.yaml

# Sync Manifests to Hauler Store
hauler store sync --store k3s-store --platform linux/amd64 --filename rancher-airgap-k3s.yaml
hauler store sync --store ess-store --platform linux/amd64 --filename rancher-airgap-ess-helm.yaml
hauler store sync --store helm-store --filename rancher-airgap-helm.yaml

# Save Hauler Tarballs
hauler store save --store k3s-store --filename rancher-airgap-k3s.tar.zst
hauler store save --store ess-store --filename rancher-airgap-ess-helm.tar.zst
hauler store save --store helm-store --filename rancher-airgap-helm.tar.zst

# Fetch Hauler Binary (choose appropriate platform)
# Linux AMD64
curl -sfOL https://github.com/hauler-dev/hauler/releases/download/v1.3.0/hauler_1.3.0_linux_amd64.tar.gz
# Linux ARM64
# curl -sfOL https://github.com/hauler-dev/hauler/releases/download/v1.3.0/hauler_1.3.0_linux_arm64.tar.gz
# macOS ARM64
curl -sfOL https://github.com/hauler-dev/hauler/releases/download/v1.3.0/hauler_1.3.0_darwin_arm64.tar.gz
# Windows AMD64 (for WSL2)
curl -sfOL https://github.com/hauler-dev/hauler/releases/download/v1.3.0/hauler_1.3.0_linux_amd64.tar.gz
```

---

**MOVE TARBALLS ACROSS THE AIRGAP**

---

## Disconnected Environment Setup

### Common Setup (All Platforms)

```bash
# Sudo to Root (skip if already root/admin)
sudo su

# Set Variables
export registry=<FQDN or IP>:5000
export fileserver=<FQDN or IP>:8080
export DOMAIN=<your-domain.com>  # e.g., ess.example.com

# Setup Directories
mkdir -p /opt/hauler
cd /opt/hauler

# Untar and Install Hauler
tar -xf hauler_1.3.0_linux_amd64.tar.gz  # Adjust filename for your platform
rm -rf LICENSE README.md
chmod 755 hauler && mv hauler /usr/local/bin/hauler

# Load Hauler Tarballs
hauler store load --filename rancher-airgap-k3s.tar.zst
hauler store load --filename rancher-airgap-ess-helm.tar.zst
hauler store load --filename rancher-airgap-helm.tar.zst

# Verify Hauler Store Contents
hauler store info

# Serve Hauler Content (run each in separate terminal or use nohup)
nohup hauler store serve registry &
nohup hauler store serve fileserver &

# Test Connectivity
curl ${registry}/v2/_catalog
curl http://${fileserver}
```

---

### Platform-Specific K3s Installation

#### Linux (AMD64 or ARM64)

```bash
# Set Variables
export vK3S=v1.33.5
export registry=<FQDN or IP>:5000
export fileserver=<FQDN or IP>:8080

# Detect architecture
export ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# Apply System Settings
cat << EOF >> /etc/sysctl.conf
vm.swappiness=0
vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
EOF
sysctl -p

# Install Dependencies
if [ -f /etc/redhat-release ]; then
    yum install -y iptables container-selinux libnetfilter_conntrack libnfnetlink libnftnl
    yum install -y http://${fileserver}/k3s-selinux-1.6-1.el9.noarch.rpm
else
    apt-get update && apt-get install -y iptables
fi

# Setup K3s Directories
mkdir -p /etc/rancher/k3s /var/lib/rancher/k3s/agent/images

# Copy K3s airgap images
curl -sfL http://${fileserver}/k3s-airgap-images-${ARCH}.tar.zst -o /var/lib/rancher/k3s/agent/images/k3s-airgap-images.tar.zst

# Configure K3s with Local Registry
cat << EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "http://${registry}"
  "*":
    endpoint:
      - "http://${registry}"
configs:
  "${registry}":
    tls:
      insecure_skip_verify: true
EOF

# Install K3s
curl -sfL http://${fileserver}/install.sh | INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_VERSION=${vK3S} sh -s - server \
  --system-default-registry=${registry} \
  --disable=traefik

# Symlink kubectl
sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl

# Update BASHRC
cat << EOF >> ~/.bashrc
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
alias k=kubectl
EOF
source ~/.bashrc

# Verify K3s
kubectl get nodes
```

#### Windows (WSL2)

```powershell
# In PowerShell (Windows host), enable WSL2 first
wsl --install -d Ubuntu

# Then run the Linux instructions above inside WSL2
wsl
# ... follow Linux AMD64 instructions ...
```

#### macOS (via Rancher Desktop)

```bash
# Install Rancher Desktop from https://rancherdesktop.io/
# Or use Docker Desktop with Kubernetes enabled

# After installation, configure container runtime to use your registry:
# Settings -> Container Engine -> Allowed Images -> Add your registry

# For airgap scenarios with Rancher Desktop:
# 1. Load images into Rancher Desktop's containerd
# 2. Configure registry mirrors in Settings -> Container Engine -> Registry

# Example: Load images from tarball
nerdctl --namespace k8s.io load -i k3s-airgap-images-amd64.tar.zst
```

---

### Deploy Helm

```bash
# Set Variables
export registry=<FQDN or IP>:5000
export fileserver=<FQDN or IP>:8080

# Fetch and Install Helm
curl -sfOL http://${fileserver}/helm-linux-amd64.tar.gz
# For macOS: curl -sfOL http://${fileserver}/helm-darwin-arm64.tar.gz
tar -xf helm-linux-amd64.tar.gz
cd linux-amd64 && chmod 755 helm
mv helm /usr/local/bin/helm
```

---

### Deploy Element Server Suite (ESS)

#### Prerequisites

```bash
# Set Variables
export DOMAIN=ess.example.com  # Your domain
export registry=<FQDN or IP>:5000
export fileserver=<FQDN or IP>:8080
export vESSChart=25.11.0

# Create ESS Namespace
kubectl create namespace ess

# Create ESS Configuration Directory
mkdir -p ~/ess-config-values
cd ~/ess-config-values
```

#### Configure Hostnames

```bash
# Create hostnames.yaml
cat << EOF > ~/ess-config-values/hostnames.yaml
serverName: ${DOMAIN}

synapse:
  ingress:
    host: matrix.${DOMAIN}

matrixAuthenticationService:
  ingress:
    host: account.${DOMAIN}

matrixRTC:
  ingress:
    host: mrtc.${DOMAIN}

elementWeb:
  ingress:
    host: chat.${DOMAIN}

elementAdmin:
  ingress:
    host: admin.${DOMAIN}

wellKnownDelegation:
  ingress:
    host: ${DOMAIN}
EOF
```

#### Configure TLS (Self-Signed for Airgap)

```bash
# Generate self-signed certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN}"

# Create TLS secrets
kubectl create secret tls ess-wildcard-tls -n ess \
  --cert=/tmp/tls.crt --key=/tmp/tls.key

# Create TLS config
cat << EOF > ~/ess-config-values/tls.yaml
synapse:
  ingress:
    tls:
      secretName: ess-wildcard-tls

matrixAuthenticationService:
  ingress:
    tls:
      secretName: ess-wildcard-tls

matrixRTC:
  ingress:
    tls:
      secretName: ess-wildcard-tls

elementWeb:
  ingress:
    tls:
      secretName: ess-wildcard-tls

elementAdmin:
  ingress:
    tls:
      secretName: ess-wildcard-tls

wellKnownDelegation:
  ingress:
    tls:
      secretName: ess-wildcard-tls
EOF
```

#### Install ESS

```bash
# Install ESS from local registry
helm upgrade --install --namespace "ess" ess oci://${registry}/hauler/matrix-stack \
  --version ${vESSChart} \
  -f ~/ess-config-values/hostnames.yaml \
  -f ~/ess-config-values/tls.yaml \
  --wait

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=matrix-stack -n ess --timeout=600s
```

#### Create Initial User

```bash
# Create admin user in Matrix Authentication Service
kubectl exec -n ess -it deploy/ess-matrix-authentication-service -- mas-cli manage register-user

# Follow the prompts to create username and password
```

#### Verify Setup

```bash
# Check all pods are running
kubectl get pods -n ess

# Check services
kubectl get svc -n ess

# Check ingress
kubectl get ingress -n ess

# Test Element Web
# Navigate to https://chat.${DOMAIN} in your browser
```

---

## Platform-Specific Notes

### Linux
- K3s runs natively with excellent performance
- SELinux support on RHEL-based distributions
- Systemd service management

### Windows (WSL2)
- K3s runs in WSL2 with near-native performance
- Access services via `localhost` or WSL2 IP
- May need to configure Windows Firewall for port forwarding

### macOS
- K3s runs via Rancher Desktop or Docker Desktop
- Performance depends on VM allocation
- Use `localhost` to access services
- Some features like LoadBalancer require additional configuration

---

## Troubleshooting

### Check Hauler Services

```bash
ps aux | grep hauler
curl ${registry}/v2/_catalog
curl http://${fileserver}
```

### Check K3s Status

```bash
systemctl status k3s  # Linux
kubectl get nodes
kubectl get pods -A
```

### Check ESS Logs

```bash
kubectl logs -n ess deployment/ess-synapse
kubectl logs -n ess deployment/ess-matrix-authentication-service
kubectl logs -n ess deployment/ess-element-web
```

### Registry Issues

```bash
# Verify registry configuration
cat /etc/rancher/k3s/registries.yaml

# Test registry connectivity
curl http://${registry}/v2/_catalog

# Check pod image pull status
kubectl describe pod <pod-name> -n ess
```

---

## Next Steps

1. Configure DNS entries to point to your K3s ingress
2. Set up proper TLS certificates (Let's Encrypt or internal CA)
3. Configure PostgreSQL for production use (external database recommended)
4. Set up backups for persistent volumes
5. Configure federation for Matrix communications
6. Refer to [ESS Helm documentation](https://github.com/element-hq/ess-helm) for advanced configuration

---

## Additional Resources

- [Element Server Suite Community Documentation](https://github.com/element-hq/ess-helm)
- [K3s Documentation](https://docs.k3s.io/)
- [Hauler Documentation](https://github.com/hauler-dev/hauler)
- [Matrix Protocol Specification](https://spec.matrix.org/)
