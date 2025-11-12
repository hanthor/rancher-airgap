# Local Airgap Testing with K3s

This guide explains how to run airgap tests locally using the `local-airgap-test.sh` script. This script mirrors the GitHub Actions workflow but uses real K3s instead of K3d for production-like testing and faster iteration during development.

## Overview

The local airgap test script provides:

- **Real K3s deployment**: Uses production K3s instead of K3d for authentic testing
- **Faster iteration**: Run tests locally without waiting for CI/CD
- **Platform support**: Works on Linux AMD64 and ARM64 architectures
- **Complete airgap simulation**: Tests all phases from asset collection to deployment validation
- **Easy cleanup**: Simple command to reset your environment

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, RHEL 8+, Debian 11+)
- **Architecture**: AMD64 or ARM64
- **Resources**: 
  - 2+ CPU cores
  - 4GB+ RAM
  - 20GB+ free disk space
- **Access**: Root or sudo privileges

### Required Software

The script will check for these dependencies:

- `curl` - For downloading assets
- `tar` - For extracting archives
- `gzip` - For compression
- `jq` - For JSON parsing
- `openssl` - For certificate generation

Install on Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y curl tar gzip jq openssl
```

Install on RHEL/CentOS:
```bash
sudo yum install -y curl tar gzip jq openssl
```

## Quick Start

### Basic Usage

```bash
# Clone the repository
git clone https://github.com/hanthor/rancher-airgap.git
cd rancher-airgap

# Run the test (requires root)
sudo .github/workflows/scripts/local-airgap-test.sh
```

### With Custom Configuration

```bash
# Set custom domain and versions
sudo DOMAIN=matrix.test \
     K3S_VERSION=v1.33.5+k3s1 \
     ESS_CHART_VERSION=25.11.0 \
     .github/workflows/scripts/local-airgap-test.sh
```

## Test Phases

The script executes the same phases as the GitHub Actions workflow:

### Phase 1: Build Airgap Assets (Connected)

Syncs Hauler stores with all required assets:

- **K3s Store**: K3s binaries, images, installation scripts, SELinux RPMs
- **ESS Store**: Synapse, Element Web, MAS, Matrix RTC, PostgreSQL images, Helm chart
- **Helm Store**: Helm binary

This phase requires internet connectivity to download assets from upstream sources.

```
▶ Building K3s Hauler store...
▶ Building ESS Hauler store...
▶ Building Helm Hauler store...
✅ Airgap assets built successfully
```

### Phase 2: Install K3s

Installs K3s from local sources only:

- Downloads K3s binary from local Hauler fileserver
- Configures K3s to use local registries for all image pulls
- Installs K3s with Traefik disabled
- Waits for cluster to be ready

```
▶ Installing K3s v1.33.5+k3s1...
▶ Waiting for K3s to be ready...
✅ K3s installed successfully
```

### Phase 3: Start Hauler Services

Starts local registries and fileservers:

- **Registry on port 5001**: K3s images
- **Registry on port 5002**: ESS images
- **Fileserver on port 8080**: K3s binaries and scripts
- **Fileserver on port 8081**: Helm binary
- Verifies all services are responding
- Restarts K3s to apply registry configuration

```
▶ Starting K3s registry on port 5001...
▶ Starting ESS registry on port 5002...
✅ All Hauler services started successfully
```

### Phase 4: Deploy ESS from Local Sources

Deploys Element Server Suite using only local assets:

- Installs Helm from local fileserver
- Creates ESS namespace
- Generates self-signed TLS certificates
- Creates ESS values file with test configuration
- Deploys ESS Helm chart from local registry
- Waits for deployment to complete

```
▶ Installing Helm from local fileserver...
▶ Creating ESS namespace...
▶ Installing ESS from extracted chart...
✅ ESS deployment initiated
```

### Phase 5: Validation and Verification

Validates the deployment:

- Waits for all pods to be ready
- Verifies all images are from local registries (not external)
- Shows deployment, service, and pod status
- Provides access instructions

```
▶ Waiting for ESS pods to be ready...
▶ Verifying all images are from local sources...
✅ AIRGAP TEST PASSED - All pods are running
```

## Commands

### Run Complete Test

```bash
sudo .github/workflows/scripts/local-airgap-test.sh run
# or simply
sudo .github/workflows/scripts/local-airgap-test.sh
```

### Cleanup

Remove K3s and all test data:

```bash
sudo .github/workflows/scripts/local-airgap-test.sh cleanup
```

This will:
- Stop all Hauler services
- Uninstall K3s
- Remove work directories
- Clean up test artifacts

### Show Help

```bash
.github/workflows/scripts/local-airgap-test.sh help
```

## Configuration

### Environment Variables

Customize the test by setting these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Domain for ESS deployment | `ess.local` |
| `K3S_VERSION` | K3s version to install | `v1.33.5+k3s1` |
| `ESS_CHART_VERSION` | ESS Helm chart version | `25.11.0` |
| `HAULER_VERSION` | Hauler version to use | `1.3.0` |
| `PLATFORM` | Platform architecture | Auto-detected |

### Example: Custom Configuration

```bash
sudo DOMAIN=matrix.internal \
     K3S_VERSION=v1.34.0+k3s1 \
     ESS_CHART_VERSION=25.12.0 \
     .github/workflows/scripts/local-airgap-test.sh
