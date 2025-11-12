# Airgap Test Workflow Improvements

This document describes the improvements made to synchronize the GitHub Actions airgap test workflow (`test-airgap.yaml`) with bug fixes from the local airgap test script (`local-airgap-test.sh`).

## Overview

The local airgap test script (`local-airgap-test.sh`) had several bug fixes and improvements that were not present in the GitHub Actions workflow. This update brings those improvements to the CI/CD pipeline and creates shared functions to reduce code duplication.

## Key Bug Fixes Applied

### 1. Directory Management for Hauler Fileserver
**Problem**: Hauler fileserver could encounter permission issues when writing to the default directory.

**Fix**: Added `--directory` flag to Hauler fileserver commands to use isolated writable directories:
```bash
hauler store serve fileserver --port 8080 --store k3s-store --directory /tmp/k3s-fileserver
```

**Impact**: Prevents permission-related failures in CI environments.

### 2. Architecture-Aware Helm Download
**Problem**: Helm download was hardcoded to `helm-linux-amd64.tar.gz`, which would fail on ARM64 systems.

**Fix**: Added architecture detection and dynamic filename:
```bash
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac
curl -sfL "http://localhost:8081/helm-linux-${ARCH}.tar.gz" -o /tmp/helm.tar.gz
```

**Impact**: Supports multi-architecture deployments.

### 3. Updated ESS Helm Values to Match Schema 25.11.0
**Problem**: The ESS values file used per-component ingress sections and deprecated `postgresql` key, which caused deployment failures with matrix-stack 25.11.0.

**Fix**: Updated values file to use global `ingress.tlsEnabled: false` and removed deprecated keys:
```yaml
serverName: ${DOMAIN}
ingress:
  tlsEnabled: false
synapse:
  enabled: true
elementWeb:
  enabled: true
# Removed deprecated postgresql key and per-component ingress sections
```

**Impact**: Critical fix for ESS deployment compatibility.

### 4. Use --plain-http for Helm OCI Registry
**Problem**: The workflow used deprecated `--insecure-skip-tls-verify` flag.

**Fix**: Replaced with modern `--plain-http` flag:
```bash
helm upgrade --install ess \
  oci://localhost:5002/hauler/matrix-stack \
  --version ${ESS_CHART_VERSION} \
  --plain-http \
  --wait
```

**Impact**: Uses current Helm best practices and clearer intent.

### 5. Improved Retry Logic with Timeouts
**Problem**: Service startup verification had minimal retry logic and could fail on slower systems.

**Fix**: Implemented robust retry loops (30 attempts with 1-second intervals) in shared functions:
```bash
local retries=0
while [ $retries -lt 30 ]; do
  if curl -f -s "http://localhost:$port/v2/_catalog" > /dev/null 2>&1; then
    return 0
  fi
  retries=$((retries + 1))
  sleep 1
done
```

**Impact**: More reliable service startup, especially in resource-constrained CI environments.

### 6. Better Error Messages with Log Tailing
**Problem**: When services failed to start, there was limited diagnostic information.

**Fix**: Added automatic log tailing on failure:
```bash
if [ $retries -eq 30 ]; then
  echo "❌ Service failed to start after 30 seconds"
  echo "Last 50 lines of log:"
  tail -n 50 "$log_file"
  return 1
fi
```

**Impact**: Easier debugging of failures in CI runs.

### 7. Use Shared Scripts for Validation
**Problem**: Image verification was implemented inline with duplicated code.

**Fix**: Now uses the existing `verify-images.sh` script:
```bash
bash .github/workflows/scripts/verify-images.sh ess
```

**Impact**: Consistent validation logic between local and CI tests.

### 8. Use Shared Scripts for Network Monitoring
**Problem**: Network monitoring was implemented inline with duplicated code.

**Fix**: Now uses the existing `network-monitor.sh` script:
```bash
export LOG_FILE="/tmp/network-activity.log"
bash .github/workflows/scripts/network-monitor.sh
```

**Impact**: Consistent monitoring logic between local and CI tests.

## New Shared Functions

Created `.github/workflows/scripts/hauler-functions.sh` to eliminate code duplication:

### Functions Provided:
- `start_hauler_registry()` - Start Hauler registry with retry logic
- `start_hauler_fileserver()` - Start Hauler fileserver with retry logic
- `verify_hauler_registry()` - Verify registry is accessible
- `verify_hauler_fileserver()` - Verify fileserver is accessible
- `stop_hauler_services()` - Stop all Hauler services
- Helper logging functions compatible with both CI and local scripts

### Usage in GitHub Actions:
```bash
source .github/workflows/scripts/hauler-functions.sh

start_hauler_registry \
  5001 \
  "k3s-store" \
  "hauler/k3s" \
  "/tmp/k3s-registry.log" \
  "/tmp/k3s-registry.pid" || exit 1
```

### Usage in Local Script:
```bash
source "$SCRIPT_DIR/hauler-functions.sh"

start_hauler_registry \
  "$K3S_REGISTRY_PORT" \
  "k3s-store" \
  "$REPO_ROOT/hauler/k3s" \
  "$LOG_DIR/k3s-registry.log" \
  "$WORK_DIR/k3s-registry.pid" || exit 1
```

## Code Reduction

- **Before**: ~370 lines of duplicated service startup and verification code
- **After**: ~60 lines of shared functions, used by both scripts
- **Reduction**: ~310 lines of duplicate code eliminated

## Testing

All scripts have been validated:
- ✅ YAML syntax validation
- ✅ Bash syntax validation
- ✅ Function sourcing validation
- ✅ Workflow structure validation

## Migration Path for Future Features

When adding new features to the airgap test:

1. **If the feature is service management related**: Add it to `hauler-functions.sh`
2. **If the feature is validation related**: Add it to `verify-images.sh` or `network-monitor.sh`
3. **If the feature is workflow-specific**: Add it directly to the workflow or local script

This ensures code reuse and maintainability.

## Backward Compatibility

All changes are backward compatible:
- Existing workflow triggers remain unchanged
- Environment variables remain unchanged
- Output format remains unchanged
- Fallback mechanisms ensure older patterns still work

## Future Improvements

Potential future enhancements identified during this work:

1. **Just/Make integration**: Create a Justfile to share even more code between local and CI
2. **Modular test phases**: Break down the test into reusable phases (build, deploy, validate)
3. **Parameterized tests**: Allow testing different versions/configurations via workflow inputs
4. **Performance metrics**: Add timing and resource usage tracking
5. **Artifact caching**: Cache Hauler stores between CI runs for faster iteration

## Related Files

- `.github/workflows/test-airgap.yaml` - Main CI workflow
- `.github/workflows/scripts/local-airgap-test.sh` - Local test script
- `.github/workflows/scripts/hauler-functions.sh` - Shared service management functions
- `.github/workflows/scripts/verify-images.sh` - Image source verification
- `.github/workflows/scripts/network-monitor.sh` - Network activity monitoring
- `.github/workflows/scripts/verify-packages.sh` - Package verification
