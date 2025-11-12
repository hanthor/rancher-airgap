# YAML Configuration Refactoring

**Date**: November 12, 2025  
**Branch**: `copilot/make-airgap-test-locally-runnable`

## Summary

Extracted embedded Kubernetes/Helm YAML configurations from shell scripts into separate, versioned configuration files. This improves maintainability, enables schema validation, and provides better IDE support.

## Changes Made

### 1. New Configuration Files

**`.github/workflows/config/`** - New directory for configuration files

- **`k3s-registries.yaml`** - K3s container registry configuration
  - Configures local Hauler registries for airgap testing
  - Variables: `localhost:5001`, `localhost:5002` (substituted at runtime)
  - Validated by K3s on startup

- **`ess-values.yaml`** - ESS Helm chart values
  - Production-ready template for Element Server Suite
  - Variables: `ess.local` → `$DOMAIN` (substituted at runtime)
  - **Validated by Helm schema** before deployment

- **`README.md`** - Documentation for configuration files
  - Usage instructions
  - Validation procedures
  - Variables and substitution rules

### 2. New Validation Script

**`.github/workflows/scripts/validate-helm-values.sh`**
- Standalone Helm values validation utility
- Supports OCI and traditional chart repositories
- Validates values against chart JSON schema
- Renders templates to catch deployment-time errors

```bash
# Usage example
./validate-helm-values.sh \
  oci://localhost:5002/hauler/matrix-stack \
  .github/workflows/config/ess-values.yaml \
  25.11.0
```

### 3. Updated Scripts

**`local-airgap-test.sh`**
- ✅ Uses `$CONFIG_DIR/k3s-registries.yaml` instead of heredoc
- ✅ Uses `$CONFIG_DIR/ess-values.yaml` instead of heredoc  
- ✅ Adds Helm values validation step
- ✅ Substitutes variables with `sed` at deployment time
- ✅ Added namespace-level privileged Pod Security

**`test-airgap.yaml`** (GitHub Actions)
- ✅ Uses `.github/workflows/config/ess-values.yaml`
- ✅ Adds Helm lint validation step
- ✅ Added namespace-level privileged Pod Security
- ✅ Matches local script behavior

## Benefits

### Schema Validation
Before this change, invalid Helm values would only be caught during deployment (after 5-10 minutes of waiting). Now:

```bash
# Validate immediately
./validate-helm-values.sh oci://localhost:5002/hauler/matrix-stack ess-values.yaml 25.11.0
# ✅ Values file is valid!
```

### IDE Support
- Syntax highlighting for YAML
- Auto-completion with Helm/K8s schemas
- Linting and validation in editor
- Better diff views in Git

### Maintainability
| Before | After |
|--------|-------|
| YAML embedded in shell heredocs | Separate `.yaml` files |
| No validation until deployment | Pre-deployment validation |
| Hard to review in PRs | Clear YAML diffs |
| No reusability | Shared across scripts |

### Security
Easier to review security-related configuration:
- Pod Security Standard settings visible
- Security context overrides documented
- Clear warnings for testing-only configurations

## Migration Guide

### For New Helm Charts

Instead of embedding values in scripts:

```bash
# ❌ Old way - embedded YAML
cat > /tmp/values.yaml <<EOF
replicas: 3
image: myapp:latest
EOF
helm install myapp ./chart -f /tmp/values.yaml
```

Do this:

```bash
# ✅ New way - external config
# 1. Create config file
cat > .github/workflows/config/myapp-values.yaml <<EOF
replicas: 3
image: myapp:latest
EOF

# 2. Validate it
./validate-helm-values.sh ./chart .github/workflows/config/myapp-values.yaml

# 3. Use it in script
sed "s/myapp:latest/myapp:${VERSION}/g" \
  "$CONFIG_DIR/myapp-values.yaml" > /tmp/myapp-values.yaml
helm install myapp ./chart -f /tmp/myapp-values.yaml
```

### For K8s Manifests

Similar pattern:
1. Extract to `.github/workflows/config/my-resource.yaml`
2. Use `kubectl apply -f` or `envsubst` for variable substitution
3. Validate with `kubectl apply --dry-run=client`

## Testing

Validated configuration files work correctly:

```bash
# K3s registries
✅ K3s starts successfully with external registries.yaml
✅ Images pull from localhost:5001 and localhost:5002

# ESS Helm values
✅ Schema validation passes
✅ Helm template rendering succeeds
✅ Deployment completes successfully
```

## Next Steps

Consider extracting:
1. Additional K8s manifests (Secrets, ConfigMaps)
2. Kustomize overlays for different environments
3. Policy definitions (NetworkPolicy, PSP, etc.)

## Related Issues

- Fixes: ESS deployment validation errors
- Improves: Developer workflow for Helm values
- Enables: CI/CD validation before deployment