```

## Accessing the Deployment

After a successful test, access your ESS deployment:

### 1. Configure DNS or Hosts File

Add entries to `/etc/hosts`:

```bash
sudo tee -a /etc/hosts <<EOF
127.0.0.1 ess.local
127.0.0.1 matrix.ess.local
127.0.0.1 account.ess.local
127.0.0.1 chat.ess.local
127.0.0.1 admin.ess.local
127.0.0.1 mrtc.ess.local
EOF
```

Replace `ess.local` with your custom `DOMAIN` if you changed it.

### 2. Get Service NodePorts

```bash
k3s kubectl get svc -n ess
```

Look for services with type `NodePort` and note their ports.

### 3. Access Services

Example with Element Web:

```bash
# If Element Web service is on NodePort 30123
firefox http://chat.ess.local:30123
```

## Logs and Debugging

### Log Locations

All logs are stored in `/tmp/airgap-test/logs/`:

- `k3s-sync.log` - K3s store sync output
- `ess-sync.log` - ESS store sync output
- `helm-sync.log` - Helm store sync output
- `k3s-registry.log` - K3s registry service log
- `ess-registry.log` - ESS registry service log
- `k3s-fileserver.log` - K3s fileserver log
- `helm-fileserver.log` - Helm fileserver log
- `ess-install.log` - ESS Helm installation log

### View Logs

```bash
# View K3s registry log
cat /tmp/airgap-test/logs/k3s-registry.log

# View ESS installation log
cat /tmp/airgap-test/logs/ess-install.log

# Follow K3s service log
journalctl -u k3s -f
```

### Debugging Pod Issues

```bash
# Check pod status
k3s kubectl get pods -n ess

# Describe a specific pod
k3s kubectl describe pod -n ess <pod-name>

# View pod logs
k3s kubectl logs -n ess <pod-name>

# View previous container logs (if restarted)
k3s kubectl logs -n ess <pod-name> --previous
```

### Verify Image Sources

Manually verify all pods use local registries:

```bash
bash .github/workflows/scripts/verify-images.sh ess
```

Expected output:
```
✅ LOCAL: localhost:5002/element-hq/synapse:v1.116.0
✅ LOCAL: localhost:5002/element-hq/element-web:v1.11.76
✅ AIRGAP VALIDATION PASSED
```

## Troubleshooting

### K3s Installation Fails

**Problem**: K3s fails to install or start

**Solution**:
```bash
# Check K3s service status
systemctl status k3s

# View K3s logs
journalctl -u k3s -n 100

# Check firewall
sudo systemctl status firewalld
sudo firewall-cmd --list-all

# Verify binary download
ls -lh /usr/local/bin/k3s
```

### Hauler Services Not Starting

**Problem**: Registry or fileserver fails to start

**Solution**:
```bash
# Check if ports are already in use
sudo netstat -tlnp | grep -E '5001|5002|8080|8081'

# Kill conflicting processes
sudo pkill -f "hauler store serve"

# Check Hauler store contents
cd /path/to/hauler/k3s
hauler store info --store k3s-store

