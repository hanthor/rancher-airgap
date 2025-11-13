# Set Variables
export vHelm=3.19.0

# Setup Working Directory
rm -rf .build/helm
mkdir -p .build/helm
cd .build/helm

# Create Hauler Manifest
# Helm -> https://github.com/helm/helm
cat << EOF >> .build/helm/rancher-airgap-helm.yaml
apiVersion: content.hauler.cattle.io/v1
kind: Files
metadata:
  name: rancher-airgap-files-helm
spec:
  files:
    - path: https://get.helm.sh/helm-v${vHelm}-linux-amd64.tar.gz
      name: helm-linux-amd64.tar.gz
    - path: https://get.helm.sh/helm-v${vHelm}-linux-arm64.tar.gz
      name: helm-linux-arm64.tar.gz
EOF
