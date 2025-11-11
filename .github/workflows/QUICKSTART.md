# Quick Start: Airgap Release Workflow

This guide shows how to create your first airgap release using the GitHub Actions workflow.

## Prerequisites

- Repository forked or cloned
- Push access to the repository
- Optional: Cloudflare R2 credentials (for cloud storage)

## Method 1: Create Release with Git Tag (Recommended)

This is the simplest method for creating releases.

### Step 1: Tag Your Release

```bash
# Navigate to your repository
cd rancher-airgap

# Pull latest changes
git pull origin main

# Create and push a tag
git tag v1.0.0
git push origin v1.0.0
```

### Step 2: Monitor the Workflow

1. Go to **Actions** tab in GitHub
2. Find the "Airgap Release Build" workflow
3. Click on the running workflow to see progress
4. Wait for all jobs to complete (~1-3 hours)

### Step 3: Download Your Release

Once complete, go to **Releases** and you'll find:
- `k3s-1.33.5-amd64.tar.zst`
- `k3s-1.33.5-arm64.tar.zst`
- `ess-helm-25.11.0-amd64.tar.zst`
- `ess-helm-25.11.0-arm64.tar.zst`
- `helm-3.19.0-amd64.tar.zst`
- `helm-3.19.0-arm64.tar.zst`
- `linux-dependencies-v1.0.0.tar.gz`
- `windows-wsl2-dependencies-v1.0.0.tar.gz`
- `macos-dependencies-v1.0.0.tar.gz`

## Method 2: Manual Trigger (For Testing)

Use this method to test the workflow without creating a release.

### Step 1: Trigger Workflow Manually

1. Go to **Actions** tab
2. Click **Airgap Release Build** on the left
3. Click **Run workflow** button
4. Choose options:
   - **Branch**: main
   - **Upload to Cloudflare R2**: false (unless configured)
5. Click **Run workflow**

### Step 2: Download Build Artifacts

1. Wait for workflow to complete
2. Click on the completed workflow run
3. Scroll to **Artifacts** section at the bottom
4. Download individual artifacts (retained for 7 days)

**Note**: Manual triggers do NOT create a GitHub Release, only build artifacts.

## Using Your Release in an Airgap Environment

### Step 1: Download Files

```bash
# Create download directory
mkdir -p ~/airgap-download
cd ~/airgap-download

# Download what you need (example for K3s + ESS)
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/k3s-1.33.5-amd64.tar.zst
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/ess-helm-25.11.0-amd64.tar.zst
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/helm-3.19.0-amd64.tar.zst
wget https://github.com/hanthor/rancher-airgap/releases/download/v1.0.0/linux-dependencies-v1.0.0.tar.gz
```

### Step 2: Transfer Across Airgap

Use your organization's approved method:
- Physical media (USB drive)
- Secure file transfer
- Approved network bridge

### Step 3: Load in Airgap Environment

```bash
# Install Hauler (if not already installed)
curl -sfL https://get.hauler.dev | bash

# Load the stores
hauler store load --filename k3s-1.33.5-amd64.tar.zst
hauler store load --filename ess-helm-25.11.0-amd64.tar.zst
hauler store load --filename helm-3.19.0-amd64.tar.zst

# Verify contents
hauler store info

# Serve the content
hauler store serve registry &    # OCI registry on port 5000
hauler store serve fileserver &  # HTTP server on port 8080
```

### Step 4: Deploy

Follow the [K3s + ESS Quickstart Guide](../../examples/k3s-ess-quickstart.md).

## Platform-Specific Notes

### Linux

Download the `amd64` or `arm64` version based on your architecture:
```bash
uname -m  # Shows x86_64 (amd64) or aarch64 (arm64)
```

### Windows (WSL2)

1. Download `amd64` version (WSL2 runs Linux binaries)
2. Download `windows-wsl2-dependencies-v1.0.0.tar.gz`
3. Extract and install in WSL2 environment

### macOS

1. Download `arm64` version for M1/M2/M3 Macs
2. Download `macos-dependencies-v1.0.0.tar.gz`
3. Use with Docker Desktop or Rancher Desktop

## Troubleshooting

### Workflow Failed

1. Check the Actions tab for error messages
2. Common issues:
   - Network connectivity (downloading images)
   - Disk space (large image stores)
   - Invalid manifest files

### Artifacts Not Available

- Build artifacts expire after 7 days
- Create a release tag to have permanent downloads

### Release Not Created

- Ensure you pushed a tag starting with `v`
- Check workflow permissions (needs write access)

### R2 Upload Failed

- Verify secrets are configured correctly
- Check R2 bucket exists and is accessible
- Review endpoint URL format

## Next Steps

1. ✅ Create your first release
2. ✅ Download and test in a connected environment
3. ✅ Transfer to airgap environment
4. ✅ Deploy K3s + ESS
5. 📚 Share feedback and improvements

## Additional Resources

- [Workflow Documentation](README.md) - Detailed workflow information
- [Secrets Configuration](SECRETS.md) - How to set up R2 uploads
- [K3s + ESS Quickstart](../../examples/k3s-ess-quickstart.md) - Deployment guide
- [Main README](../../README.md) - Repository overview
