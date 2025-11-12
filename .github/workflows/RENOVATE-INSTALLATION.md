# Renovate Bot Installation Guide

This guide explains how to enable the Renovate bot on this GitHub repository after merging this PR.

## Prerequisites

This PR must be merged to main before enabling Renovate.

## Installation Options

### Option 1: GitHub App (Recommended)

1. Visit the [Renovate GitHub App page](https://github.com/apps/renovate)
2. Click **Install** or **Configure**
3. Select your organization/account
4. Choose repository access:
   - Select **Only select repositories**
   - Choose `hanthor/rancher-airgap`
5. Click **Install** or **Save**

Renovate will automatically detect the `renovate.json` configuration and start running on the schedule defined (every weekend).

### Option 2: Self-Hosted Renovate

If you prefer to run Renovate as a self-hosted solution:

1. Fork the [renovate repository](https://github.com/renovatebot/renovate)
2. Set up as a GitHub Action or scheduled job
3. Configure environment variables for authentication
4. Point to this repository in your configuration

See [Renovate Self-Hosting Documentation](https://docs.renovatebot.com/getting-started/running/) for details.

## Verification

After installation, verify Renovate is working:

### Check for Onboarding PR

Renovate should create an **onboarding PR** within a few minutes:

```bash
gh pr list --label renovate
```

The onboarding PR will:
- Show you what Renovate detected
- Preview initial configuration
- Allow you to validate before enabling

Merge the onboarding PR to activate Renovate.

### Check Dashboard Issue

Renovate creates a **Dependency Dashboard** issue:

```bash
gh issue list --label renovate
```

This issue shows:
- Pending updates
- Configuration errors (if any)
- Update schedule status

### Manual Trigger (Testing)

To test immediately without waiting for the schedule:

1. Go to **Settings** → **Webhooks** in your repository
2. Find the Renovate webhook
3. Click **Redeliver** on a recent delivery

Or trigger via the Renovate dashboard:

1. Visit the Dependency Dashboard issue
2. Check the box next to any dependency
3. Renovate will create a PR immediately

## Expected Behavior

Once enabled, Renovate will:

1. **Scan weekly** (every weekend) for new versions
2. **Create PRs** for version updates with labels:
   - `dependencies` - All updates
   - `ess-helm` - ESS Helm Chart (triggers automation)
   - `k3s` - K3s updates
   - `helm` - Helm updates
   - `hauler` - Hauler updates

3. **For ESS updates**, the `update-ess-images` workflow will automatically:
   - Deploy the new ESS version to K3d
   - Extract actual image tags
   - Update the hauler manifest
   - Commit changes to the PR
   - Add a comment with version details

## Configuration

The Renovate configuration is in `renovate.json` at the repository root.

Key settings:
- **Schedule**: Every weekend
- **Labels**: Automatic labeling by component
- **Auto-merge**: Disabled (requires manual review)
- **PR limits**: Max 5 concurrent, 10 per hour

## Troubleshooting

### No onboarding PR appears

- Check repository access in the [Renovate app settings](https://github.com/apps/renovate)
- Verify `renovate.json` is valid: `npx -p renovate renovate-config-validator`
- Check Renovate logs in the app configuration

### PRs not triggering ESS automation

Verify:
1. PR has the `ess-helm` label
2. PR user is from Renovate (username contains "renovate")
3. Workflow file exists: `.github/workflows/update-ess-images.yaml`
4. Workflow permissions are enabled in repository settings

### Workflow fails during image extraction

Check the workflow run logs:
```bash
gh run list --workflow=update-ess-images.yaml
gh run view <run-id>
```

Common issues:
- K3d cluster creation failed
- Hauler registry not started
- ESS deployment timeout (increase timeout in workflow)

## Manual Testing

Test the ESS automation workflow manually:

```bash
# Trigger for current version
gh workflow run update-ess-images.yaml -f ess_chart_version=25.11.0

# Watch the run
gh run watch

# View logs
gh run view --log
```

## Disabling Renovate

To temporarily disable:

1. Add `"enabled": false` to `renovate.json`
2. Commit and push

To permanently remove:
1. Uninstall the Renovate GitHub App
2. Delete the `renovate.json` file (optional)

## Support

- [Renovate Documentation](https://docs.renovatebot.com/)
- [GitHub Community](https://github.com/renovatebot/renovate/discussions)
- [Project RENOVATE.md](.github/workflows/RENOVATE.md) - Local documentation

## Next Steps

After enabling Renovate:

1. ✅ Merge the onboarding PR
2. ✅ Review the Dependency Dashboard issue
3. ✅ Wait for first update PRs (or trigger manually)
4. ✅ Test the ESS automation on the first ess-helm PR
5. ✅ Review and merge update PRs as they arrive
