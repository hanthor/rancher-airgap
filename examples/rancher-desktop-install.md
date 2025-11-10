# Rancher Desktop Installation for Windows and macOS

This guide provides automated installation methods for Rancher Desktop on Windows and macOS platforms. Rancher Desktop provides a K3s Kubernetes environment with container runtime support (nerdctl/docker).

## Overview

**Rancher Desktop** is an open-source desktop application that brings Kubernetes and container management to your local machine. For airgapped K3s + ESS deployments, Rancher Desktop can be used on Windows and macOS instead of running K3s natively.

**Official Project**: https://github.com/rancher-sandbox/rancher-desktop

## Installation Methods

### Windows

#### Method 1: MSI Installer (Recommended)

Download the MSI installer from the [Rancher Desktop releases page](https://github.com/rancher-sandbox/rancher-desktop/releases) and install:

**Silent Install (Per-User)**:
```powershell
# Download latest release
$version = "1.16.0"  # Update to desired version
$url = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${version}/Rancher.Desktop.Setup.${version}.msi"
$installer = "$env:TEMP\RancherDesktop.msi"

Invoke-WebRequest -Uri $url -OutFile $installer

# Install silently for current user
msiexec /i $installer /quiet MSIINSTALLPERUSER=1
```

**Silent Install (All Users - Requires Admin)**:
```powershell
# Run as Administrator
msiexec /i $installer /quiet MSIINSTALLPERUSER=0
```

**Silent Install with Auto-Start**:
```powershell
msiexec /i $installer /passive MSIINSTALLPERUSER=1 RDRUNAFTERINSTALL=1
```

#### Method 2: ZIP Archive

For portable installations without requiring installer:

```powershell
$version = "1.16.0"
$url = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${version}/Rancher.Desktop-${version}-win.zip"
$zipFile = "$env:TEMP\RancherDesktop.zip"
$installDir = "$env:LOCALAPPDATA\Programs\Rancher Desktop"

# Download and extract
Invoke-WebRequest -Uri $url -OutFile $zipFile
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force

# Create desktop shortcut (optional)
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Rancher Desktop.lnk")
$Shortcut.TargetPath = "$installDir\Rancher Desktop.exe"
$Shortcut.Save()
```

#### Method 3: Automated Script (Development Setup)

Rancher Desktop provides a development setup script that can be adapted:

```powershell
# Download and run the automated setup
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb 'https://github.com/rancher-sandbox/rancher-desktop/raw/main/scripts/windows-setup.ps1' | iex
```

**Note**: This script is primarily for development environments and includes additional tools.

### macOS

#### Method 1: DMG Installer (Recommended)

Download and install via DMG:

```bash
#!/bin/bash
VERSION="1.16.0"  # Update to desired version

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DMG_FILE="Rancher.Desktop-${VERSION}.aarch64.dmg"
else
    DMG_FILE="Rancher.Desktop-${VERSION}.x86_64.dmg"
fi

# Download DMG
curl -L "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${VERSION}/${DMG_FILE}" \
     -o "/tmp/RancherDesktop.dmg"

# Mount DMG
hdiutil attach /tmp/RancherDesktop.dmg

# Copy to Applications
cp -R "/Volumes/Rancher Desktop/Rancher Desktop.app" /Applications/

# Unmount DMG
hdiutil detach "/Volumes/Rancher Desktop"

# Clean up
rm /tmp/RancherDesktop.dmg
```

#### Method 2: Homebrew Cask

```bash
# Install via Homebrew
brew install --cask rancher

# Or specify version
brew install --cask rancher@1.16.0
```

#### Method 3: ZIP Archive

```bash
VERSION="1.16.0"
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ]; then
    ZIP_FILE="Rancher.Desktop-${VERSION}-mac.aarch64.zip"
else
    ZIP_FILE="Rancher.Desktop-${VERSION}-mac.x86_64.zip"
fi

# Download and extract
curl -L "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${VERSION}/${ZIP_FILE}" \
     -o /tmp/RancherDesktop.zip

unzip /tmp/RancherDesktop.zip -d /Applications/
rm /tmp/RancherDesktop.zip
```

## Post-Installation Configuration

### First Run Setup (All Platforms)

On first launch, Rancher Desktop will:
1. Present a welcome screen with initial configuration options
2. Download necessary components (K3s, container runtime)
3. Initialize the Kubernetes cluster

### Automated Configuration (rdctl)

Rancher Desktop includes `rdctl` CLI for automation:

**Windows**:
```powershell
# Configure Rancher Desktop settings
& "$env:LOCALAPPDATA\Programs\Rancher Desktop\resources\resources\win32\bin\rdctl.exe" set --kubernetes.enabled=true

# Or if installed system-wide
& "$env:ProgramFiles\Rancher Desktop\resources\resources\win32\bin\rdctl.exe" set --kubernetes.enabled=true
```

**macOS**:
```bash
# Configure Rancher Desktop settings
/Applications/Rancher\ Desktop.app/Contents/Resources/resources/darwin/bin/rdctl set --kubernetes.enabled=true

# Example: Disable auto-start
rdctl set --application.auto-start=false

# Example: Set memory allocation
rdctl set --virtual-machine.memory-in-gb=4

# Example: Set CPU count
rdctl set --virtual-machine.number-cpus=2
```

### Common rdctl Commands

```bash
# Start Rancher Desktop
rdctl start

# Shutdown Rancher Desktop
rdctl shutdown

# Get current settings
rdctl list-settings

# Set Kubernetes version
rdctl set --kubernetes.version=v1.30.0+k3s1

# Enable/disable Kubernetes
rdctl set --kubernetes.enabled=true

# Set container runtime (moby or containerd)
rdctl set --container-engine.name=containerd

# Factory reset
rdctl factory-reset
```

## Configuration File Locations

### Windows
- **Settings**: `%APPDATA%\rancher-desktop\settings.json`
- **Logs**: `%LOCALAPPDATA%\rancher-desktop\logs`
- **Data**: `%LOCALAPPDATA%\rancher-desktop`

### macOS
- **Settings**: `~/Library/Application Support/rancher-desktop/settings.json`
- **Logs**: `~/Library/Logs/rancher-desktop`
- **Data**: `~/Library/Application Support/rancher-desktop`

## Example: Automated Silent Install Script

### Windows (PowerShell)

```powershell
# install-rancher-desktop.ps1
param(
    [string]$Version = "1.16.0",
    [switch]$AllUsers = $false,
    [switch]$AutoStart = $false
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Rancher Desktop v$Version..."

# Download installer
$url = "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${Version}/Rancher.Desktop.Setup.${Version}.msi"
$installer = "$env:TEMP\RancherDesktop-${Version}.msi"

Write-Host "Downloading from $url..."
Invoke-WebRequest -Uri $url -OutFile $installer

# Build msiexec arguments
$msiArgs = @(
    "/i", $installer,
    "/quiet"
)

if ($AllUsers) {
    $msiArgs += "MSIINSTALLPERUSER=0"
} else {
    $msiArgs += "MSIINSTALLPERUSER=1"
}

if ($AutoStart) {
    $msiArgs += "RDRUNAFTERINSTALL=1"
}

# Install
Write-Host "Installing Rancher Desktop..."
Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow

# Clean up
Remove-Item $installer

Write-Host "Rancher Desktop v$Version installed successfully!"

# Wait for installation to complete
Start-Sleep -Seconds 5

# Start Rancher Desktop if AutoStart is set
if ($AutoStart) {
    if ($AllUsers) {
        & "$env:ProgramFiles\Rancher Desktop\Rancher Desktop.exe"
    } else {
        & "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe"
    }
}
```

### macOS (Bash)

```bash
#!/bin/bash
# install-rancher-desktop.sh

set -e

VERSION="${1:-1.16.0}"
AUTO_START="${2:-false}"

echo "Installing Rancher Desktop v${VERSION}..."

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DMG_FILE="Rancher.Desktop-${VERSION}.aarch64.dmg"
else
    DMG_FILE="Rancher.Desktop-${VERSION}.x86_64.dmg"
fi

# Download DMG
echo "Downloading ${DMG_FILE}..."
curl -L "https://github.com/rancher-sandbox/rancher-desktop/releases/download/v${VERSION}/${DMG_FILE}" \
     -o "/tmp/RancherDesktop.dmg"

# Mount DMG
echo "Mounting DMG..."
hdiutil attach /tmp/RancherDesktop.dmg -nobrowse -quiet

# Copy to Applications
echo "Installing to /Applications..."
rm -rf "/Applications/Rancher Desktop.app"
cp -R "/Volumes/Rancher Desktop/Rancher Desktop.app" /Applications/

# Unmount DMG
echo "Cleaning up..."
hdiutil detach "/Volumes/Rancher Desktop" -quiet

# Clean up
rm /tmp/RancherDesktop.dmg

echo "Rancher Desktop v${VERSION} installed successfully!"

# Start Rancher Desktop if requested
if [ "$AUTO_START" = "true" ]; then
    echo "Starting Rancher Desktop..."
    open -a "Rancher Desktop"
fi
```

## Using with K3s + ESS Airgap Deployment

Once Rancher Desktop is installed:

1. **Start Rancher Desktop** to initialize the K3s cluster
2. **Access kubectl**:
   - Windows: `rdctl shell kubectl get nodes`
   - macOS: `rdctl shell kubectl get nodes`
3. **Access nerdctl/docker**:
   - Windows: `rdctl shell nerdctl ps`
   - macOS: `rdctl shell nerdctl ps`
4. **Deploy ESS using Helm** following the `k3s-ess-quickstart.md` guide

### Loading Images from Hauler

```bash
# Export images from Hauler
hauler store save --store ess-store --filename ess-images.tar.zst

# Extract and load into Rancher Desktop
tar -xzf ess-images.tar.zst
rdctl shell nerdctl load -i <image-tar-file>
```

## Troubleshooting

### Windows

**Issue**: Installation fails with permission errors
- **Solution**: Run PowerShell as Administrator for system-wide install

**Issue**: WSL2 not enabled
- **Solution**: Enable WSL2 before installing Rancher Desktop:
  ```powershell
  wsl --install
  wsl --set-default-version 2
  ```

### macOS

**Issue**: "Rancher Desktop.app" is damaged
- **Solution**: Remove quarantine attribute:
  ```bash
  xattr -dr com.apple.quarantine "/Applications/Rancher Desktop.app"
  ```

**Issue**: Insufficient permissions
- **Solution**: Ensure your user has admin rights or run with sudo

## References

- **Official Documentation**: https://docs.rancherdesktop.io/
- **GitHub Repository**: https://github.com/rancher-sandbox/rancher-desktop
- **Release Downloads**: https://github.com/rancher-sandbox/rancher-desktop/releases
- **rdctl Documentation**: https://docs.rancherdesktop.io/references/rdctl-command-reference
- **Settings Reference**: https://docs.rancherdesktop.io/references/settings-reference
