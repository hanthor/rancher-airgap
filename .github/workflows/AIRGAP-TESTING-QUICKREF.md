# Airgap Testing Quick Reference

## Quick Commands

### Run Airgap Test

```bash
# Via GitHub CLI
gh workflow run test-airgap.yaml

# Via GitHub UI
Actions → Test Airgap K3s/ESS Deployment → Run workflow
```

### View Results

```bash
# List workflow runs
gh run list --workflow=test-airgap.yaml

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

### Local Testing

```bash
# Install dependencies
curl -sfL https://get.hauler.dev | bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Build Hauler stores
cd hauler/k3s
hauler store sync --store k3s-store --platform linux/amd64 --filename rancher-airgap-k3s.yaml

cd ../ess-helm
hauler store sync --store ess-store --platform linux/amd64 --filename rancher-airgap-ess-helm.yaml

# Start services
hauler store serve registry --port 5001 --store ../k3s/k3s-store &
hauler store serve registry --port 5002 --store ess-store &
hauler store serve fileserver --port 8080 --store ../k3s/k3s-store &

# Create K3d cluster
k3d cluster create test --registry-create test-registry:0.0.0.0:5000

# Verify
curl http://localhost:5001/v2/_catalog
curl http://localhost:5002/v2/_catalog
```

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Image pull from external | Add image to Hauler manifest |
| Pod in CrashLoopBackOff | Check pod logs: `kubectl logs -n ess <pod>` |
| Helm chart not found | Verify chart in Hauler ESS store |
| Binary download fails | Check fileserver is running on port 8080 |
| Network connection detected | Review `network-activity.log` artifact |
| OS package missing | Use `repotrack` to download, add to repo |

## Validation Scripts

### Verify Images

```bash
.github/workflows/scripts/verify-images.sh ess
```

### Verify Packages

```bash
.github/workflows/scripts/verify-packages.sh /tmp/os-repo
```

### Monitor Network

```bash
.github/workflows/scripts/network-monitor.sh
```

## Test Results Checklist

- [ ] Workflow completed successfully
- [ ] All images from local registries
- [ ] All pods in Running state
- [ ] No external network connections (or minimal)
- [ ] ESS health check passes
- [ ] OS packages available
- [ ] Artifacts generated

## Update Workflow

### Add Missing Image

```yaml
# hauler/ess-helm/rancher-airgap-ess-helm.yaml
spec:
  images:
    - name: ghcr.io/element-hq/component:v1.0.0
```

### Add Missing File

```yaml
# hauler/k3s/rancher-airgap-k3s.yaml
spec:
  files:
    - path: https://example.com/file.tar.gz
      name: file.tar.gz
```

### Rebuild and Test

```bash
git add hauler/
git commit -m "Add missing assets"
git push
# Workflow runs automatically on push
```

## Expected Workflow Duration

- Phase 1 (Build): ~5-10 minutes
- Phase 2 (Setup): ~2-3 minutes  
- Phase 3 (Isolation): ~1 minute
- Phase 4 (Deploy): ~10-15 minutes
- Phase 5 (Validate): ~2-3 minutes

**Total**: ~20-35 minutes

## Success Metrics

```
✅ Total images: 15
✅ Local images: 15
✅ External images: 0

✅ Total pods: 8
✅ Running pods: 8
✅ Failed pods: 0

✅ External connections: 0-5 (acceptable)
✅ Airgap compliance: 100%
```

## Debug Mode

Enable for troubleshooting:

```yaml
# Workflow dispatch input
debug_enabled: true
```

This starts a tmate session where you can:
- Inspect cluster state
- Check logs manually
- Test commands interactively

## Quick Links

- [Full Documentation](README-AIRGAP-TESTING.md)
- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md)
- [Workflow File](test-airgap.yaml)
- [Hauler Docs](https://github.com/hauler-dev/hauler)
