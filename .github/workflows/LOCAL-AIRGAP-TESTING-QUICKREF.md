# Local Airgap Testing - Quick Reference

Quick commands and troubleshooting for local K3s airgap testing.

## Quick Start

```bash
# Run complete test
sudo .github/workflows/scripts/local-airgap-test.sh

# Cleanup
sudo .github/workflows/scripts/local-airgap-test.sh cleanup

# Show help
.github/workflows/scripts/local-airgap-test.sh help
```

## Custom Configuration

```bash
# Custom domain
sudo DOMAIN=matrix.test .github/workflows/scripts/local-airgap-test.sh

# Specific versions
sudo K3S_VERSION=v1.34.0+k3s1 \
     ESS_CHART_VERSION=25.12.0 \
     .github/workflows/scripts/local-airgap-test.sh

# All options
sudo DOMAIN=matrix.internal \
     K3S_VERSION=v1.33.5+k3s1 \
     ESS_CHART_VERSION=25.11.0 \
     HAULER_VERSION=1.3.0 \
     .github/workflows/scripts/local-airgap-test.sh
```

## Common Tasks

### Check Status

```bash
# K3s status
systemctl status k3s
journalctl -u k3s -f

# Cluster status
k3s kubectl cluster-info
k3s kubectl get nodes

# Pod status
k3s kubectl get pods -n ess -o wide

# Service status
k3s kubectl get svc -n ess
```

### View Logs

```bash
# Script logs
ls -lh /tmp/airgap-test/logs/
cat /tmp/airgap-test/logs/ess-install.log

# K3s logs
journalctl -u k3s -n 100 --no-pager

# Pod logs
k3s kubectl logs -n ess <pod-name>
k3s kubectl logs -n ess <pod-name> --previous

# Hauler service logs
cat /tmp/airgap-test/logs/k3s-registry.log
cat /tmp/airgap-test/logs/ess-registry.log
```

### Debug Commands

```bash
# Describe pod
k3s kubectl describe pod -n ess <pod-name>

# Get events
k3s kubectl get events -n ess --sort-by='.lastTimestamp'

# Check image pulls
k3s kubectl get pods -n ess -o json | jq -r '.items[].spec.containers[].image'

# Verify registry
curl http://localhost:5001/v2/_catalog | jq
curl http://localhost:5002/v2/_catalog | jq

# Check fileserver
curl http://localhost:8080/
curl http://localhost:8081/

# Test registry access
k3s kubectl run test --image=busybox --restart=Never -- sleep 3600
```

## Troubleshooting

### K3s Won't Start

```bash
# Check service
systemctl status k3s
journalctl -u k3s -n 50

# Check binary
ls -lh /usr/local/bin/k3s
/usr/local/bin/k3s --version

# Check configuration
cat /etc/rancher/k3s/registries.yaml

# Restart K3s
systemctl restart k3s
systemctl status k3s
```

### Hauler Service Issues

```bash
# Check running services
ps aux | grep hauler

# Check port usage
sudo netstat -tlnp | grep -E '5001|5002|8080|8081'

# Kill and restart
sudo pkill -f "hauler store serve"

# Manual start for debugging
cd /path/to/hauler/k3s
hauler store serve registry --port 5001 --store k3s-store
```

### Pods Not Starting

```bash
# Check pod status
k3s kubectl get pods -n ess

# Describe failing pod
k3s kubectl describe pod -n ess <pod-name>

# Check events
k3s kubectl get events -n ess

# Check images
bash .github/workflows/scripts/verify-images.sh ess

# Check resources
k3s kubectl top nodes
k3s kubectl top pods -n ess
```

### Image Pull Errors

```bash
# Verify images in registry
curl http://localhost:5002/v2/_catalog | jq

# Check registry config
cat /etc/rancher/k3s/registries.yaml

# Restart K3s to reload config
systemctl restart k3s

# Check pod image
k3s kubectl get pod -n ess <pod-name> -o jsonpath='{.spec.containers[*].image}'

# Check pull events
k3s kubectl describe pod -n ess <pod-name> | grep -A5 "Events:"
```

### Helm Issues

```bash
# Verify Helm
helm version

# List releases
helm list -n ess

# Get release status
helm status ess -n ess

# Get values
helm get values ess -n ess

# Uninstall and retry
helm uninstall ess -n ess
# Re-run test
```

### Network Issues

```bash
# Check network monitoring
cat /tmp/network-activity.log

# Monitor real-time
sudo bash .github/workflows/scripts/network-monitor.sh

# Check DNS
cat /etc/resolv.conf
nslookup ess.local

# Check /etc/hosts
cat /etc/hosts
```

### Cleanup Issues

