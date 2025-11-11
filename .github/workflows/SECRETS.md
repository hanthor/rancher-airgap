# Secrets Configuration Guide

This guide explains how to configure secrets for the Airgap Release workflow.

## GitHub Secrets

The workflow requires repository secrets for optional Cloudflare R2 uploads.

### Step-by-Step Setup

#### 1. Navigate to Repository Settings
1. Go to your repository on GitHub
2. Click **Settings** (top navigation bar)
3. In the left sidebar, click **Secrets and variables** → **Actions**

#### 2. Add R2 Secrets (Optional)

Click **New repository secret** for each of the following:

##### R2_ACCESS_KEY_ID
- **Name**: `R2_ACCESS_KEY_ID`
- **Value**: Your Cloudflare R2 Access Key ID
- **How to get it**:
  1. Log in to Cloudflare Dashboard
  2. Go to R2 → Manage R2 API Tokens
  3. Create API Token
  4. Copy the Access Key ID

##### R2_SECRET_ACCESS_KEY
- **Name**: `R2_SECRET_ACCESS_KEY`
- **Value**: Your Cloudflare R2 Secret Access Key
- **How to get it**:
  1. Same as above
  2. Copy the Secret Access Key (shown only once!)

##### R2_ENDPOINT
- **Name**: `R2_ENDPOINT`
- **Value**: Your Cloudflare R2 endpoint URL
- **Format**: `https://<account-id>.r2.cloudflarestorage.com`
- **How to get it**:
  1. Cloudflare Dashboard → R2
  2. Click on your bucket
  3. Find the S3 API endpoint

##### R2_BUCKET
- **Name**: `R2_BUCKET`
- **Value**: Your R2 bucket name (e.g., `airgap-releases`)
- **How to get it**:
  1. Cloudflare Dashboard → R2
  2. Use the bucket name you created

## Cloudflare R2 Setup

If you haven't set up Cloudflare R2 yet:

### 1. Create R2 Bucket
```bash
# Via Cloudflare Dashboard
1. Go to R2 → Create bucket
2. Enter bucket name: airgap-releases
3. Click Create bucket
```

### 2. Create API Token
```bash
# Via Cloudflare Dashboard
1. Go to R2 → Manage R2 API Tokens
2. Click Create API Token
3. Set permissions: Object Read & Write
4. Optionally scope to specific buckets
5. Click Create API Token
6. IMPORTANT: Save the Access Key ID and Secret Access Key immediately
```

### 3. Configure Bucket Permissions (Optional)

For public read access (if you want to share releases publicly):
```bash
# Via Cloudflare Dashboard
1. Go to your bucket → Settings
2. Under "Public access" toggle "Allow access"
3. Note the public URL for your bucket
```

## Testing Your Configuration

### Test R2 Upload Manually

You can test R2 access before running the workflow:

```bash
# Install AWS CLI
sudo apt-get install awscli

# Configure credentials
export AWS_ACCESS_KEY_ID="your-r2-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-r2-secret-access-key"
export R2_ENDPOINT="https://xxxxx.r2.cloudflarestorage.com"

# Test upload
echo "test" > test.txt
aws s3 cp test.txt s3://airgap-releases/test.txt \
  --endpoint-url "$R2_ENDPOINT"

# Test download
aws s3 ls s3://airgap-releases/ \
  --endpoint-url "$R2_ENDPOINT"

# Cleanup
rm test.txt
aws s3 rm s3://airgap-releases/test.txt \
  --endpoint-url "$R2_ENDPOINT"
```

### Test Workflow Without R2

You can test the workflow without R2 uploads:

1. Don't configure R2 secrets
2. Trigger workflow manually via workflow_dispatch
3. Set "Upload to Cloudflare R2" to `false`
4. The workflow will skip the R2 upload job

## Alternative: AWS S3

If you prefer AWS S3 instead of Cloudflare R2, you can modify the workflow:

### Secrets Needed for S3
- `AWS_ACCESS_KEY_ID` - Your AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY` - Your AWS Secret Access Key
- `AWS_REGION` - Your S3 bucket region (e.g., `us-west-2`)
- `S3_BUCKET` - Your S3 bucket name

### Workflow Modifications

In `.github/workflows/airgap-release.yaml`, update the `upload-to-r2` job:

```yaml
# Replace R2 secrets with:
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ secrets.AWS_REGION }}
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

# Update the upload command:
- name: Upload to AWS S3
  env:
    S3_BUCKET: ${{ secrets.S3_BUCKET }}
  run: |
    # Remove --endpoint-url flag
    aws s3 cp "$file" "s3://${S3_BUCKET}/${RELEASE_TAG}/${filename}" \
      --no-progress
```

## Security Best Practices

### 1. Use Limited Scope Tokens
- Create R2 tokens with minimum required permissions
- Scope tokens to specific buckets if possible
- Rotate tokens regularly

### 2. Protect Secret Values
- Never commit secrets to git
- Don't expose secrets in logs
- Use GitHub's secret masking (automatic)

### 3. Monitor Access
- Review R2/S3 access logs regularly
- Set up alerts for unexpected access
- Monitor storage costs

### 4. Backup Strategy
- Keep backups of releases in multiple locations
- Document your bucket configuration
- Have a recovery plan

## Troubleshooting

### "Access Denied" Errors
- Verify Access Key ID and Secret Access Key are correct
- Check bucket permissions
- Ensure API token has write permissions

### "Bucket Not Found" Errors
- Verify bucket name is correct (case-sensitive)
- Check that bucket exists in your account
- Verify endpoint URL matches your account

### "Endpoint Connection Failed"
- Verify endpoint URL format
- Check for typos in the endpoint
- Ensure endpoint includes `https://`

## Cost Estimation

### Cloudflare R2 Costs (as of 2024)
- Storage: $0.015/GB/month
- Class A Operations (writes): $4.50/million
- Class B Operations (reads): $0.36/million
- **No egress fees** (major advantage over S3)

### Example Release Cost
For a release with:
- 20 GB total artifacts
- 100 downloads per month

**Monthly cost**: ~$0.30 storage + minimal operations = **< $1/month**

### AWS S3 Costs (for comparison)
- Storage: ~$0.023/GB/month
- Data transfer out: $0.09/GB (first 10 TB)
- Operations: Variable

**Same release**: ~$0.46 storage + ~$180 egress = **~$180/month**

**Winner**: Cloudflare R2 for public distribution (no egress fees)

## Additional Resources

- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
