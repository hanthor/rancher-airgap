# Airgap Testing CI Workflow

## Overview

This workflow provides automated testing of airgapped K3s + ESS deployments to ensure all required assets (container images, binaries, OS packages) are available locally without requiring internet connectivity.

## Purpose

The airgap testing workflow validates that:

1. **All container images** are available in local Hauler registries
2. **All binaries** (Helm, K3s) are available from local fileserver
3. **All OS packages** are available in local repository
4. **No external network calls** are made during deployment
5. **ESS deployment** completes successfully using only local resources

## Workflow Triggers

The workflow runs on:

- **Manual trigger** via `workflow_dispatch` (with optional debug mode)
- **Pull requests** that modify `hauler/**` or workflow files
- **Push to main** that modifies `hauler/**` or workflow files

## Workflow Phases

### Phase 1: Build Airgap Assets (Connected)

This phase simulates the "connected side" of the airgap where assets are collected:

1. **Sync Hauler Stores**: Downloads all container images and files defined in manifests
   - K3s store (K3s images, binaries, SELinux RPMs)
   - ESS store (Synapse, Element Web, MAS, PostgreSQL, etc.)
   - Helm store (Helm binary)

2. **Create OS Repository**: Downloads Linux packages required for K3s
   - iptables, container-selinux, libnetfilter_conntrack, etc.
   - Simulates creating a YUM/APT repository

### Phase 2: Setup Isolated Environment

1. **Create K3d Cluster**: Lightweight K3s cluster for testing
2. **Start Hauler Services**:
   - Registry on port 5001 (K3s images)
   - Registry on port 5002 (ESS images)
   - Fileserver on port 8080 (K3s binaries)
   - Fileserver on port 8081 (Helm binary)
3. **Setup Network Monitoring**: Tracks external connections

### Phase 3: Configure Network Isolation

Simulates the "disconnected side" of the airgap:

1. Sets up network monitoring to detect external access attempts
2. Configures markers to track airgap mode
3. In a real airgap, would use iptables to block outbound traffic

**Note**: GitHub Actions runners cannot fully block internet, but the workflow monitors and reports any external connections.

### Phase 4: Deploy from Local Sources

1. **Configure K3s Registry**: Points to local Hauler registries
2. **Install Helm**: From local fileserver only
3. **Deploy ESS**: Using local Helm chart and images
4. **Wait for Pods**: Ensures all ESS components start

### Phase 5: Validation

1. **Verify Image Sources**: Confirms all pods use local registry
2. **Check Network Activity**: Reports any external connections
3. **Verify ESS Components**: Validates critical pods are running
4. **Test OS Repository**: Checks package availability
5. **Generate Report**: Creates comprehensive test report

## Usage

### Manual Trigger

```bash
# Via GitHub CLI
gh workflow run test-airgap.yaml

# Via GitHub UI
Actions → Test Airgap K3s/ESS Deployment → Run workflow
```

### Automatic on PR

The workflow runs automatically when you:

```bash
git checkout -b feature/update-manifests
# Edit hauler manifests
git add hauler/
git commit -m "Update ESS to v25.12.0"
git push origin feature/update-manifests
# Create PR - workflow runs automatically
```

### Debug Mode

Enable debug mode to get a tmate session for troubleshooting:

```yaml
# When triggering manually, set:
debug_enabled: true
```

## Understanding Results

### Success Indicators

✅ **All checks passed**:
- All images from local registries
- All pods running
- Minimal external network activity
- Report shows 100% airgap compliance

### Warning Indicators

⚠️ **Partial success**:
- Some external connections detected
- Review network activity log
- May need to add missing assets to manifests

### Failure Indicators

❌ **Test failed**:
- Pods pulling from external registries
- Missing binaries in fileserver
- ESS deployment timeout
- Critical components not running

## Artifacts

After each run, the workflow uploads test artifacts:

- `airgap-report.md`: Comprehensive test report
- `network-activity.log`: External connections log
- `*-registry.log`: Hauler registry logs
- `fileserver.log`: Hauler fileserver logs

Download artifacts from the workflow run page:
`Actions → Test Airgap K3s/ESS Deployment → [Run] → Artifacts`

## Interpreting Network Activity Logs

The network monitor tracks connections and logs:

```
[2025-01-15 10:30:45] EXTERNAL CONNECTION: tcp 0 0 10.0.1.5:45678 93.184.216.34:443 ESTABLISHED
```

**Common patterns**:

- **ghcr.io (20.205.243.166)**: ESS images - add to Hauler manifest
- **docker.io (registry-1.docker.io)**: Container images - add to Hauler manifest
- **api.github.com**: GitHub API - may be from Helm chart fetch
- **DNS queries**: Usually benign, but verify no image pulls

## Troubleshooting

### Images Pulled from External Sources

**Problem**: `verify-images.sh` reports external images

**Solution**:
1. Check which images are external
2. Add missing images to appropriate Hauler manifest:
   - K3s images → `hauler/k3s/rancher-airgap-k3s.yaml`
   - ESS images → `hauler/ess-helm/rancher-airgap-ess-helm.yaml`
3. Regenerate manifests if needed
4. Commit changes and re-run workflow

