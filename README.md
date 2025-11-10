# K3s + Element Server Suite (ESS) Airgap Guide

### Welcome to the K3s + ESS Airgap Deployment Guide

This repository provides a framework and guide for deploying **K3s and Element Server Suite (ESS)** in disconnected or airgapped environments with **cross-platform support** for Linux (AMD64/ARM64), Windows (WSL2), and macOS (ARM64).

We utilize [Hauler](https://github.com/hauler-dev/hauler) by [Rancher Government](https://github.com/rancherfederal) to collect, package, and distribute assets. Hauler simplifies the airgap process by representing assets as content and collections, allowing users to easily fetch, store, package, and distribute with declarative manifests or the command line.

**Review the comprehensive *[K3s + ESS Quickstart Guide](examples/k3s-ess-quickstart.md)*!**

**High Level Workflow:**

```bash
Collection -> Across the Airgap -> Distribution
```

**Detailed Workflow:**

```bash
fetch -> validate -> save -> | <airgap> | -> load -> validate -> distribute
```

## Why K3s + ESS?

- **K3s**: Lightweight, certified Kubernetes distribution perfect for edge and airgap scenarios
- **ESS**: Complete Matrix communication stack (Synapse, Element Web, Element Admin, MAS, Matrix RTC)
- **Cross-Platform**: Support for Linux, Windows (WSL2), and macOS (Docker Desktop/Rancher Desktop)
- **Airgap-First**: Designed for disconnected environments with offline installation support

## Platform Support

| Platform | Architecture | Support Level | Notes |
|----------|--------------|---------------|-------|
| Linux | AMD64 | ✅ Full | Native K3s with systemd |
| Linux | ARM64 | ✅ Full | Native K3s with systemd |
| Windows 10/11 | AMD64 | ✅ Via WSL2 | K3s runs in WSL2 Linux |
| macOS | ARM64 (M1/M2/M3) | ✅ Via Docker/Rancher Desktop | K3s runs in container runtime |

## Repository Structure

### Core Components

- [hauler/k3s](hauler/k3s/README.md) - provides the content manifest for K3s (Lightweight Kubernetes)
  - currently supports: `K3S: v1.33.5`
  - platforms: `linux/amd64`, `linux/arm64` (Windows/macOS use Linux binaries via WSL2/containers)
- [hauler/ess-helm](hauler/ess-helm/README.md) - provides the content manifest for Element Server Suite
  - currently supports: `ESS Helm Chart: v25.11.0`
  - includes: Synapse, Element Web, Element Admin, MAS, Matrix RTC, PostgreSQL, HAProxy

### Featured Addons

- [hauler/helm](hauler/helm/README.md) - provides the content manifest for Helm
  - currently supports: `Helm: v3.19.0`

### Legacy Rancher Components

The following components are from the original Rancher Airgap project and are maintained for reference:

- [hauler/rke2](hauler/rke2/README.md) - Rancher Kubernetes (RKE2) - `RKE2: v1.33.5`
- [hauler/rancher](hauler/rancher/README.md) - Rancher Multi-Cluster Manager - `Rancher: v2.12.2`
- [hauler/longhorn](hauler/longhorn/README.md) - Rancher Longhorn - `Longhorn: v1.9.2`
- [hauler/neuvector](hauler/neuvector/README.md) - Rancher NeuVector - `NeuVector: v5.4.6`
- [hauler/harvester](hauler/harvester/README.md) - Rancher Harvester - `Harvester: v1.6.1`
- [hauler/gitea](hauler/gitea/README.md) - Gitea - `Gitea: v1.24.6`
- [hauler/vault](hauler/vault/README.md) - Vault - `Vault: v1.20.4`
- [hauler/kubevip](hauler/kubevip/README.md) - KubeVip - `KubeVip: v0.5.11`
- [hauler/kubewarden](hauler/kubewarden/README.md) - KubeWarden - `KubeWarden: v1.29.0`
- [hauler/cosign](hauler/cosign/README.md) - Cosign - `Cosign: v2.6.1`
- [hauler/hauler](hauler/hauler/README.md) - Hauler - `Hauler: v1.3.0`

**Note:** This repository has been repurposed to focus on K3s + ESS deployments for airgapped Matrix communication infrastructure. The Rancher components are preserved for users who may need them.

## Hauler Installation

```bash
# https://github.com/hauler-dev/hauler
curl -sfL https://get.hauler.dev | bash

# date = $(date +"%m%d%Y")
```
