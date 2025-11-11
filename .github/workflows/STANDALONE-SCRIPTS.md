# Using Validation Scripts Standalone

The validation scripts in `.github/workflows/scripts/` can be used independently for local testing and validation.

## Prerequisites

```bash
# Ensure scripts are executable
chmod +x .github/workflows/scripts/*.sh

# Install required tools
sudo apt-get install -y netstat jq kubectl
```

## Verify Images Script

Checks that all pod images in a namespace are from local registries.

### Usage

```bash
# Check images in 'ess' namespace
.github/workflows/scripts/verify-images.sh ess

# Check images in 'default' namespace
.github/workflows/scripts/verify-images.sh default

# Check images in 'kube-system' namespace
.github/workflows/scripts/verify-images.sh kube-system
```

### Example Output

```
=======================================
Image Source Verification
=======================================
Namespace: ess
Allowed registries: host.k3d.internal localhost 127.0.0.1

Checking pod images in namespace: ess
---
✅ LOCAL: localhost:5000/hauler/synapse:v1.123.0
✅ LOCAL: localhost:5000/hauler/element-web:v1.12.3
✅ LOCAL: localhost:5000/hauler/postgres:17.2-alpine
❌ EXTERNAL: ghcr.io/element-hq/matrix-authentication-service:0.17.0

=======================================
Summary
=======================================
Total images: 4
Local images: 3
External images: 1

❌ AIRGAP VALIDATION FAILED
Found 1 images from external sources

Action required:
1. Add missing images to Hauler manifests
2. Rebuild Hauler stores
3. Re-run airgap test
```

### Customizing Allowed Registries

Edit the script to add custom registries:

```bash
# In verify-images.sh
ALLOWED_REGISTRIES=(
  "host.k3d.internal"
  "localhost"
  "127.0.0.1"
  "registry.example.com"  # Add your registry
)
```

## Verify Packages Script

Validates that required OS packages are available in a local repository.

### Usage

```bash
# Check default repository location
.github/workflows/scripts/verify-packages.sh /tmp/os-repo

# Check custom repository location
.github/workflows/scripts/verify-packages.sh /opt/hauler/repos
```

### Example Output

```
=======================================
OS Package Repository Verification
=======================================
Repository directory: /tmp/os-repo
Required packages: iptables container-selinux libnetfilter_conntrack ...

Checking for required packages...
---
✅ FOUND: iptables
✅ FOUND: container-selinux
❌ MISSING: libnetfilter_conntrack
✅ FOUND: git

=======================================
Summary
=======================================
Total required packages: 8
Found packages: 7
Missing packages: 1

All packages in repository:
  - iptables_1.8.7-1_amd64.deb
  - container-selinux_2.167.0-1_all.deb
  - git_2.34.1-1_amd64.deb

⚠️  WARNING: Missing 1 required packages

Action required:
1. Download missing packages on connected server
2. Add to OS repository
3. Recreate repository metadata
```

### Customizing Required Packages

Edit the script to modify package list:

```bash
# In verify-packages.sh
REQUIRED_PACKAGES=(
  "iptables"
  "container-selinux"
  "git"
  "curl"
  "custom-package"  # Add your package
)
```

## Network Monitor Script

Monitors network connections and detects external access attempts.

### Usage

```bash
# Run with default settings
.github/workflows/scripts/network-monitor.sh

# Run with custom log file
LOG_FILE=/tmp/my-network.log .github/workflows/scripts/network-monitor.sh

# Run with custom monitoring interval (seconds)
MONITOR_INTERVAL=10 .github/workflows/scripts/network-monitor.sh

# Run in background
nohup .github/workflows/scripts/network-monitor.sh &

# Stop monitor
pkill -f network-monitor.sh
```

### Example Output

```
Network Monitor Started: 2025-01-15 10:30:00
Monitoring for external connections...
Allowed hosts: 127.0.0.1 localhost host.k3d.internal 0.0.0.0
Allowed ports: 5000 5001 5002 8080 8081 6443
---
Starting monitoring loop (Ctrl+C to stop)...
[2025-01-15 10:30:15] EXTERNAL CONNECTION: tcp 0 0 10.0.1.5:45678 93.184.216.34:443 ESTABLISHED
[2025-01-15 10:30:20] HTTP/HTTPS CONNECTION: tcp 0 0 10.0.1.5:45679 185.199.108.133:443 ESTABLISHED
```

### Customizing Allowed Connections

Edit the script to modify allowed hosts/ports:

```bash
# In network-monitor.sh
ALLOWED_HOSTS=(
  "127.0.0.1"
  "localhost"
  "my-registry.local"  # Add your host
)

ALLOWED_PORTS=(
  "5000"
  "8080"
  "3000"  # Add your port
)
```

