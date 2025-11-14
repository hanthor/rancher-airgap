# Copilot Instructions for K3s + Element Server Suite (ESS) Airgap

## Project Purpose

This repository provides Hauler manifests and automation scripts for deploying **K3s and Element Server Suite (ESS)** in **disconnected/airgapped environments** with **cross-platform support** (Linux AMD64/ARM64, Windows WSL2, macOS ARM64). The core workflow follows a three-phase pattern: **Collection → Across the Airgap → Distribution**.

## Architecture Overview

### Hauler Manifest Structure

Each product component follows a consistent tri-part YAML manifest pattern:

1. **Files**: Binary artifacts, installation scripts, RPMs, ISOs (`kind: Files`)
2. **Charts**: Helm charts with specific versions (`kind: Charts`)
3. **Images**: Container images from various registries (`kind: Images`)

**Note:** The `platform:` field is not supported in Hauler manifests. Simply list the files with their URLs and names; Hauler will collect and package them regardless of platform.

**Example**: `hauler/k3s/rancher-airgap-k3s.yaml` contains K3s installation files for multiple architectures (amd64/arm64), container images, and SELinux RPMs.

**ESS Example**: `hauler/ess-helm/rancher-airgap-ess-helm.yaml` contains the ESS Helm chart and all required container images (Synapse, Element Web, MAS, PostgreSQL, etc.).

### Directory Organization

- `hauler/*/rancher-airgap-*.yaml` - Declarative Hauler manifests for each product
- `hauler/scripts/*/hauler-*.sh` - Generator scripts that dynamically create manifests from upstream sources
- `examples/` - End-to-end deployment workflows showing both sides of the airgap

### Key Products

- **K3s**: Lightweight Kubernetes distribution for edge/airgap scenarios
- **ESS (Element Server Suite)**: Matrix homeserver stack including Synapse, Element Web, Matrix Authentication Service, Matrix RTC, PostgreSQL, HAProxy
- **Helm**: Package manager for Kubernetes deployments

## Critical Workflows

### Manifest Generation Pattern

Scripts in `hauler/scripts/` follow this pattern:

```bash
# Set version variables
export vK3S=1.33.5
export vESSHelmChart=25.11.0

# Fetch and transform image lists from upstream
curl -sSfL https://github.com/k3s-io/k3s/releases/download/v${vK3S}+k3s1/k3s-images.txt | 
  sed -e "s/docker\.io\///g" -e "s/^/    - name: /"

# Generate YAML manifest with heredoc
cat << EOF >> rancher-airgap-k3s.yaml
apiVersion: content.hauler.cattle.io/v1
kind: Images
...
EOF
```

**Key insight**: Images are dynamically discovered from official release artifacts, then formatted into Hauler YAML syntax.

### Hauler Store Workflow

The complete airgap workflow uses these specific commands in sequence:

```bash
# Connected side (collect)
hauler store sync --store <name>-store --platform linux/amd64 --filename <manifest>.yaml
hauler store save --store <name>-store --filename <name>.tar.zst

# Physical transfer across airgap

# Disconnected side (distribute)
hauler store load --filename <name>.tar.zst
hauler store serve registry     # Serves OCI registry on :5000
hauler store serve fileserver   # Serves HTTP files on :8080
```

**Critical**: Separate stores per product enable granular updates. Always use `--platform` flag for multi-arch support.

### Distribution Architecture

On the disconnected side, Hauler provides two services simultaneously:

- **Registry** (port 5000): OCI-compliant container registry for images
- **Fileserver** (port 8080): HTTP server for installation scripts, binaries, RPMs

Downstream K3s installations configure `system-default-registry` to point to the Hauler registry, while installation scripts fetch from the fileserver.

## Project Conventions

### Version Management

- Product versions are hardcoded in manifests (e.g., `K3S: v1.33.5`, `ESS: 25.11.0`)
- Update both the manifest YAML AND the corresponding generator script
- Version variables use consistent naming: `vK3S`, `vESSHelmChart`, `vSynapse`, `vElementWeb`

### Cross-Platform Support

This repository now supports three primary platforms:

- **Linux AMD64/ARM64**: Native K3s deployment with systemd
- **Windows AMD64 (WSL2)**: K3s runs in WSL2 using Linux binaries
- **macOS ARM64**: K3s runs via Rancher Desktop or Docker Desktop

**Important**: K3s does NOT have native Windows or macOS binaries - it runs through virtualization/containerization layers. Manifests include only Linux binaries since those work in WSL2 and container runtimes.

### Platform Architecture

Default platform is `linux/amd64`, but manifests include `linux/arm64` artifacts for:

- K3s installation tarballs and binaries
- Container images (multi-arch support)

Both architectures are packaged together; deployment-time selection happens via installation variables.

## Development Patterns

### Adding a New Product

1. Create directory: `hauler/<product>/`
2. Create generator script: `hauler/scripts/<product>/hauler-<product>.sh`
3. Generate initial manifest: Run script to create `rancher-airgap-<product>.yaml`
4. Add README following existing pattern in `hauler/<product>/README.md`
5. Update root README.md with version support

### Updating Product Versions

