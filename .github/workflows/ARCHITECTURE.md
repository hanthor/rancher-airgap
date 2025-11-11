# Workflow Architecture

This document provides a visual overview of the Airgap Release workflow architecture.

## Workflow Trigger Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      Workflow Triggers                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Tag Push (Automatic)         2. Manual Dispatch         │
│     git tag v1.0.0               Actions → Run workflow     │
│     git push origin v1.0.0       ├─ Choose branch           │
│                                  └─ Enable/disable R2       │
│                                                              │
└────────────────┬─────────────────────────────┬──────────────┘
                 │                             │
                 └─────────────┬───────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  Workflow Start  │
                    └──────────────────┘
```

## Job Execution Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Parallel Build Phase                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────┐  ┌──────────────────────────────────────┐   │
│  │  Core Products       │  │  OS Deps                             │   │
│  ├──────────────────────┤  ├──────────────────────────────────────┤   │
│  │                      │  │                                      │   │
│  │  K3s                 │  │  Linux                               │   │
│  │   ├─ amd64          │  │  Windows                             │   │
│  │   └─ arm64          │  │  macOS                               │   │
│  │                      │  │                                      │   │
│  │  ESS-Helm            │  └──────────────────────────────────────┘   │
│  │   ├─ amd64          │                                              │
│  │   └─ arm64          │                                              │
│  │                      │                                              │
│  │  Helm                │                                              │
│  │   ├─ amd64          │                                              │
│  │   └─ arm64          │                                              │
│  │                      │                                              │
│  └──────────────────────┘                                              │
│                                                                         │
│  Matrix Strategy:         For each OS:                                 │
│  - 3 products             - Download packages                          │
│  - 2 architectures        - Create tarball                             │
│  = 6 parallel jobs        = 3 parallel jobs                            │
│                                                                         │
└───────────────┬────────────────────────────┬──────────────────────────┘
                │                            │
                ▼                            ▼
        ┌──────────┐                 ┌──────────┐
        │ Artifact │                 │ Artifact │
        │ Upload   │                 │ Upload   │
        └──────────┘                 └──────────┘
                │                            │
                └────────────┬───────────────┘
                             │
                                 ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Distribution Phase                               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────┐    ┌──────────────────────────────┐  │
│  │  GitHub Release             │    │  Cloudflare R2 (Optional)    │  │
│  │  (if tag push)              │    │  (if enabled)                │  │
│  ├─────────────────────────────┤    ├──────────────────────────────┤  │
│  │                             │    │                              │  │
│  │  1. Download all artifacts  │    │  1. Download all artifacts   │  │
│  │  2. Generate release notes  │    │  2. Configure AWS CLI        │  │
│  │  3. Create release          │    │  3. Upload to R2 bucket      │  │
│  │  4. Upload all files        │    │                              │  │
│  │                             │    │  Path: bucket/tag/files      │  │
│  │  Permanent storage          │    │  No egress fees!             │  │
│  │                             │    │                              │  │
│  └─────────────────────────────┘    └──────────────────────────────┘  │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

## Artifact Structure

```
Release v1.0.0
├── Core Products (linux/amd64)
│   ├── k3s-1.33.5-amd64.tar.zst
│   ├── ess-helm-25.11.0-amd64.tar.zst
│   └── helm-3.19.0-amd64.tar.zst
│
├── Core Products (linux/arm64)
│   ├── k3s-1.33.5-arm64.tar.zst
│   ├── ess-helm-25.11.0-arm64.tar.zst
│   └── helm-3.19.0-arm64.tar.zst
│
└── OS Dependencies
    ├── linux-dependencies-v1.0.0.tar.gz
    ├── windows-wsl2-dependencies-v1.0.0.tar.gz
    └── macos-dependencies-v1.0.0.tar.gz
