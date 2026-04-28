#! /usr/bin/env bash

set -euo pipefail

# Login to registry
echo "$CI_REGISTRY_PASSWORD" | oras login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"

ARTIFACT_TYPE="application/vnd.unknown.config.v1+json"

# Use tag if available, otherwise fall back to commit SHA
VERSION=${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}

# Create a manifest file for the catalog
cat >catalog-manifest.json <<EOF
{
"version": "$VERSION",
"created": "$(date -Iseconds)",
"source": "$CI_PROJECT_URL",
"commit": "$CI_COMMIT_SHA",
"files": [
  $(find vendor metrics-catalog reference-architectures/get-hybrid/src reference-architectures/default-overrides mixins-monitoring libsonnet -type f -name "*.libsonnet" -o -name "*.json" | jq -R . | paste -sd, -),
  scripts/generate-reference-architecture-config.sh,
  scripts/ensure-jsonnet-tool.sh,
  scripts/ensure-mixtool.sh,
  reference-architectures/default-overrides/gitlab-metrics-options.libsonnet
]
}
EOF

# Push all files as OCI artifact with correct custom media type mappings.
oras push "$DOCKER_DESTINATION" \
  --disable-path-validation \
  --artifact-type "$ARTIFACT_TYPE" \
  --annotation "org.opencontainers.image.title=Metrics Catalog Configuration" \
  --annotation "org.opencontainers.image.description=Configuration files and schemas for metrics catalog" \
  --annotation "org.opencontainers.image.version=$VERSION" \
  --annotation "org.opencontainers.image.created=$(date -Iseconds)" \
  --annotation "org.opencontainers.image.source=$CI_PROJECT_URL" \
  --annotation "org.opencontainers.image.revision=$CI_COMMIT_SHA" \
  --annotation "catalog.type=metrics" \
  --annotation "catalog.format=mixed" \
  "$JSONNET_VENDOR_DIR:application/vnd.oci.image.layer.v1.tar" \
  metrics-catalog/:application/vnd.oci.image.layer.v1.tar \
  reference-architectures/get-hybrid/src:application/vnd.oci.image.layer.v1.tar \
  reference-architectures/default-overrides/gitlab-metrics-options.libsonnet:application/vnd.oci.image.layer.v1.tar \
  mixins-monitoring:application/vnd.oci.image.layer.v1.tar \
  scripts:application/vnd.oci.image.layer.v1.tar \
  libsonnet:application/vnd.oci.image.layer.v1.tar

# Also tag as latest
oras tag "$DOCKER_DESTINATION" latest
