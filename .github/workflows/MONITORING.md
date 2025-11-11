# Monitoring and Badges for Airgap Testing

## GitHub Actions Status Badge

Add this badge to your README to show the status of airgap testing:

```markdown
[![Airgap Test](https://github.com/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml/badge.svg)](https://github.com/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml)
```

Result:
[![Airgap Test](https://github.com/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml/badge.svg)](https://github.com/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml)

## Monitoring Workflow Runs

### Via GitHub UI

1. Navigate to the **Actions** tab in your repository
2. Click on **Test Airgap K3s/ESS Deployment** workflow
3. View recent runs and their status

### Via GitHub CLI

```bash
# List recent workflow runs
gh run list --workflow=test-airgap.yaml --limit 10

# View details of specific run
gh run view <run-id>

# Watch a running workflow
gh run watch

# Download artifacts from a run
gh run download <run-id>
```

### Via API

```bash
# Get workflow runs
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml/runs

# Get specific run
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/hanthor/rancher-airgap/actions/runs/<run-id>
```

## Automated Notifications

### Email Notifications

GitHub automatically sends email notifications for workflow failures if you're watching the repository.

**Configure notifications:**
1. Go to repository → **Watch** → **Custom**
2. Check **Actions** under **Participating and @mentions**

### Slack Integration

Use GitHub Actions Slack integration:

```yaml
# Add to workflow
- name: Notify Slack on Failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "❌ Airgap test failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Microsoft Teams Integration

```yaml
- name: Notify Teams on Failure
  if: failure()
  uses: aliencube/microsoft-teams-actions@v0.8.0
  with:
    webhook_uri: ${{ secrets.TEAMS_WEBHOOK_URL }}
    title: Airgap Test Failed
    summary: Test workflow detected issues
    text: View run at ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

## Metrics and Reporting

### Workflow Duration Tracking

Track how long tests take over time:

```bash
# Get last 10 run durations
gh run list --workflow=test-airgap.yaml --limit 10 --json name,conclusion,createdAt,updatedAt | \
  jq -r '.[] | "\(.name): \(.conclusion) - Duration: \((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601))s"'
```

### Success Rate Calculation

```bash
# Calculate success rate
gh run list --workflow=test-airgap.yaml --limit 50 --json conclusion | \
  jq -r '[.[] | .conclusion] | group_by(.) | map({status: .[0], count: length}) | .[]'
```

### Artifact Size Tracking

```bash
# Check artifact sizes
gh api repos/hanthor/rancher-airgap/actions/runs/<run-id>/artifacts | \
  jq -r '.artifacts[] | "\(.name): \(.size_in_bytes / 1024 / 1024 | round)MB"'
```

## Dashboard Setup

### GitHub Actions Dashboard

Create a custom dashboard using GitHub API:

```python
#!/usr/bin/env python3
import requests
import os

token = os.environ.get('GITHUB_TOKEN')
headers = {'Authorization': f'token {token}'}

# Get recent workflow runs
response = requests.get(
    'https://api.github.com/repos/hanthor/rancher-airgap/actions/workflows/test-airgap.yaml/runs',
    headers=headers
)

runs = response.json()['workflow_runs'][:10]

print("Recent Airgap Test Runs:")
print("-" * 80)
for run in runs:
    status_emoji = "✅" if run['conclusion'] == 'success' else "❌"
    print(f"{status_emoji} {run['created_at']}: {run['conclusion']} - {run['html_url']}")
```

### Grafana Dashboard (Advanced)

Export GitHub Actions metrics to Grafana:

1. Use GitHub Actions exporter: https://github.com/cpanato/github_actions_exporter
2. Configure Prometheus to scrape metrics
3. Create Grafana dashboard with:
   - Success rate over time
   - Average duration
   - Failure reasons
   - Network activity trends

## Scheduled Health Checks

Add scheduled runs to monitor airgap compliance:

```yaml
# In .github/workflows/test-airgap.yaml, add to 'on:' section
schedule:
  - cron: '0 0 * * 1'  # Weekly on Monday at midnight UTC
```

## Trend Analysis

### Track Changes Over Time

Create a script to analyze trends:

```bash
#!/bin/bash
# analyze-trends.sh

echo "Airgap Test Trends (Last 30 Days)"
echo "=================================="

# Get runs from last 30 days
runs=$(gh run list --workflow=test-airgap.yaml --limit 100 --json createdAt,conclusion,updatedAt)

# Calculate metrics
total=$(echo "$runs" | jq '. | length')
success=$(echo "$runs" | jq '[.[] | select(.conclusion == "success")] | length')
failure=$(echo "$runs" | jq '[.[] | select(.conclusion == "failure")] | length')
rate=$(echo "scale=2; $success * 100 / $total" | bc)

echo "Total runs: $total"
echo "Successful: $success"
echo "Failed: $failure"
echo "Success rate: ${rate}%"
echo ""

# Average duration
avg_duration=$(echo "$runs" | jq -r '
  [.[] | ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601))] |
  add / length
')

echo "Average duration: ${avg_duration}s"
```

## Alert Rules

### Define Alert Thresholds

```yaml
# alert-rules.yaml (conceptual)
rules:
  - name: airgap-test-failures
    condition: failure_count > 2 in 24h
    action: notify_team
    
  - name: airgap-test-duration
    condition: duration > 45 minutes
    action: investigate
    
  - name: external-connections
    condition: external_connections > 10
    action: review_manifests
```

### Implement in Workflow

```yaml
- name: Check Alert Thresholds
  if: always()
  run: |
    # Check recent failures
    RECENT_FAILURES=$(gh run list --workflow=test-airgap.yaml \
      --limit 10 --json conclusion | \
      jq '[.[] | select(.conclusion == "failure")] | length')
    
    if [ "$RECENT_FAILURES" -gt 2 ]; then
      echo "::warning::High failure rate detected: $RECENT_FAILURES failures in last 10 runs"
    fi
```

## Integration with PR Checks

### Require Passing Tests

In repository settings:

1. Go to **Settings** → **Branches**
2. Add branch protection rule for `main`
3. Check **Require status checks to pass**
4. Select **Test Airgap K3s/ESS Deployment**

Now PRs cannot merge without passing airgap tests.

### PR Comment Bot

Add workflow step to comment on PRs:

```yaml
- name: Comment on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const report = require('fs').readFileSync('/tmp/airgap-report.md', 'utf8');
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Airgap Test Results\n\n${report}`
      });
```

## Best Practices

1. **Monitor regularly**: Check workflow status at least weekly
2. **Set up notifications**: Don't rely on manual checks
3. **Track metrics**: Understand trends over time
4. **Document failures**: Add context to failed runs
5. **Automate responses**: Use webhooks for critical failures
6. **Review artifacts**: Download and analyze test reports
7. **Update thresholds**: Adjust alert rules as needed

## Troubleshooting Dashboard Access

If you don't see workflows or runs:

1. Ensure you have repository access
2. Check if workflows are enabled: **Settings** → **Actions** → **General**
3. Verify branch protection rules don't block workflow runs
4. Check GitHub Actions usage limits (free tier has quotas)

## Cost Monitoring

Track GitHub Actions minutes usage:

```bash
# View billing summary (requires admin access)
gh api /orgs/{org}/settings/billing/actions
```

For public repositories, GitHub Actions is free. For private repositories, monitor usage to stay within quota.