```bash
cd hauler/scripts/<product>/
# Edit version variables at top of hauler-<product>.sh
bash hauler-<product>.sh
# Review changes in generated YAML
mv /opt/hauler/<product>/rancher-airgap-<product>.yaml ../../<product>/
```

### ESS-Specific Updates

For ESS Helm chart updates:
1. Check latest version at https://github.com/element-hq/ess-helm/releases
2. Update version in `hauler/scripts/ess-helm/hauler-ess-helm.sh`
3. Update component image versions (Synapse, Element Web, MAS, etc.)
4. Review values.yaml in the ESS Helm chart for new image references
5. Regenerate manifest

### Testing Changes

Use the quickstart workflow from `examples/k3s-ess-quickstart.md`:

```bash
# Test collection phase
hauler store sync --store test-store --filename <modified-manifest>.yaml
hauler store info --store test-store  # Verify contents
```

## External Dependencies

- **Hauler**: The core tool (https://github.com/hauler-dev/hauler) - manifests define WHAT to collect, Hauler performs the collection/packaging
- **K3s**: Lightweight Kubernetes (https://k3s.io/)
- **ESS Helm**: Element Server Suite Helm charts (https://github.com/element-hq/ess-helm)
- **Upstream sources**: GitHub releases, OCI registries, Helm repositories, official image lists

## Common Pitfalls

1. **Registry configuration**: K3s `registries.yaml` requires both `mirrors` and `configs` sections, even for HTTP registries
2. **Store naming**: Use consistent naming pattern `<product>-store` to avoid cross-product contamination
3. **File URLs**: Percent-encode special characters in GitHub release URLs (e.g., `+` becomes `%2B`)
4. **Image references**: Remove `docker.io/` prefix in image lists since Hauler normalizes registry paths
5. **Platform confusion**: K3s binaries are Linux-only; Windows/macOS use these binaries through WSL2/Docker
6. **ESS ingress**: ESS requires proper ingress configuration and DNS entries for all services (Synapse, Element Web, MAS, Matrix RTC, Element Admin)
7. **ESS PostgreSQL**: Default internal PostgreSQL is for testing; production deployments should use external database

## ESS Deployment Specifics

### Component Architecture

ESS consists of multiple interconnected services:

- **Synapse**: Matrix homeserver (core messaging server)
- **Matrix Authentication Service (MAS)**: User authentication and SSO
- **Element Web**: Web client for Matrix
- **Element Admin**: Administration interface
- **Matrix RTC Backend**: Video/voice calling (LiveKit-based)
- **PostgreSQL**: Database (chart-managed or external)
- **HAProxy**: Load balancer for Synapse workers
- **Redis**: Caching for Synapse

### Critical ESS Requirements

1. **DNS Entries**: ESS requires separate DNS entries for:
   - Base server name (e.g., `ess.example.com`)
   - Synapse (e.g., `matrix.ess.example.com`)
   - MAS (e.g., `account.ess.example.com`)
   - Matrix RTC (e.g., `mrtc.ess.example.com`)
   - Element Web (e.g., `chat.ess.example.com`)
   - Element Admin (e.g., `admin.ess.example.com`)

2. **TLS Certificates**: All services require TLS
   - Can use Let's Encrypt with cert-manager in connected environments
   - Use self-signed or internal CA in airgapped environments

3. **Ports**: ESS uses specific ports:
   - TCP 80/443: HTTP/HTTPS for all web services
   - TCP 30881: Matrix RTC WebRTC connections
   - UDP 30882: Matrix RTC Muxed WebRTC connections

### ESS Helm Values Pattern

ESS uses Helm values files with hierarchical configuration:

```yaml
serverName: ess.example.com  # Matrix server name (embedded in user IDs)

synapse:
  ingress:
    host: matrix.ess.example.com
    tls:
      secretName: ess-synapse-tls
  
matrixAuthenticationService:
  ingress:
    host: account.ess.example.com
# ... etc
```

## Key Files for Common Tasks

- **Update K3s version**: `hauler/scripts/k3s/hauler-k3s.sh`, then regenerate manifest
- **Update ESS version**: `hauler/scripts/ess-helm/hauler-ess-helm.sh`, then regenerate manifest
- **Add new Helm chart**: Update `Charts` section in relevant manifest YAML
- **Modify quickstart**: `examples/k3s-ess-quickstart.md` (primary user documentation)
- **View supported versions**: Root `README.md` "Repository Structure" section
- **ESS component images**: Check `hauler/ess-helm/rancher-airgap-ess-helm.yaml` for current versions

## Cross-Platform Deployment Notes

### Linux
- Native K3s installation with systemd service
- Full feature support including LoadBalancer via Klipper
- Best performance and most tested platform

### Windows (WSL2)
- K3s runs in WSL2 Linux environment
- Use Linux AMD64 binaries and manifests
- Access services via `localhost` or WSL2 IP address
- May require Windows Firewall configuration for external access

### macOS
- K3s runs via Rancher Desktop or Docker Desktop
- Use Linux AMD64 binaries (run in VM/container)
- Access services via `localhost`
- LoadBalancer services require additional configuration
- Performance depends on VM resource allocation

