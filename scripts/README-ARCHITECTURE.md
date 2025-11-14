# Airgap Script Architecture

This directory contains a modular function library and scripts for building and deploying airgapped K3s + ESS environments.

## Architecture Overview

The codebase follows a **shared library pattern** where all core functionality lives in `airgap-lib.sh`, and specific use cases are implemented as thin wrapper scripts.

```
airgap-lib.sh          # Core function library (shared)
├── hauler-functions.sh # Hauler service management (shared)
│
├── build-airgap-assets.sh    # Collection phase only
├── deploy-airgap.sh          # Distribution phase only  
└── local-airgap-test.sh      # End-to-end testing (both phases)
```

## Files

### Core Libraries

- **`airgap-lib.sh`** - Main function library with all core logic:
  - Environment detection and validation
  - Hauler installation and store building
  - K3s installation and configuration
  - Helm installation
  - ESS deployment
  - Validation and reporting
  - All functions are reusable across scripts

- **`hauler-functions.sh`** - Hauler service management:
  - Starting/stopping Hauler registry and fileserver
  - Health checks and validation
  - Process management

### Workflow Scripts

#### 1. `build-airgap-assets.sh` - Collection Phase

**Purpose**: Build Hauler stores on a **CONNECTED** system

```bash
sudo ./build-airgap-assets.sh
```

**What it does**:
- Installs Hauler
  - Builds K3s, ESS, and Helm Hauler stores
  - Outputs stores to `.build/*/` directories

**Use when**:
- Creating airgap assets for the first time
- Updating to new versions
- Running on a system with internet access

**Output**:
- `.build/k3s/k3s-store/`
- `.build/ess-helm/ess-store/`
- `.build/helm/helm-store/`

#### 2. `deploy-airgap.sh` - Distribution Phase

**Purpose**: Deploy from existing Hauler stores on a **DISCONNECTED** system

```bash
sudo ./deploy-airgap.sh
```

**What it does**:
- Verifies Hauler stores exist
- Installs K3s from local stores
- Starts Hauler registry and fileserver
- Installs Helm from local stores
- Deploys ESS from local registry
- Validates deployment

**Use when**:
- Deploying in an airgapped environment
- Hauler stores already exist or were transferred
- No internet connection available

**Requirements**:
- Pre-built Hauler stores in `.build/*/` directories
- OR loaded from archives (`hauler store load`)

#### 3. `local-airgap-test.sh` - End-to-End Testing

**Purpose**: Full cycle test (build + deploy) on a **CONNECTED** system

```bash
sudo ./local-airgap-test.sh run
```

**What it does**:
- Builds Hauler stores (if needed)
- Deploys K3s + ESS
- Validates everything works
- Provides cleanup commands

**Additional commands**:
```bash
sudo ./local-airgap-test.sh light-cleanup  # Reset but keep stores
sudo ./local-airgap-test.sh cleanup        # Full cleanup
```

**Use when**:
- Testing end-to-end airgap workflow
- Validating manifest changes
- Local development and iteration

## Typical Workflows

### Workflow 1: Build and Deploy (Two Systems)

**On connected system:**
```bash
# Build airgap assets
sudo ./build-airgap-assets.sh

# Save to archives for transfer
cd ../../.build/k3s
hauler store save --store k3s-store --filename k3s.tar.zst

cd ../ess-helm  
hauler store save --store ess-store --filename ess.tar.zst

cd ../helm
hauler store save --store helm-store --filename helm.tar.zst
```

**Transfer archives to disconnected system**

**On disconnected system:**
```bash
# Load Hauler stores
cd .build/k3s
hauler store load --filename k3s.tar.zst

cd ../ess-helm
hauler store load --filename ess.tar.zst

cd ../helm
hauler store load --filename helm.tar.zst

# Deploy
sudo ./deploy-airgap.sh
```

### Workflow 2: Local Testing (Single System)