```bash
# Force stop all services
sudo pkill -9 -f hauler
sudo pkill -9 -f k3s

# Force uninstall K3s
sudo /usr/local/bin/k3s-uninstall.sh

# Remove all K3s data
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf ~/.kube

# Remove work directory
sudo rm -rf /tmp/airgap-test

# Remove binaries
sudo rm -f /usr/local/bin/k3s
sudo rm -f /usr/local/bin/kubectl
sudo rm -f /usr/local/bin/helm

# Clean iptables
sudo iptables -F
sudo iptables -t nat -F
```

## Access ESS

```bash
# Add DNS entries
sudo tee -a /etc/hosts <<EOF
127.0.0.1 ess.local matrix.ess.local account.ess.local
127.0.0.1 chat.ess.local admin.ess.local mrtc.ess.local
EOF

# Get service ports
k3s kubectl get svc -n ess

# Access Element Web (example with NodePort 30123)
firefox http://chat.ess.local:30123
```

## Iteration Workflow

```bash
# 1. Edit manifest
vim hauler/ess-helm/rancher-airgap-ess-helm.yaml

# 2. Cleanup previous test
sudo .github/workflows/scripts/local-airgap-test.sh cleanup

# 3. Run new test
sudo .github/workflows/scripts/local-airgap-test.sh

# 4. Check results
k3s kubectl get pods -n ess

# 5. Repeat until successful
```

## Validation Commands

```bash
# Verify all images from local registries
bash .github/workflows/scripts/verify-images.sh ess

# Check Hauler stores
cd hauler/k3s
hauler store info --store k3s-store

cd hauler/ess-helm
hauler store info --store ess-store

# Verify no external connections
cat /tmp/network-activity.log
```

## Performance Monitoring

```bash
# Monitor resources
watch -n 5 'free -h && echo && df -h && echo && k3s kubectl top nodes'

# Monitor pod resources
watch -n 5 'k3s kubectl top pods -n ess'

# Monitor K3s
journalctl -u k3s -f

# Monitor all logs
tail -f /tmp/airgap-test/logs/*.log
```

## Pre-Commit Checklist

```bash
# Before committing manifest changes:

# 1. Run local test
sudo .github/workflows/scripts/local-airgap-test.sh

# 2. Verify all pods running
k3s kubectl get pods -n ess

# 3. Verify images from local registry
bash .github/workflows/scripts/verify-images.sh ess

# 4. Check logs for errors
grep -i error /tmp/airgap-test/logs/*.log

# 5. Save logs
cp -r /tmp/airgap-test/logs ~/airgap-logs-$(date +%Y%m%d)

# 6. Cleanup
sudo .github/workflows/scripts/local-airgap-test.sh cleanup

# 7. Commit changes
git add hauler/
git commit -m "Update manifest"
```

## Quick Reference Table

| Task | Command |
|------|---------|
| Run test | `sudo .github/workflows/scripts/local-airgap-test.sh` |
| Cleanup | `sudo .github/workflows/scripts/local-airgap-test.sh cleanup` |
| Check pods | `k3s kubectl get pods -n ess` |
| View logs | `cat /tmp/airgap-test/logs/ess-install.log` |
| K3s status | `systemctl status k3s` |
| Restart K3s | `systemctl restart k3s` |
| Check registry | `curl http://localhost:5002/v2/_catalog` |
| Verify images | `bash .github/workflows/scripts/verify-images.sh ess` |
| Debug pod | `k3s kubectl describe pod -n ess <pod>` |
| Pod logs | `k3s kubectl logs -n ess <pod>` |

## Log Locations

| Log | Path |
|-----|------|
| K3s sync | `/tmp/airgap-test/logs/k3s-sync.log` |
| ESS sync | `/tmp/airgap-test/logs/ess-sync.log` |
| K3s registry | `/tmp/airgap-test/logs/k3s-registry.log` |
| ESS registry | `/tmp/airgap-test/logs/ess-registry.log` |
| K3s fileserver | `/tmp/airgap-test/logs/k3s-fileserver.log` |
| ESS install | `/tmp/airgap-test/logs/ess-install.log` |
| K3s service | `journalctl -u k3s` |

## Port Reference

| Service | Port | URL |
|---------|------|-----|
| K3s Registry | 5001 | http://localhost:5001 |
| ESS Registry | 5002 | http://localhost:5002 |
| K3s Fileserver | 8080 | http://localhost:8080 |
| Helm Fileserver | 8081 | http://localhost:8081 |
| K3s API | 6443 | https://localhost:6443 |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `ess.local` | Domain for ESS |
| `K3S_VERSION` | `v1.33.5+k3s1` | K3s version |
| `ESS_CHART_VERSION` | `25.11.0` | ESS chart version |
| `HAULER_VERSION` | `1.3.0` | Hauler version |
| `PLATFORM` | Auto-detect | Platform architecture |

## See Also

- [Complete Local Testing Guide](LOCAL-AIRGAP-TESTING.md)
- [GitHub Actions Testing Guide](README-AIRGAP-TESTING.md)
- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md)
