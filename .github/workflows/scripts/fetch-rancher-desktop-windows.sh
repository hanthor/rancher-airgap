#!/usr/bin/env bash
# Fetch the latest Rancher Desktop Windows installer and place it under hauler/windows/
# Usage: ./fetch-rancher-desktop-windows.sh [--token <GITHUB_TOKEN>] [--tag <release-tag>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../../.."
TARGET_DIR="$REPO_ROOT/hauler/windows"

GITHUB_TOKEN=""
TAG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --token) GITHUB_TOKEN="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--token <GITHUB_TOKEN>] [--tag <release-tag>]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$TARGET_DIR"

API_URL="https://api.github.com/repos/rancher-sandbox/rancher-desktop/releases"
if [ -n "$TAG" ]; then
  API_URL="$API_URL/tags/$TAG"
else
  API_URL="$API_URL/latest"
fi

echo "Fetching release metadata from $API_URL"
if [ -n "$GITHUB_TOKEN" ]; then
  auth=(-H "Authorization: token $GITHUB_TOKEN")
else
  auth=()
fi

json=$(curl -sSfL "${auth[@]}" "$API_URL")

asset_url=$(echo "$json" | jq -r '.assets[] | select(.name|test("(?i)windows|win.*exe|msi")) | .browser_download_url' | head -n1)

if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
  echo "No Windows installer asset found in release metadata"
  exit 2
fi

echo "Found Windows asset: $asset_url"
fname=$(basename "$asset_url")
out="$TARGET_DIR/$fname"

echo "Downloading to $out"
if [ -n "$GITHUB_TOKEN" ]; then
  curl -L -H "Authorization: token $GITHUB_TOKEN" -o "$out" "$asset_url"
else
  curl -L -o "$out" "$asset_url"
fi

echo "Downloaded Rancher Desktop installer to: $out"
echo "You can now run the packager to include this file in the Airgap package."
