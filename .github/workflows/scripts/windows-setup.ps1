<#
.SYNOPSIS
  Helper to run Rancher Desktop installer on Windows and optionally configure basic air-gap settings.

DESCRIPTION
  This script looks in the package's hauler/windows folder for an installer (.exe or .msi),
  runs it (optionally silently), and attempts to locate Rancher Desktop settings.json to add
  a local insecure registry entry (http://localhost:5002) if the file is found.

  This is a helper for interactive use on Windows. Use with care and review the changes
  before applying to production machines.
#>

param(
    [switch]$InstallSilently
)

Write-Host "Rancher Desktop Windows setup helper"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pkgPath = Join-Path $scriptRoot 'hauler\windows'
if (-Not (Test-Path $pkgPath)) {
    Write-Host "No hauler/windows directory found in package. Place installer(s) there and re-run." -ForegroundColor Yellow
    exit 1
}

$installer = Get-ChildItem -Path $pkgPath -Include *.exe,*.msi -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-Not $installer) {
    Write-Host "No installer found in $pkgPath" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found installer: $($installer.Name)"
if ($InstallSilently) {
    Write-Host "Running installer silently (best-effort)"
    if ($installer.Extension -ieq '.msi') {
        Start-Process msiexec -ArgumentList "/i `"$($installer.FullName)`" /qn /norestart" -Wait -NoNewWindow
    } else {
        # Silent params vary; try common /S flag
        Start-Process -FilePath $installer.FullName -ArgumentList '/S' -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Please run the installer interactively: $($installer.FullName)"
}

Write-Host "Looking for Rancher Desktop settings.json to add an insecure registry (http://localhost:5002)"

$candidates = @()
$candidates += Get-ChildItem -Path $env:APPDATA -Recurse -Filter settings.json -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'rancher|Rancher|Rancher Desktop' }
$candidates += Get-ChildItem -Path $env:LOCALAPPDATA -Recurse -Filter settings.json -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'rancher|Rancher|Rancher Desktop' }

if ($candidates.Count -eq 0) {
    Write-Host "No settings.json found. Please open Rancher Desktop and configure the registry mirror to point to http://localhost:5002" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $candidates) {
    Write-Host "Found settings: $($file.FullName)"
    try {
        $json = Get-Content $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "Failed to parse JSON at $($file.FullName) - skipping" -ForegroundColor Yellow
        continue
    }

    if (-not $json.insecureRegistries) { $json | Add-Member -MemberType NoteProperty -Name insecureRegistries -Value @() }
    if ($json.insecureRegistries -notcontains 'http://localhost:5002') {
        $json.insecureRegistries += 'http://localhost:5002'
        $backup = "$($file.FullName).bak"
        Copy-Item -Path $file.FullName -Destination $backup -Force
        $json | ConvertTo-Json -Depth 10 | Out-File -FilePath $file.FullName -Encoding UTF8
        Write-Host "Added http://localhost:5002 to insecureRegistries in $($file.FullName) (backup saved to $backup)" -ForegroundColor Green
    } else {
        Write-Host "http://localhost:5002 already present in insecureRegistries for $($file.FullName)"
    }
}

Write-Host "Done. Restart Rancher Desktop for settings to take effect."
