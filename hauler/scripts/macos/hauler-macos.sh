#!/bin/bash
# hauler-k3s-macos.sh: Collect Rancher Desktop for macOS and update manifest

set -euo pipefail

# Version variables
vRancherDesktop=1.13.1 # Update as needed
vK3S=1.33.5 # Sync with main K3s version


# Download Rancher Desktop DMG
curl -sSfL -o rancher-desktop-${vRancherDesktop}-mac.dmg "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${vRancherDesktop}/Rancher.Desktop-${vRancherDesktop}-mac.dmg"

# Get latest kubectl version
vKubectl=$(curl -s https://dl.k8s.io/release/stable.txt)
# Download kubectl for macOS ARM64
curl -sSfL -o kubectl "https://dl.k8s.io/release/${vKubectl}/bin/darwin/arm64/kubectl"

# Get latest k9s version
vK9s=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
# Download k9s for macOS ARM64
curl -sSfL -o k9s_Darwin_arm64.tar.gz "https://github.com/derailed/k9s/releases/download/${vK9s}/k9s_Darwin_arm64.tar.gz"

# Generate Hauler manifest entry for Rancher Desktop, kubectl, and k9s
cat << EOF > /opt/hauler/macos/rancher-airgap-macos.yaml
apiVersion: content.hauler.cattle.io/v1
kind: Files
metadata:
  name: rancher-airgap-files-macos
spec:
  files:
    - name: rancher-desktop-${vRancherDesktop}-mac.dmg
      url: https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${vRancherDesktop}/Rancher.Desktop-${vRancherDesktop}-mac.dmg
    - name: kubectl
      url: https://dl.k8s.io/release/${vKubectl}/bin/darwin/arm64/kubectl
    - name: k9s_Darwin_arm64.tar.gz
      url: https://github.com/derailed/k9s/releases/download/${vK9s}/k9s_Darwin_arm64.tar.gz
EOF

# Print completion
echo "Rancher Desktop, kubectl, and k9s for macOS collected and manifest updated."