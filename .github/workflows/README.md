# Airgap Release Workflow

This workflow automates the creation of airgapped image stores and OS dependencies for deploying K3s, Element Server Suite (ESS), and other Rancher products in disconnected environments.

**📖 Documentation Navigation:**
- **[Quick Start Guide](QUICKSTART.md)** - Get started in 5 minutes ⭐
- **[Architecture Overview](ARCHITECTURE.md)** - Visual workflow diagrams
- **[Secrets Configuration](SECRETS.md)** - Configure Cloudflare R2 uploads
- **[Airgap Testing](README-AIRGAP-TESTING.md)** - Automated airgap validation workflow 🧪
- **[Testing Quick Reference](AIRGAP-TESTING-QUICKREF.md)** - Quick commands and troubleshooting
- **This Document** - Detailed workflow reference

## Trigger Methods

### 1. Automatic (Tag Push)
```bash
git tag v1.0.0
git push origin v1.0.0
```

When you push a tag starting with `v`, the workflow will:
- Build all image stores for both amd64 and arm64
- Create OS dependency tarballs
- Create a GitHub Release with all artifacts
- Optionally upload to Cloudflare R2 (if secrets are configured)

### 2. Manual (Workflow Dispatch)
You can manually trigger the workflow from the GitHub Actions tab:

1. Go to **Actions** → **Airgap Release Build**
2. Click **Run workflow**
3. Choose whether to upload to Cloudflare R2
4. Click **Run workflow**

## Workflow Jobs

### 1. Build Core Products
Builds airgap stores for:
- **K3s**: Lightweight Kubernetes
- **ESS (Element Server Suite)**: Matrix communication platform
- **Helm**: Kubernetes package manager

**Architectures**: linux/amd64, linux/arm64

### 2. Build OS Dependencies
Creates dependency tarballs for each target operating system:
- **Linux**: Full RPM packages for RHEL/CentOS-based systems
- **Windows WSL2**: Dependencies for K3s in WSL2
- **macOS**: Dependencies for K3s via Docker Desktop/Rancher Desktop

### 4. Create GitHub Release
- Downloads all build artifacts
- Creates release notes
- Uploads all tarballs to the GitHub Release

### 4. Upload to Cloudflare R2 (Optional)
- Uploads all artifacts to Cloudflare R2 storage
- Requires R2 credentials in repository secrets

## Required Secrets

The workflow works without any secrets for basic functionality (GitHub Releases only).

### Optional: Cloudflare R2 Upload

To enable Cloudflare R2 uploads, configure these repository secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `R2_ACCESS_KEY_ID` | Cloudflare R2 Access Key ID | `a1b2c3d4e5f6...` |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 Secret Access Key | `secretkey123...` |
| `R2_ENDPOINT` | Cloudflare R2 Endpoint URL | `https://xxxxx.r2.cloudflarestorage.com` |
| `R2_BUCKET` | Cloudflare R2 Bucket Name | `airgap-releases` |

### Setting Secrets

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add each secret with its name and value

## Output Artifacts

### Image Stores
Each product produces two architecture-specific tarballs:
```
<product>-<version>-amd64.tar.zst
<product>-<version>-arm64.tar.zst
```

**Example:**
```
k3s-1.33.5-amd64.tar.zst
k3s-1.33.5-arm64.tar.zst
ess-helm-25.11.0-amd64.tar.zst
ess-helm-25.11.0-arm64.tar.zst
helm-3.19.0-amd64.tar.zst
helm-3.19.0-arm64.tar.zst
```

### OS Dependencies
Each OS produces a tarball with required packages:
```
linux-dependencies-<tag>.tar.gz
windows-wsl2-dependencies-<tag>.tar.gz
macos-dependencies-<tag>.tar.gz
```

**Example:**
```
linux-dependencies-v1.0.0.tar.gz
windows-wsl2-dependencies-v1.0.0.tar.gz
macos-dependencies-v1.0.0.tar.gz
```

## Usage After Release

### 1. Download from GitHub Releases

```bash
# Download image store
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/k3s-1.33.5-amd64.tar.zst

# Download OS dependencies
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/linux-dependencies-v1.0.0.tar.gz
```

### 2. Transfer Across Airgap

Transfer the downloaded files to your disconnected environment using your organization's approved method (USB, secure file transfer, etc.).

### 3. Load and Deploy

Follow the [K3s + ESS Quickstart Guide](../../examples/k3s-ess-quickstart.md) for deployment instructions.

## Workflow Customization

### Adding New Products

To add a new product to the build:

1. Edit `.github/workflows/airgap-release.yaml`
2. Add to the appropriate matrix (core or rancher products):
   ```yaml
   - name: myproduct
     script: hauler/scripts/myproduct/hauler-myproduct.sh
     manifest: hauler/myproduct/rancher-airgap-myproduct.yaml
     version_var: vMyProduct
   ```

### Modifying OS Dependencies

Edit the `build-os-dependencies` job matrix to add or remove packages:

```yaml
- name: linux
  packages: iptables container-selinux ... new-package
```

## Troubleshooting

### Build Failures

1. Check the Actions tab for detailed logs
2. Verify that version variables are correctly set in scripts
3. Ensure manifest files exist and are valid

### R2 Upload Failures

1. Verify R2 secrets are correctly configured
2. Check that the R2 bucket exists and is accessible
3. Verify endpoint URL format (should include protocol)

### Download Failures

If hauler fails to download images or files:
1. Check internet connectivity
2. Verify upstream sources are accessible
3. Review manifest files for correct URLs

## Build Time Estimates

| Job | Approx. Duration |
|-----|------------------|
| Core Products (per product/arch) | 5-15 minutes |
| Rancher Products (per product/arch) | 10-30 minutes |
| OS Dependencies | 5-10 minutes |
| Release Creation | 2-5 minutes |

**Total workflow time**: 1-3 hours (depending on parallelism and artifact sizes)

## Cost Considerations

- **GitHub Actions**: Uses standard GitHub Actions minutes
- **Artifact Storage**: 7-day retention for intermediate artifacts
- **Cloudflare R2**: Storage and transfer costs apply if enabled
- **Bandwidth**: Large downloads from GitHub/Docker Hub registries

## Support

For issues or questions:
- Open an issue in the repository
- Refer to the main [README](../../README.md)
- Check the [K3s + ESS Quickstart Guide](../../examples/k3s-ess-quickstart.md)