# Manually start service for debugging
hauler store serve registry --port 5001 --store k3s-store
```

### Pods Not Starting

**Problem**: ESS pods stuck in `ImagePullBackOff` or `CrashLoopBackOff`

**Solution**:
```bash
# Check if images are in local registry
curl http://localhost:5002/v2/_catalog | jq

# Verify K3s registry configuration
cat /etc/rancher/k3s/registries.yaml

# Check K3s can reach registries
k3s kubectl run test --image=busybox --restart=Never -- sleep 3600
k3s kubectl logs test

# Review pod events
k3s kubectl describe pod -n ess <pod-name>

# Check for resource constraints
k3s kubectl top nodes
k3s kubectl top pods -n ess
```

### Image Verification Fails

**Problem**: Verification script reports external images

**Solution**:
```bash
# List all images in use
k3s kubectl get pods -n ess -o json | jq -r '.items[].spec.containers[].image'

# Check which images are missing from local registry
curl http://localhost:5002/v2/_catalog | jq '.repositories[]'

# Add missing images to Hauler manifest
vim hauler/ess-helm/rancher-airgap-ess-helm.yaml

# Rebuild ESS store
cd hauler/ess-helm
hauler store sync --store ess-store --filename rancher-airgap-ess-helm.yaml

# Restart registry
pkill -f "hauler.*5002"
nohup hauler store serve registry --port 5002 --store ess-store &
```

### Helm Chart Installation Fails

**Problem**: ESS Helm chart fails to install

**Solution**:
```bash
# Verify Helm is installed
helm version

# Check Helm can access registry
helm pull oci://localhost:5002/hauler/matrix-stack \
  --version 25.11.0 \
  --insecure-skip-tls-verify

# Try manual chart extraction
cd hauler/ess-helm
hauler store copy --store ess-store \
  --content-type chart \
  --name matrix-stack \
  --destination /tmp/charts

# Install from extracted chart
helm upgrade --install ess /tmp/charts/matrix-stack-25.11.0.tgz \
  --namespace ess \
  -f /tmp/ess-values.yaml

# Check Helm release status
helm list -n ess
helm status ess -n ess
```

### Cleanup Issues

**Problem**: Cleanup leaves behind resources

**Solution**:
```bash
# Manually stop all Hauler processes
sudo pkill -9 -f hauler

# Force K3s uninstall
sudo /usr/local/bin/k3s-uninstall.sh

# Remove K3s configuration
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s

# Clean up work directory
sudo rm -rf /tmp/airgap-test

# Remove K3s binary
sudo rm -f /usr/local/bin/k3s /usr/local/bin/kubectl

# Clean iptables rules (if needed)
sudo iptables -F
sudo iptables -t nat -F
```

## Comparison with GitHub Actions Workflow

| Feature | GitHub Actions (test-airgap.yaml) | Local Script |
|---------|-----------------------------------|--------------|
| **Runtime** | K3d (K3s in Docker) | K3s (native) |
| **Network Isolation** | Monitoring only | Monitoring only |
| **Speed** | ~20-30 minutes | ~10-15 minutes |
| **Platform** | Ubuntu runner (amd64) | Linux amd64/arm64 |
| **Cleanup** | Automatic | Manual command |
| **Iteration** | Requires push/PR | Instant local run |
| **Production-like** | Simulated | Real K3s |

### When to Use Each

**Use GitHub Actions** when:
- Testing changes in CI/CD pipeline
- Validating PRs before merge
- Ensuring changes don't break airgap
- Need automated testing on push

**Use Local Script** when:
- Developing and testing locally
- Quick iteration on manifest changes
- Debugging specific issues
- Testing on ARM64 architecture
- Learning airgap deployment process

## Best Practices

### 1. Clean Slate Testing

For consistent results, run cleanup before each test:

```bash
sudo .github/workflows/scripts/local-airgap-test.sh cleanup
sudo .github/workflows/scripts/local-airgap-test.sh run
```

### 2. Version Testing

Test multiple versions systematically:

```bash
# Test current stable
sudo K3S_VERSION=v1.33.5+k3s1 ESS_CHART_VERSION=25.11.0 \
  .github/workflows/scripts/local-airgap-test.sh run