### ESS Pods Not Starting

**Problem**: Pods in `CrashLoopBackOff` or `ImagePullBackOff`

**Solution**:
1. Check pod logs: `kubectl logs -n ess <pod-name>`
2. Check pod description: `kubectl describe pod -n ess <pod-name>`
3. Common issues:
   - Image not in registry → add to manifest
   - Configuration error → check values file
   - Resource limits → increase timeouts

### Network Monitoring Shows Many Connections

**Problem**: Many external connections in log

**Solution**:
1. Review `network-activity.log` artifact
2. Identify destination hosts/ports
3. Determine if connections are:
   - **Image pulls**: Add images to manifests
   - **Binary downloads**: Add files to Hauler stores
   - **Helm chart fetches**: Ensure chart in local registry
   - **DNS queries**: Usually safe, but investigate unexpected patterns

### OS Packages Missing

**Problem**: `verify-packages.sh` reports missing packages

**Solution**:
1. On connected server, use `repotrack` to download packages:
   ```bash
   repotrack <package-name>
   ```
2. Add packages to OS repository
3. Recreate repository metadata:
   ```bash
   createrepo /opt/hauler/repos
   ```

## Iterative Improvement

### Step 1: Run Workflow

```bash
gh workflow run test-airgap.yaml
```

### Step 2: Review Results

Download and review artifacts:
- Check `airgap-report.md` for summary
- Review `network-activity.log` for external connections
- Check pod logs for errors

### Step 3: Identify Missing Assets

Common missing assets:
- Container images (check pod events)
- Helm charts (check chart repository)
- Binary files (check fileserver logs)
- OS packages (check package installation logs)

### Step 4: Update Manifests

Add missing assets to appropriate manifests:

**Images**:
```yaml
# hauler/ess-helm/rancher-airgap-ess-helm.yaml
spec:
  images:
    - name: ghcr.io/element-hq/new-component:v1.0.0
```

**Files**:
```yaml
# hauler/k3s/rancher-airgap-k3s.yaml
spec:
  files:
    - path: https://example.com/new-binary
      name: new-binary
```

**Charts**:
```yaml
# hauler/ess-helm/rancher-airgap-ess-helm.yaml
spec:
  charts:
    - name: new-chart
      repoURL: oci://registry.example.com/charts
      version: 1.0.0
```

### Step 5: Test Changes

Commit and push changes to trigger workflow:

```bash
git add hauler/
git commit -m "Add missing ESS component image"
git push
```

### Step 6: Repeat

Continue iterating until:
- ✅ All images from local sources
- ✅ All pods running successfully
- ✅ No external network connections
- ✅ 100% airgap compliance

## Advanced Usage

### Testing Specific Versions

Modify environment variables in workflow:

```yaml
env:
  K3S_VERSION: "v1.34.0+k3s1"
  ESS_CHART_VERSION: "25.12.0"
```

### Custom Domain Testing

Change the test domain:

```yaml
env:
  DOMAIN: "matrix.internal"
```

### Extended Timeout

For slower environments:

```yaml
jobs:
  test-airgap-deployment:
    timeout-minutes: 90  # Default is 60
```

### Additional Namespaces

Test multiple deployments:

```bash
# In workflow, add step:
- name: Verify Additional Namespace
  run: |
    bash .github/workflows/scripts/verify-images.sh another-namespace
```

## Integration with Development Workflow

### Pre-Release Validation

Before creating a release tag:

```bash
# 1. Update version in manifests
# 2. Run airgap test
gh workflow run test-airgap.yaml
# 3. Wait for success
# 4. Create release
git tag v1.2.0 && git push origin v1.2.0
```

### Continuous Validation

Set up branch protection rules:
1. Require airgap test to pass before merge
2. Ensures all PRs maintain airgap compliance
3. Prevents regressions in airgap coverage

## Best Practices

1. **Run workflow on every manifest change**: Catch issues early
2. **Review network logs**: Even successful runs may have warnings
3. **Keep manifests updated**: Track upstream version changes
4. **Document exceptions**: If external access is intentional, document why
5. **Test on real airgap**: GitHub Actions simulates airgap; validate on real disconnected environment

## Known Limitations

1. **GitHub Actions can't fully block internet**: Monitoring-based approach
2. **K3d vs K3s**: Some behaviors differ between K3d and production K3s
3. **Resource constraints**: GitHub runners have limited resources
4. **Image architecture**: Testing single architecture (amd64)
5. **DNS resolution**: May show connections to DNS servers

## Related Documentation

- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md)
- [Hauler Documentation](https://github.com/hauler-dev/hauler)
- [K3d Documentation](https://k3d.io/)
- [ESS Helm Chart](https://github.com/element-hq/ess-helm)

## Contributing

To improve the airgap testing workflow:

1. Add more validation checks
2. Improve network monitoring
3. Add support for additional platforms
4. Enhance reporting
5. Add more comprehensive package testing

Submit PRs with improvements!

## Support

For issues with the airgap testing workflow:

1. Check workflow logs in GitHub Actions
2. Download and review test artifacts
3. Consult troubleshooting section above
4. Open an issue with:
   - Workflow run URL
   - Error messages
   - Artifacts (if applicable)
