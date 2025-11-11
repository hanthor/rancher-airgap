# Testing Airgapped K3s + ESS Deployments

This guide demonstrates how to test and validate airgapped K3s + ESS deployments using the automated testing workflow.

## Quick Start

### 1. Run the Automated Test

```bash
# Via GitHub CLI
gh workflow run test-airgap.yaml

# Via GitHub UI
# Navigate to: Actions → Test Airgap K3s/ESS Deployment → Run workflow
```

### 2. Monitor Progress

```bash
# Watch the running workflow
gh run watch

# Or view in browser
# Navigate to: Actions → Latest run
```

### 3. Review Results

```bash
# Download test artifacts
gh run download <run-id>

# View the airgap report
cat airgap-test-results/airgap-report.md

# Check network activity
cat airgap-test-results/network-activity.log
```

## What the Test Does

### Pre-Deployment (Connected Phase)

The test simulates the "connected side" of an airgap deployment:

1. **Downloads all assets** using Hauler:
   - K3s container images and binaries
   - ESS Helm chart and all component images
   - Helm binary
   - OS dependency packages

2. **Creates local services**:
   - OCI registries for container images (ports 5001, 5002)
   - Fileservers for binaries (ports 8080, 8081)
   - OS package repository

### Deployment (Airgapped Phase)

The test simulates the "disconnected side" deployment:

1. **Sets up isolated environment**:
   - Creates K3d cluster
   - Configures local registry access only
   - Starts network monitoring

2. **Deploys from local sources**:
   - Installs Helm from local fileserver
   - Configures K3s to use local registries
   - Deploys ESS from local Helm chart and images

3. **Validates airgap compliance**:
   - Verifies all images from local registries
   - Monitors for external network connections
   - Checks pod health and deployment status

## Understanding Test Results

### Success ✅

```
Total images: 15
Local images: 15
External images: 0

Total pods: 8
Running pods: 8
Failed pods: 0

External connections: 0-5 (acceptable)
Airgap compliance: 100%
```

**Action**: Deployment is fully airgapped and ready for production use.

### Partial Success ⚠️

```
Total images: 15
Local images: 14
External images: 1

External connections: 12

Airgap compliance: 93%
```

**Action**: Review which image is external, add to manifest, retest.

### Failure ❌

```
Total images: 15
Local images: 10
External images: 5

Failed pods: 3

Airgap compliance: 67%
```

**Action**: Multiple missing assets - review logs, update manifests, rebuild stores.

## Iterative Improvement Workflow

### Step 1: Initial Test

Run the workflow to establish baseline:

```bash
gh workflow run test-airgap.yaml
```

### Step 2: Identify Issues

Download and review artifacts:

```bash
gh run download <run-id>
cd airgap-test-results

# Check what failed
grep "EXTERNAL" network-activity.log
grep "❌" airgap-report.md
```

### Step 3: Update Manifests

Add missing assets to appropriate manifests:

```yaml
# hauler/ess-helm/rancher-airgap-ess-helm.yaml
# Add missing image
spec:
  images:
    - name: ghcr.io/element-hq/missing-component:v1.0.0
```

### Step 4: Commit and Retest

```bash
git add hauler/
git commit -m "Add missing ESS component to manifest"
git push

# Workflow runs automatically or trigger manually
gh workflow run test-airgap.yaml
```

### Step 5: Verify Improvement

Compare results:

```bash
# Before: External images: 5
# After:  External images: 2
# Progress: 60% improvement
```

### Step 6: Repeat Until 100%

Continue iterating until all checks pass.

## Common Issues and Solutions

### Issue: Image Pull from External Registry

**Symptom:**
```
❌ EXTERNAL: ghcr.io/element-hq/synapse:v1.123.0
```

**Solution:**
```yaml
# Add to hauler/ess-helm/rancher-airgap-ess-helm.yaml
spec:
  images:
    - name: ghcr.io/element-hq/synapse:v1.123.0
```

**Verify:**
```bash
# Rebuild and test
gh workflow run test-airgap.yaml
```

### Issue: Binary Not Found

**Symptom:**
```
curl: (7) Failed to connect to localhost port 8080
```

**Solution:**
```yaml
# Add to hauler/k3s/rancher-airgap-k3s.yaml
spec:
  files:
    - path: https://github.com/example/binary.tar.gz
      name: binary.tar.gz
```

### Issue: Helm Chart Not Available

**Symptom:**
```
Error: failed to download "oci://localhost:5002/hauler/matrix-stack"
```

**Solution:**
The workflow has fallback to extract chart from store. If still failing:

1. Verify chart is in manifest:
```yaml
spec:
  charts:
    - name: matrix-stack
      repoURL: oci://ghcr.io/element-hq/ess-helm
      version: 25.11.0
```

2. Rebuild Hauler store:
```bash
cd hauler/ess-helm
hauler store sync --store ess-store --platform linux/amd64 --filename rancher-airgap-ess-helm.yaml
```

### Issue: Pod CrashLoopBackOff

**Symptom:**
```
ess-synapse-0     0/1     CrashLoopBackOff
```