### Analyzing Monitor Results

```bash
# View all logs
cat /tmp/network-activity.log

# View only alerts (external connections)
cat /tmp/network-alerts.log

# Count external connections
grep "EXTERNAL CONNECTION" /tmp/network-activity.log | wc -l

# Find unique external hosts
grep "EXTERNAL CONNECTION" /tmp/network-activity.log | \
  awk '{print $5}' | cut -d':' -f1 | sort -u

# Find most common external destinations
grep "EXTERNAL CONNECTION" /tmp/network-activity.log | \
  awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn
```

## Combined Validation Workflow

Run all validations together:

```bash
#!/bin/bash
# run-all-validations.sh

set -e

echo "Running all airgap validations..."
echo "================================"

# 1. Verify images
echo ""
echo "1. Verifying images in ess namespace..."
.github/workflows/scripts/verify-images.sh ess

# 2. Verify packages
echo ""
echo "2. Verifying OS packages..."
.github/workflows/scripts/verify-packages.sh /tmp/os-repo

# 3. Show network activity summary
echo ""
echo "3. Network activity summary..."
if [ -f /tmp/network-activity.log ]; then
  echo "External connections detected: $(grep -c EXTERNAL /tmp/network-activity.log || echo 0)"
  echo "DNS queries detected: $(grep -c 'DNS QUERY' /tmp/network-activity.log || echo 0)"
  echo "HTTP/HTTPS connections: $(grep -c 'HTTP/HTTPS' /tmp/network-activity.log || echo 0)"
else
  echo "No network activity log found. Start network-monitor.sh first."
fi

echo ""
echo "Validation complete!"
```

## Integration with CI/CD

### GitLab CI

```yaml
# .gitlab-ci.yml
validate-airgap:
  stage: test
  script:
    - .github/workflows/scripts/verify-images.sh ess
    - .github/workflows/scripts/verify-packages.sh /tmp/os-repo
  artifacts:
    paths:
      - /tmp/network-activity.log
    expire_in: 1 week
```

### Jenkins

```groovy
// Jenkinsfile
pipeline {
  agent any
  stages {
    stage('Validate Airgap') {
      steps {
        sh '.github/workflows/scripts/verify-images.sh ess'
        sh '.github/workflows/scripts/verify-packages.sh /tmp/os-repo'
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: '/tmp/network-activity.log', allowEmptyArchive: true
    }
  }
}
```

### CircleCI

```yaml
# .circleci/config.yml
version: 2.1
jobs:
  validate-airgap:
    docker:
      - image: cimg/base:stable
    steps:
      - checkout
      - run:
          name: Verify Images
          command: .github/workflows/scripts/verify-images.sh ess
      - run:
          name: Verify Packages
          command: .github/workflows/scripts/verify-packages.sh /tmp/os-repo
      - store_artifacts:
          path: /tmp/network-activity.log
```

## Troubleshooting

### Script Not Found

```bash
# Ensure you're in repository root
cd /path/to/rancher-airgap

# Make scripts executable
chmod +x .github/workflows/scripts/*.sh
```

### Permission Denied

```bash
# Run with sudo if needed (for netstat)
sudo .github/workflows/scripts/network-monitor.sh
```

### Missing Dependencies

```bash
# Install jq
sudo apt-get install -y jq

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install net-tools (for netstat)
sudo apt-get install -y net-tools
```

## Best Practices

1. **Run before deployment**: Validate manifests before deploying
2. **Monitor during deployment**: Start network monitor before deploying
3. **Review logs**: Always check logs even if validation passes
4. **Customize for your environment**: Adjust allowed registries and packages
5. **Integrate with CI**: Automate validation in your pipeline
6. **Document exceptions**: If external access is intentional, document why

## Advanced Usage

### Continuous Monitoring

```bash
# Run network monitor continuously
while true; do
  .github/workflows/scripts/network-monitor.sh
  sleep 60
done
```

### Scheduled Validation

```bash
# Add to crontab for daily validation
0 0 * * * cd /path/to/rancher-airgap && .github/workflows/scripts/verify-images.sh ess >> /var/log/airgap-validation.log 2>&1
```

### Email Alerts

```bash
# Send email if validation fails
.github/workflows/scripts/verify-images.sh ess || \
  echo "Airgap validation failed!" | mail -s "Airgap Alert" admin@example.com
```

## Related Documentation

- [Airgap Testing Workflow](README-AIRGAP-TESTING.md)
- [Quick Reference](AIRGAP-TESTING-QUICKREF.md)
- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md)
