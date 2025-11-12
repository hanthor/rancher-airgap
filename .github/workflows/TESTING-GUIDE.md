# Testing the Updated Airgap Workflow

This guide explains how to test the updated airgap workflow after merging the PR.

## Quick Test via GitHub Actions UI

1. Navigate to the repository on GitHub
2. Go to **Actions** tab
3. Select **Test Airgap K3s/ESS Deployment** workflow
4. Click **Run workflow** button
5. Select branch: `copilot/update-airgap-test-workflow` (or `main` after merge)
6. (Optional) Enable debug mode for troubleshooting
7. Click **Run workflow**

## What to Monitor

### Expected Successful Behavior

1. **Build Phase** (Steps 1-6)
   - Hauler stores sync successfully for K3s, ESS, and Helm
   - All required assets downloaded and stored

2. **Service Startup** (Step 7: "Start Hauler Registry and Fileserver")
   - ✅ K3s registry starts on port 5001 (within 30 retries)
   - ✅ ESS registry starts on port 5002 (within 30 retries)
   - ✅ K3s fileserver starts on port 8080 (within 30 retries)
   - ✅ Helm fileserver starts on port 8081 (within 30 retries)
   - If any service fails, log tail will show last 50 lines

3. **Helm Installation** (Step 11)
   - Architecture detected correctly (should be amd64 on GitHub runners)
   - Helm binary downloaded from fileserver
   - Helm version displayed

4. **ESS Deployment** (Step 12)
   - Values file generated with correct schema
   - Chart pulled from local registry using `--plain-http`
   - Deployment succeeds within timeout

5. **Validation** (Steps 15-16)
   - All pods reach Running state
   - Image verification passes (all images from local sources)
   - No external image pulls detected

### Key Improvements to Observe

Compare with previous runs to see:

1. **Better Error Messages**: If services fail to start, you'll see log tails automatically
2. **Faster Retries**: Services verify with 1-second intervals instead of longer delays
3. **No Permission Errors**: Fileservers use dedicated directories
4. **Clean Values**: ESS deployment uses minimal, schema-compliant values

## Debugging Failed Runs

### If Hauler Services Fail to Start

Check the workflow logs for:
- Last 50 lines of service log (automatically displayed)
- Port conflicts (unlikely in GitHub Actions)
- Store corruption (re-sync may be needed)

### If Helm Installation Fails

Check for:
- Correct architecture detection
- Fileserver serving the tarball
- Extraction path matches architecture

### If ESS Deployment Fails

Check for:
- Values schema compatibility
- Registry accessibility
- Chart version availability

### If Image Verification Fails

This means external images were pulled:
- Check `verify-images.sh` output for which images
- Update Hauler manifests to include missing images
- Re-run the workflow

## Local Testing

To test the same changes locally:

```bash
# Clone the repository
git clone https://github.com/hanthor/rancher-airgap.git
cd rancher-airgap
git checkout copilot/update-airgap-test-workflow

# Run the local airgap test (requires root)
sudo bash .github/workflows/scripts/local-airgap-test.sh
```

The local script now uses the same shared functions as the GHA workflow.

## Comparing Before/After

### Before (Previous Behavior)
- Inline service startup code (duplicated)
- No retry logic with timeouts
- Hardcoded architecture (amd64 only)
- Complex ESS values with deprecated keys
- Inline image verification
- Permission issues with fileserver

### After (New Behavior)
- Shared functions (DRY principle)
- Robust retry logic (30 attempts, 1s interval)
- Dynamic architecture detection
- Clean ESS values (schema 25.11.0 compliant)
- Reusable verification scripts
- Isolated fileserver directories

## Success Criteria

The workflow is successful if:
1. ✅ All 20 steps complete without errors
2. ✅ All Hauler services start within retry limits
3. ✅ Helm installs from local fileserver
4. ✅ ESS deploys with updated values
5. ✅ All pods reach Running state
6. ✅ Image verification passes (0 external images)
7. ✅ No permission errors in logs

## Rollback Plan

If the workflow fails unexpectedly:

1. Check if it's a transient issue (network, resource limits)
2. Re-run the workflow once
3. If still failing, review error logs
4. If needed, revert to previous workflow version
5. Report issues with full logs attached

## Contact

If you encounter issues not covered in this guide:
1. Check `.github/workflows/AIRGAP-TEST-IMPROVEMENTS.md` for detailed explanations
2. Review workflow logs for specific error messages
3. Test locally to reproduce
4. File an issue with reproduction steps