```

## Build Process Detail

### For Each Product

```
┌──────────────────────────────────────────────────────────┐
│  Product Build Steps (e.g., K3s amd64)                  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  1. Checkout Repository                                 │
│     └─ Get latest code and manifests                    │
│                                                          │
│  2. Install Hauler                                       │
│     └─ curl -sfL https://get.hauler.dev | bash          │
│                                                          │
│  3. Extract Version                                      │
│     └─ Parse version from script (e.g., vK3S=1.33.5)    │
│                                                          │
│  4. Build Hauler Store                                   │
│     ├─ hauler store sync                                │
│     │   --store linux-amd64-store                       │
│     │   --platform linux/amd64                          │
│     │   --filename rancher-airgap-k3s.yaml              │
│     │                                                    │
│     └─ Downloads:                                        │
│         ├─ Container images                             │
│         ├─ Binary files                                 │
│         └─ Installation scripts                         │
│                                                          │
│  5. Save Hauler Store                                    │
│     ├─ hauler store save                                │
│     │   --store linux-amd64-store                       │
│     │   --filename k3s-1.33.5-amd64.tar.zst             │
│     │                                                    │
│     └─ Creates compressed archive                       │
│                                                          │
│  6. Upload Artifact                                      │
│     └─ Store for 7 days OR include in release           │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Security Model

```
┌────────────────────────────────────────────────────────┐
│  Job Permissions (Least Privilege)                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│  build-core-products:                                 │
│    permissions:                                        │
│      contents: read    ← Can read repo files          │
│                                                        │
│  build-os-dependencies:                               │
│    permissions:                                        │
│      contents: read    ← Can read repo files          │
│                                                        │
│  create-release:                                       │
│    permissions:                                        │
│      contents: write   ← Can create releases          │
│                                                        │
│  upload-to-r2:                                         │
│    permissions:                                        │
│      contents: read    ← Can read repo files          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## Storage Locations

```
┌──────────────────────────────────────────────────────────┐
│  Where Artifacts Are Stored                              │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  During Build:                                           │
│  ├─ GitHub Actions Artifacts                            │
│  │   └─ Retention: 7 days                               │
│  │                                                       │
│  └─ Local runner storage (temporary)                    │
│                                                          │
│  After Release:                                          │
│  ├─ GitHub Releases                                      │
│  │   ├─ Permanent storage                               │
│  │   ├─ Public download                                 │
│  │   └─ Bandwidth: GitHub's network                     │
│  │                                                       │
│  └─ Cloudflare R2 (optional)                            │
│      ├─ Permanent storage                               │
│      ├─ Public/private access                           │
│      ├─ No egress fees                                  │
│      └─ Path: bucket/v1.0.0/filename                    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Performance Characteristics

```
┌───────────────────────────────────────────────────────────┐
│  Expected Build Times                                     │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  Core Products:        5-15 min per product/arch         │
│  OS Dependencies:      5-10 min per OS                   │
│  Release Creation:     2-5 min                           │
│  R2 Upload:            5-15 min                          │
│                                                           │
│  Total (parallel):     15-30 min                         │
│  Total (sequential):   30-60 min                         │
│                                                           │
│  Parallelization:                                         │
│  ├─ Core: 6 parallel jobs (3 products × 2 arch)         │
│  └─ OS: 3 parallel jobs                                  │
│                                                           │
│  Total parallel jobs: 9                                  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## Cost Analysis

```
┌──────────────────────────────────────────────────────────┐
│  GitHub Actions Minutes (Public Repo)                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Per Release:                                            │
│  ├─ Compute: ~45-90 min                                 │
│  ├─ Cost: FREE (public repo)                            │
│  └─ Private repo: ~$0.50-1.00                           │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  Cloudflare R2 (Optional)                                │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Per Release (~8 GB):                                    │
│  ├─ Storage: $0.015/GB/month = $0.12/month              │
│  ├─ Upload: Class A ops = $0.00004                      │
│  ├─ Download: $0 (no egress fees!)                      │
│  └─ Total: ~$0.12/month                                 │
│                                                          │
│  100 downloads/month:                                    │
│  ├─ GitHub: $0 egress                                   │
│  ├─ R2: $0 egress                                       │
│  └─ AWS S3: ~$72 egress (for comparison)               │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Extension Points

To customize the workflow:

1. **Add Products**: Edit matrix in workflow YAML
2. **Change OS Deps**: Modify packages list in matrix
3. **Add Storage**: Implement new upload job
4. **Change Triggers**: Modify `on:` section
5. **Adjust Retention**: Change artifact retention-days

## Related Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Workflow Documentation](README.md)
- [Secrets Configuration](SECRETS.md)
- [Main README](../../README.md)
