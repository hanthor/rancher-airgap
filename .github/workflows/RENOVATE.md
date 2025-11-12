# Renovate Automation Documentation

## Overview

This repository uses [Renovate](https://docs.renovatebot.com/) to automatically track and update versions of key dependencies:

- **ESS Helm Chart** (Element Server Suite)
- **K3s** (Lightweight Kubernetes)
- **Helm** (Kubernetes package manager)
- **Hauler** (Airgap asset collection tool)

## How It Works

### 1. Renovate Configuration

The `renovate.json` file configures Renovate to:

- Monitor GitHub releases for k3s, helm, and hauler
- Track the ESS Helm chart from the OCI registry
- Create PRs when new versions are detected
- Apply appropriate labels to PRs for automation triggers

### 2. Version Tracking Locations

Renovate monitors and updates versions in multiple locations:

#### ESS Helm Chart
- `hauler/ess-helm/rancher-airgap-ess-helm.yaml` - Chart version in manifest
- `hauler/scripts/ess-helm/hauler-ess-helm.sh` - Version variable in generator script
- `.github/workflows/test-airgap.yaml` - ESS_CHART_VERSION environment variable

#### K3s
- `hauler/scripts/k3s/hauler-k3s.sh` - K3s version variable
- `.github/workflows/test-airgap.yaml` - K3S_VERSION environment variable

#### Helm
- `hauler/scripts/helm/hauler-helm.sh` - Helm version variable
- `.github/workflows/test-airgap.yaml` - HELM_VERSION environment variable

#### Hauler
- `.github/workflows/test-airgap.yaml` - HAULER_VERSION environment variable

### 3. ESS Image Update Automation

When Renovate creates a PR to update the ESS Helm Chart version, the `update-ess-images.yaml` workflow automatically:

1. **Detects the change**: Checks if the PR is from Renovate and has the `ess-helm` label
2. **Deploys ESS**: Spins up a K3d cluster and deploys the new ESS version
3. **Extracts images**: Captures all container image versions from the deployed chart
4. **Updates manifest**: Regenerates `hauler/ess-helm/rancher-airgap-ess-helm.yaml` with actual image versions
5. **Commits changes**: Pushes the updated manifest back to the PR
6. **Comments on PR**: Adds a summary of extracted versions

This ensures the Hauler manifest always contains the correct image versions for each ESS Helm Chart release.

## Workflow Details

### Update ESS Images Workflow

**File**: `.github/workflows/update-ess-images.yaml`

**Triggers**:
- Automatically on Renovate PRs with `ess-helm` label
- Manually via `workflow_dispatch` with a specified ESS version

**Process**:
```
1. Detect ESS version change (from Renovate PR or manual input)
2. Install tools (k3d, hauler, helm, yq)
3. Build Hauler stores (K3s, Helm, ESS)
4. Start Hauler registry servers
5. Create K3d cluster with registry mirrors
6. Deploy ESS Helm Chart (new version)
7. Extract image versions from deployed pods
8. Update hauler manifest with actual versions
9. Update generator script version
10. Commit and push changes
11. Add PR comment with version details
```

**Key Features**:
- Uses local Hauler registries for airgap-like testing
- Extracts versions from live deployments (not just values.yaml)
- Updates both the manifest and generator script
- Provides detailed PR comments with all extracted versions

### Manual Workflow Run

You can manually trigger the update workflow for any ESS version:

```bash
gh workflow run update-ess-images.yaml -f ess_chart_version=25.11.0
```

## Renovate Schedule

- Renovate runs **every weekend** to check for new versions
- PRs are created with appropriate labels and commit message prefixes
- Maximum 5 concurrent PRs, 10 PRs per hour

## Custom Managers

Renovate uses custom regex managers to track versions in:

- Shell script variable exports (`export vK3S=1.33.5`)
- YAML workflow environment variables
- Hauler manifest files

## Labels

Renovate applies these labels to PRs:

- `dependencies` - All dependency updates
- `ess-helm` - ESS Helm Chart updates (triggers automation)
- `k3s` - K3s updates
- `helm` - Helm updates
- `hauler` - Hauler updates
- `automated-update` - ESS updates that trigger the image extraction workflow

## Commit Message Format

PRs use conventional commit format:

- `chore(ess): ESS Helm Chart` - ESS updates
- `chore(k3s): K3s` - K3s updates
- `chore(helm): Helm` - Helm updates
- `chore(hauler): Hauler` - Hauler updates

## Troubleshooting

### Renovate PR doesn't trigger automation

Check:
1. PR has the `ess-helm` label
2. PR is from a user with "renovate" in the username
3. Workflow file `.github/workflows/update-ess-images.yaml` exists in the base branch

### Image extraction fails

Check:
1. K3d cluster created successfully
2. Hauler registries are running (`curl http://localhost:5001/v2/`)
3. ESS Helm chart deployed (`kubectl get pods -n ess`)
4. All pods are running before extraction

### Manifest not updated

Check:
1. Image extraction step completed successfully
2. Git configuration is correct
3. GitHub token has write permissions
4. No merge conflicts

## Testing the Automation

### Test Renovate Configuration

```bash
# Validate renovate.json syntax
npx --yes renovate-config-validator
```

### Test Image Update Workflow Locally

You can't run the full workflow locally, but you can test the image extraction logic:

```bash
# Deploy ESS to a local K3d cluster
k3d cluster create test-ess
kubectl create namespace ess
helm install ess oci://ghcr.io/element-hq/ess-helm/matrix-stack \
  --version 25.11.0 \
  --namespace ess \
  --wait

# Extract images
kubectl get pods -n ess -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

### Test Manual Workflow Trigger

```bash
# Trigger for a specific version
gh workflow run update-ess-images.yaml -f ess_chart_version=25.11.0

# Watch the workflow
gh run watch
```

## Maintenance

### Updating Renovate Configuration

1. Edit `renovate.json`
2. Validate with `npx renovate-config-validator`
3. Commit and push
4. Renovate will pick up changes on next run

### Adding New Dependencies

To track a new component:

1. Add a custom manager to `renovate.json`
2. Define the file pattern and regex matcher
3. Specify the datasource (github-releases, helm, etc.)
4. Add appropriate labels and commit message format

### Modifying the Automation

To change the ESS image update workflow:

1. Edit `.github/workflows/update-ess-images.yaml`
2. Test with manual trigger first
3. Create a PR and test on a test branch
4. Merge when validated

## Security Considerations

- Renovate PRs should be reviewed before merging
- The automation uses GitHub Actions tokens with limited scope
- Container images are verified through deployment testing
- All changes are committed with clear audit trail

## Related Documentation

- [Renovate Documentation](https://docs.renovatebot.com/)
- [ESS Helm Chart Repository](https://github.com/element-hq/ess-helm)
- [Hauler Documentation](https://github.com/hauler-dev/hauler)
- [K3s Releases](https://github.com/k3s-io/k3s/releases)
- [Helm Releases](https://github.com/helm/helm/releases)
