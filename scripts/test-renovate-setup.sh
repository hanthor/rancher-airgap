#!/bin/bash
# Test script for Renovate configuration and ESS automation
# This script helps validate the setup locally

set -e

echo "=== Renovate Configuration Test ==="
echo ""

# Check if renovate.json exists
if [ ! -f "renovate.json" ]; then
    echo "❌ Error: renovate.json not found"
    exit 1
fi
echo "✅ renovate.json found"

# Validate renovate.json syntax
echo "Validating renovate.json syntax..."
if command -v npx &> /dev/null; then
    if npx --yes -p renovate renovate-config-validator 2>&1 | grep -q "Config validated successfully"; then
        echo "✅ renovate.json is valid"
    else
        echo "❌ renovate.json validation failed"
        npx --yes -p renovate renovate-config-validator
        exit 1
    fi
else
    echo "⚠️  npx not found, skipping validation (install Node.js to validate)"
fi

echo ""
echo "=== Workflow Files Test ==="
echo ""

# Check if update-ess-images.yaml exists
if [ ! -f ".github/workflows/update-ess-images.yaml" ]; then
    echo "❌ Error: .github/workflows/update-ess-images.yaml not found"
    exit 1
fi
echo "✅ update-ess-images.yaml found"

# Validate YAML syntax
if command -v yamllint &> /dev/null; then
    echo "Validating update-ess-images.yaml syntax..."
    if yamllint -d relaxed .github/workflows/update-ess-images.yaml 2>&1 | grep -q "error"; then
        echo "❌ update-ess-images.yaml has errors"
        yamllint -d relaxed .github/workflows/update-ess-images.yaml
        exit 1
    else
        echo "✅ update-ess-images.yaml is valid (warnings are acceptable)"
    fi
else
    echo "⚠️  yamllint not found, skipping validation"
fi

echo ""
echo "=== Version Tracking Test ==="
echo ""

# Check if versions are tracked in expected files
echo "Checking ESS Helm Chart version tracking..."

# Check hauler manifest
if grep -q "version: 25.11.0" hauler/ess-helm/rancher-airgap-ess-helm.yaml; then
    echo "✅ ESS version found in hauler manifest"
else
    echo "⚠️  ESS version format may have changed in hauler manifest"
fi

# Check hauler script
if grep -q "export vESSHelmChart=" hauler/scripts/ess-helm/hauler-ess-helm.sh; then
    echo "✅ ESS version variable found in hauler script"
else
    echo "❌ ESS version variable not found in hauler script"
    exit 1
fi

# Check test-airgap workflow
if grep -q "ESS_CHART_VERSION:" .github/workflows/test-airgap.yaml; then
    echo "✅ ESS version found in test-airgap workflow"
else
    echo "⚠️  ESS version not found in test-airgap workflow"
fi

echo ""
echo "Checking K3s version tracking..."

# Check hauler script
if grep -q "export vK3S=" hauler/scripts/k3s/hauler-k3s.sh; then
    echo "✅ K3s version variable found in hauler script"
else
    echo "❌ K3s version variable not found in hauler script"
    exit 1
fi

# Check test-airgap workflow
if grep -q "K3S_VERSION:" .github/workflows/test-airgap.yaml; then
    echo "✅ K3s version found in test-airgap workflow"
else
    echo "⚠️  K3s version not found in test-airgap workflow"
fi

echo ""
echo "Checking Helm version tracking..."

# Check hauler script
if grep -q "export vHelm=" hauler/scripts/helm/hauler-helm.sh; then
    echo "✅ Helm version variable found in hauler script"
else
    echo "❌ Helm version variable not found in hauler script"
    exit 1
fi

# Check test-airgap workflow
if grep -q "HELM_VERSION:" .github/workflows/test-airgap.yaml; then
    echo "✅ Helm version found in test-airgap workflow"
else
    echo "⚠️  Helm version not found in test-airgap workflow"
fi

echo ""
echo "Checking Hauler version tracking..."

# Check test-airgap workflow
if grep -q "HAULER_VERSION:" .github/workflows/test-airgap.yaml; then
    echo "✅ Hauler version found in test-airgap workflow"
else
    echo "⚠️  Hauler version not found in test-airgap workflow"
fi

echo ""
echo "=== Documentation Test ==="
echo ""

# Check if documentation exists
if [ ! -f ".github/workflows/RENOVATE.md" ]; then
    echo "❌ Error: .github/workflows/RENOVATE.md not found"
    exit 1
fi
echo "✅ RENOVATE.md documentation found"

# Check if README mentions Renovate
if grep -q "Renovate" README.md; then
    echo "✅ README.md mentions Renovate"
else
    echo "⚠️  README.md doesn't mention Renovate"
fi

echo ""
echo "=== Summary ==="
echo ""
echo "✅ All critical tests passed!"
echo ""
echo "Next steps:"
echo "1. Merge this PR to enable Renovate"
echo "2. Ensure Renovate bot is installed on the repository"
echo "3. Wait for Renovate to run (scheduled for weekends)"
echo "4. Review and test any PRs created by Renovate"
echo ""
echo "To manually test the ESS image update workflow:"
echo "  gh workflow run update-ess-images.yaml -f ess_chart_version=25.11.0"
echo ""