```bash
# Full end-to-end test
sudo ./local-airgap-test.sh run

# Make changes, test again (reuses stores)
sudo ./local-airgap-test.sh light-cleanup
sudo ./local-airgap-test.sh run

# Full cleanup when done
sudo ./local-airgap-test.sh cleanup
```

### Workflow 3: GitHub Actions Integration

The library functions can be sourced directly in GitHub Actions:

```yaml
- name: Build airgap assets
  run: |
    source .github/workflows/scripts/airgap-lib.sh
    install_hauler "$HAULER_VERSION" "$ARCH"
    build_all_hauler_stores "$GITHUB_WORKSPACE" "$ARCH" "$LOG_DIR"
```

## Configuration

All scripts use environment variables with defaults:

```bash
# Versions (updated by Renovate)
HAULER_VERSION=1.3.1
K3S_VERSION=v1.33.5+k3s1
HELM_VERSION=v3.19.0
ESS_CHART_VERSION=25.11.0

# Deployment
DOMAIN=ess.local
PLATFORM=$(uname -m)  # auto-detected

# Directories
WORK_DIR=/tmp/airgap-*
LOG_DIR=$WORK_DIR/logs
STORE_DIR=$REPO_ROOT/hauler

# Ports
K3S_REGISTRY_PORT=5001
ESS_REGISTRY_PORT=5002
K3S_FILESERVER_PORT=8080
HELM_FILESERVER_PORT=8081
```

Override any variable before running:

```bash
DOMAIN=matrix.example.com sudo ./deploy-airgap.sh
```

## Function Reference

### From `airgap-lib.sh`:

#### Environment
- `detect_architecture(platform)` - Detect CPU architecture
- `check_root()` - Verify running as root
- `check_prerequisites(mode)` - Validate dependencies
- `setup_directories(work_dir, log_dir)` - Create directory structure

#### Hauler
- `install_hauler(version, arch)` - Install Hauler binary
- `build_hauler_store(name, dir, manifest, platform, log)` - Build single store
- `build_all_hauler_stores(repo_root, arch, log_dir)` - Build all stores

#### K3s
- `configure_k3s_registries(config, k3s_port, ess_port)` - Setup registry config
- `install_k3s_from_hauler(repo, version, arch, work, log, port)` - Install K3s
- `setup_k3s_kubeconfig()` - Configure kubectl access

#### Helm & ESS
- `install_helm_from_hauler(version, arch, port)` - Install Helm
- `deploy_ess(domain, version, port, config, log, repo)` - Deploy ESS
- `validate_ess_deployment(domain, k3s_ver, ess_ver, arch)` - Validate

### From `hauler-functions.sh`:

- `start_hauler_registry(port, store, path, log, pid)` - Start registry
- `start_hauler_fileserver(port, store, path, log, pid, dir)` - Start fileserver
- `stop_hauler_services()` - Stop all Hauler services

## Benefits of This Architecture

1. **Code Reuse**: One implementation shared across all use cases
2. **Consistency**: Same behavior in local tests, CI/CD, and production
3. **Maintainability**: Fix bugs once, benefits everywhere
4. **Flexibility**: Easy to create new workflows by combining functions
5. **Testability**: Each function can be tested independently
6. **Documentation**: Functions are self-documenting with clear parameters

## Migration from Old Scripts

The original `local-airgap-test.sh` has been refactored into:
- Core logic → `airgap-lib.sh`
- Workflow orchestration → `local-airgap-test-new.sh`

Both versions coexist during transition. Once validated, rename:
```bash
mv local-airgap-test.sh local-airgap-test-old.sh
mv local-airgap-test-new.sh local-airgap-test.sh
```

## Future Enhancements

Potential additions to the library:

- `save_hauler_stores()` - Save all stores to archives
- `load_hauler_stores()` - Load all stores from archives  
- `verify_airgap_mode()` - Ensure no external network access
- `generate_deployment_report()` - Create detailed status report
- `backup_ess_data()` - Backup ESS persistent data
- `restore_ess_data()` - Restore from backup
