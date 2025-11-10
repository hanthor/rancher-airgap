# Element Server Suite (ESS) Helm Chart

**Note:** View the [README](https://github.com/zackbradys/rancher-airgap/blob/main/README.md) for the latest versions!

## Collection and Packaging

[hauler/ess-helm/rancher-airgap-ess-helm.yaml](https://github.com/zackbradys/rancher-airgap/blob/main/hauler/ess-helm/rancher-airgap-ess-helm.yaml) - provides the content manifest for all the assets.

```bash
# pull the manifest
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/ess-helm/rancher-airgap-ess-helm.yaml

# sync to the store  
hauler store sync --files rancher-airgap-ess-helm.yaml

# save to tarball
hauler store save --filename rancher-airgap-ess-helm.tar.zst
```

## Across the Airgap

```bash
# Transfer the tarball to your airgapped environment
```

## Loading and Distribution

```bash
# load the tarball
hauler store load --filename rancher-airgap-ess-helm.tar.zst

# serve registry
hauler store serve registry
# or run in background: nohup hauler store serve registry &

# serve fileserver
hauler store serve fileserver  
# or run in background: nohup hauler store serve fileserver &
```

## Deployment

After loading and serving, install ESS using Helm:

```bash
# Set variables
export registry=<FQDN or IP>:5000
export ESS_VERSION=25.11.0

# Install ESS Community from local registry
helm upgrade --install --namespace "ess" ess oci://${registry}/hauler/matrix-stack \
  --version ${ESS_VERSION} \
  -f ~/ess-config-values/hostnames.yaml \
  -f ~/ess-config-values/tls.yaml \
  --wait
```

For detailed configuration and setup instructions, refer to the [ESS Helm documentation](https://github.com/element-hq/ess-helm).