**Solution:**

1. Check pod logs in artifacts
2. Common causes:
   - Missing configuration
   - Insufficient resources
   - Image architecture mismatch

3. Review pod description:
```yaml
# In workflow logs, look for:
kubectl describe pod ess-synapse-0 -n ess
```

### Issue: Network Connections Detected

**Symptom:**
```
[2025-01-15 10:30:15] EXTERNAL CONNECTION: tcp 0 0 10.0.1.5:45678 93.184.216.34:443
```

**Solution:**

1. Identify destination:
```bash
# Lookup IP
nslookup 93.184.216.34
# Result: ghcr.io
```

2. Find which pod is pulling:
```bash
# Check pod events
kubectl get events -n ess --sort-by='.lastTimestamp'
```

3. Add missing image to manifest

## Advanced Testing

### Test Specific Version

Modify workflow environment variables:

```yaml
env:
  K3S_VERSION: "v1.34.0+k3s1"
  ESS_CHART_VERSION: "25.12.0"
```

### Test on Multiple Platforms

The workflow currently tests linux/amd64. To test arm64:

```yaml
# In workflow, change:
--platform linux/arm64
```

### Test with Custom Domain

```yaml
env:
  DOMAIN: "matrix.internal"
```

### Enable Debug Mode

For interactive troubleshooting:

```yaml
# When triggering manually
debug_enabled: true
```

This starts a tmate session where you can inspect the cluster.

## Local Testing

You can run similar tests locally:

### 1. Setup Local Hauler Services

```bash
# Build stores
cd hauler/k3s
hauler store sync --store k3s-store --platform linux/amd64 --filename rancher-airgap-k3s.yaml

cd ../ess-helm
hauler store sync --store ess-store --platform linux/amd64 --filename rancher-airgap-ess-helm.yaml

# Start services
hauler store serve registry --port 5001 --store ../k3s/k3s-store &
hauler store serve registry --port 5002 --store ess-store &
hauler store serve fileserver --port 8080 --store ../k3s/k3s-store &
```

### 2. Create K3d Cluster

```bash
k3d cluster create test --registry-create test-registry:0.0.0.0:5000
```

### 3. Run Validation Scripts

```bash
# Start network monitor
.github/workflows/scripts/network-monitor.sh &

# Deploy ESS (following quickstart guide)
# ...

# Verify images
.github/workflows/scripts/verify-images.sh ess

# Check network activity
cat /tmp/network-activity.log
```

## Integration with Development Workflow

### Pre-Commit Hook

Add validation to pre-commit:

```bash
# .git/hooks/pre-commit
#!/bin/bash
# Validate YAML syntax before commit
for file in $(git diff --cached --name-only --diff-filter=ACM | grep "\.yaml$"); do
  python3 -c "import yaml; yaml.safe_load(open('$file'))" || exit 1
done
```

### Pre-Release Testing

Before tagging a release:

```bash
# 1. Run airgap test
gh workflow run test-airgap.yaml

# 2. Wait for completion
gh run watch

# 3. Check if passed
gh run list --workflow=test-airgap.yaml --limit 1 --json conclusion

# 4. If passed, create release
git tag v1.0.0 && git push origin v1.0.0
```

### PR Validation

Enable branch protection to require test passage:

1. Settings → Branches → Add rule
2. Require status checks: "Test Airgap K3s/ESS Deployment"
3. PRs now require passing test before merge

## Monitoring Test Health

### Track Success Rate

```bash
# Get last 10 runs
gh run list --workflow=test-airgap.yaml --limit 10 --json conclusion | \
  jq -r '[.[] | .conclusion] | group_by(.) | map({status: .[0], count: length})'
```

### View Trends

```bash
# Average duration over time
gh run list --workflow=test-airgap.yaml --limit 20 --json createdAt,updatedAt | \
  jq -r '.[] | ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601))'
```

### Set Up Alerts

Add to workflow:

```yaml
- name: Alert on Failure
  if: failure()
  run: |
    # Send notification (Slack, email, etc.)
    echo "Test failed - review artifacts"
```

## Best Practices

1. **Test before release**: Always run before tagging
2. **Review all artifacts**: Even successful runs may have warnings
3. **Track metrics**: Monitor success rate and duration
4. **Update regularly**: Keep manifests current with upstream
5. **Document exceptions**: Note intentional external access
6. **Iterate quickly**: Small, frequent updates better than large batches

## Related Documentation

- [Workflow Details](../.github/workflows/README-AIRGAP-TESTING.md)
- [Quick Reference](../.github/workflows/AIRGAP-TESTING-QUICKREF.md)
- [K3s + ESS Quickstart](k3s-ess-quickstart.md)
- [Standalone Scripts](../.github/workflows/STANDALONE-SCRIPTS.md)

## Support

For issues with the testing workflow:

1. Check [Troubleshooting Guide](../.github/workflows/README-AIRGAP-TESTING.md#troubleshooting)
2. Review workflow logs
3. Download and analyze artifacts
4. Open an issue with run URL and error details
