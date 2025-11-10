#!/usr/bin/env bash

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed."
    echo "Please install yq: https://github.com/mikefarah/yq"
    exit 1
fi

# Set ESS Helm Chart Version
export vESSHelmChart=25.11.0

# Setup Working Directory
rm -rf /opt/hauler/ess-helm
mkdir -p /opt/hauler/ess-helm
cd /opt/hauler/ess-helm

echo "Fetching ESS Helm chart values.yaml to extract image versions..."

# Download the values.yaml from the ESS Helm chart repository
curl -sSfL "https://raw.githubusercontent.com/element-hq/ess-helm/main/charts/matrix-stack/values.yaml" -o values.yaml

# Extract image versions using yq
export vSynapse=$(yq '.synapse.image.tag' values.yaml | tr -d '"' | sed 's/^v//')
export vElementWeb=$(yq '.elementWeb.image.tag' values.yaml | tr -d '"' | sed 's/^v//')
export vElementAdmin=$(yq '.elementAdmin.image.tag' values.yaml | tr -d '"')
export vMAS=$(yq '.matrixAuthenticationService.image.tag' values.yaml | tr -d '"')
export vLKJWT=$(yq '.matrixRTC.image.tag' values.yaml | tr -d '"')
export vLiveKit=$(yq '.matrixRTC.sfu.image.tag' values.yaml | tr -d '"' | sed 's/^v//')
export vPostgres=$(yq '.postgres.image.tag' values.yaml | tr -d '"' | sed 's/-alpine$//')
export vHAProxy=$(yq '.haproxy.image.tag' values.yaml | tr -d '"' | sed 's/-alpine$//')
export vRedis=$(yq '.synapse.redis.image.tag' values.yaml | tr -d '"' | sed 's/-alpine$//')
export vMatrixTools=$(yq '.matrixTools.image.tag' values.yaml | tr -d '"')

echo "Extracted versions:"
echo "  Synapse: v${vSynapse}"
echo "  Element Web: v${vElementWeb}"
echo "  Element Admin: ${vElementAdmin}"
echo "  Matrix Authentication Service: ${vMAS}"
echo "  LiveKit JWT Service: ${vLKJWT}"
echo "  LiveKit SFU: v${vLiveKit}"
echo "  PostgreSQL: ${vPostgres}"
echo "  HAProxy: ${vHAProxy}"
echo "  Redis: ${vRedis}"
echo "  Matrix Tools: ${vMatrixTools}"
echo ""

# Create Hauler Manifest
cat << EOF >> /opt/hauler/ess-helm/rancher-airgap-ess-helm.yaml
apiVersion: content.hauler.cattle.io/v1
kind: Charts
metadata:
  name: rancher-airgap-charts-ess
spec:
  charts:
    - name: matrix-stack
      repoURL: oci://ghcr.io/element-hq/ess-helm
      version: ${vESSHelmChart}
---
apiVersion: content.hauler.cattle.io/v1
kind: Images
metadata:
  name: rancher-airgap-images-ess-core
spec:
  images:
    # Synapse (Matrix Homeserver)
    - name: ghcr.io/element-hq/synapse:v${vSynapse}
    # Element Web (Matrix Client)
    - name: ghcr.io/element-hq/element-web:v${vElementWeb}
    # Element Admin
    - name: oci.element.io/element-admin:${vElementAdmin}
    # Matrix Authentication Service
    - name: ghcr.io/element-hq/matrix-authentication-service:${vMAS}
    # Matrix RTC Backend (LiveKit JWT Service)
    - name: ghcr.io/element-hq/lk-jwt-service:${vLKJWT}
    # LiveKit Server (for Matrix RTC)
    - name: docker.io/livekit/livekit-server:v${vLiveKit}
    # PostgreSQL
    - name: docker.io/library/postgres:${vPostgres}-alpine
    # HAProxy
    - name: docker.io/library/haproxy:${vHAProxy}-alpine
    # Redis (for Synapse)
    - name: docker.io/library/redis:${vRedis}-alpine
    # Matrix Tools (used for init jobs and utilities)
    - name: ghcr.io/element-hq/ess-helm/matrix-tools:${vMatrixTools}
EOF

echo "ESS Helm manifest generated at /opt/hauler/ess-helm/rancher-airgap-ess-helm.yaml"
echo ""
echo "To update versions, modify the variables at the top of this script and re-run."
echo "For the most current image versions, refer to:"
echo "  - https://github.com/element-hq/ess-helm/blob/main/charts/matrix-stack/values.yaml"
