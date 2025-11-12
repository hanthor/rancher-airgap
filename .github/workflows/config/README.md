# Configuration Files for Airgap Testing

This directory contains Kubernetes and Helm configuration files used by the airgap test scripts. Separating these from the shell scripts provides better maintainability, validation, and IDE support.

## Files

### `k3s-registries.yaml`
**Purpose**: K3s container registry configuration for airgap testing

**Used by**: `local-airgap-test.sh`, GitHub Actions workflows

**Description**: Configures K3s to use local Hauler registries instead of upstream container registries. This enables true airgap testing where all images are pulled from localhost.

**Documentation**: https://docs.k3s.io/installation/private-registry

**Variables substituted**:
- `localhost:5001` → Port configured in `$K3S_REGISTRY_PORT`
- `localhost:5002` → Port configured in `$ESS_REGISTRY_PORT`

**Validation**: K3s validates this file automatically on startup

---

### `ess-values.yaml`
**Purpose**: Helm values for Element Server Suite (ESS) deployment

**Used by**: `local-airgap-test.sh`, GitHub Actions workflows

**Chart**: `element-hq/matrix-stack`

**Documentation**: https://github.com/element-hq/ess-helm

**Description**: Production-ready template for ESS deployment with all required ingress hosts configured. Uses internal PostgreSQL for testing (should be external in production).

**Variables substituted**:
- `ess.local` → Value of `$DOMAIN` environment variable

**Security Note**: This configuration requires `privileged` Pod Security Standard at the namespace level for K3s testing. In production:
- Use restricted Pod Security Admission policies
- Configure proper AppArmor/SELinux profiles
- Use external managed PostgreSQL database
- Review ESS security hardening guide

**Validation**: 
```bash
# Validate against chart schema
.github/workflows/scripts/validate-helm-values.sh \
  oci://localhost:5002/hauler/matrix-stack \
  .github/workflows/config/ess-values.yaml \
  25.11.0

# Or during deployment
helm lint oci://localhost:5002/hauler/matrix-stack \
  --values .github/workflows/config/ess-values.yaml \
  --version 25.11.0 \
  --plain-http
```

---

## Adding New Configuration Files

When adding new Kubernetes or Helm configuration:

1. **Create the YAML file** in this directory
2. **Add schema validation** where applicable (Helm charts, CRDs, etc.)
3. **Document variables** that get substituted at runtime
4. **Update this README** with usage instructions
5. **Update relevant scripts** to use the external file instead of heredocs

### Example: Adding a new Helm values file

```bash
# 1. Create the values file
cat > .github/workflows/config/my-app-values.yaml <<EOF
# My App Helm Values
appName: my-app
replicas: 3
EOF

# 2. Update script to use it
sed "s/my-app/${APP_NAME}/g" "$CONFIG_DIR/my-app-values.yaml" > /tmp/my-app-values.yaml

# 3. Validate before deployment
helm lint my-chart --values /tmp/my-app-values.yaml

# 4. Deploy
helm upgrade --install my-app my-chart --values /tmp/my-app-values.yaml
```

## Benefits of Separated Configuration

✅ **Schema Validation**: Helm/Kubernetes tooling can validate YAML syntax and schemas
✅ **IDE Support**: Syntax highlighting, auto-completion, linting
✅ **Version Control**: Better diffs and conflict resolution
✅ **Reusability**: Same configs can be used by multiple scripts
✅ **Security**: Easier to review and audit configuration changes
✅ **Documentation**: Self-documenting with inline comments

## Related Scripts

- `validate-helm-values.sh` - Validates Helm values against chart schemas
- `local-airgap-test.sh` - Uses these configs for local K3s testing
- `test-airgap.yaml` (GitHub Actions) - CI/CD airgap testing workflow