# Cleanup
sudo .github/workflows/scripts/local-airgap-test.sh cleanup

# Test next version
sudo K3S_VERSION=v1.34.0+k3s1 ESS_CHART_VERSION=25.12.0 \
  .github/workflows/scripts/local-airgap-test.sh run
```

### 3. Log Preservation

Save logs before cleanup:

```bash
# Save logs to date-stamped directory
sudo cp -r /tmp/airgap-test/logs ~/airgap-logs-$(date +%Y%m%d-%H%M%S)

# Then cleanup
sudo .github/workflows/scripts/local-airgap-test.sh cleanup
```

### 4. Resource Monitoring

Monitor system resources during test:

```bash
# In a separate terminal
watch -n 5 'free -h && echo && df -h && echo && k3s kubectl top nodes'
```

### 5. Network Verification

Monitor network connections:

```bash
# Start network monitor before test (in separate terminal)
sudo bash .github/workflows/scripts/network-monitor.sh

# Run test
sudo .github/workflows/scripts/local-airgap-test.sh

# Review network activity
cat /tmp/network-activity.log
```

## Advanced Usage

### Running Individual Phases

You can modify the script to run specific phases for debugging:

```bash
# Edit script to comment out phases you don't want to run
sudo vim .github/workflows/scripts/local-airgap-test.sh

# For example, skip asset building if already done:
# Comment out: build_airgap_assets
```

### Custom ESS Configuration

Modify the ESS values file for custom deployments:

```bash
# Edit the script to add custom values
sudo vim .github/workflows/scripts/local-airgap-test.sh

# Find the section creating /tmp/ess-values.yaml and add:
# ingress:
#   enabled: true
# storageClass: local-path
```

### Testing with External PostgreSQL

```bash
# Start PostgreSQL first
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=synapse \
  -p 5432:5432 \
  postgres:16

# Modify ESS values in script
# postgresql:
#   enabled: false
# externalPostgresql:
#   host: host.docker.internal
#   port: 5432
#   database: synapse
#   username: postgres
#   password: secret
```

### Parallel Testing

Run multiple tests in isolated environments:

```bash
# Terminal 1
sudo DOMAIN=test1.local .github/workflows/scripts/local-airgap-test.sh

# Terminal 2 (requires second machine or VM)
sudo DOMAIN=test2.local .github/workflows/scripts/local-airgap-test.sh
```

## Integration with Development Workflow

### Pre-Commit Testing

Before committing manifest changes:

```bash
# Make changes to manifests
vim hauler/ess-helm/rancher-airgap-ess-helm.yaml

# Test locally
sudo .github/workflows/scripts/local-airgap-test.sh

# If successful, commit
git add hauler/
git commit -m "Update ESS to v25.12.0"
```

### Rapid Iteration

```bash
# Edit manifest
vim hauler/ess-helm/rancher-airgap-ess-helm.yaml

# Quick test cycle
sudo .github/workflows/scripts/local-airgap-test.sh cleanup
sudo .github/workflows/scripts/local-airgap-test.sh run

# Repeat until successful
```

### Release Validation

Before creating a release:

```bash
# Test current main branch
git checkout main
git pull
sudo .github/workflows/scripts/local-airgap-test.sh

# If successful, create release
git tag v1.2.0
git push origin v1.2.0
```

## Contributing

To improve the local airgap test script:

1. Test on your platform (AMD64/ARM64, different distros)
2. Report issues or suggest enhancements
3. Submit PRs with improvements
4. Add support for additional platforms (macOS, Windows WSL)

## Related Documentation

- [GitHub Actions Airgap Test](README-AIRGAP-TESTING.md) - CI/CD workflow documentation
- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md) - Manual deployment guide
- [Hauler Documentation](https://github.com/hauler-dev/hauler) - Hauler project
- [K3s Documentation](https://docs.k3s.io/) - K3s documentation

## Support

For issues with the local airgap test script:

1. Check logs in `/tmp/airgap-test/logs/`
2. Review troubleshooting section above
3. Run with verbose logging: `bash -x .github/workflows/scripts/local-airgap-test.sh`
4. Open an issue with:
   - Platform information (OS, architecture)
   - Error messages and logs
   - Steps to reproduce
