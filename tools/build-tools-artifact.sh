#!/bin/bash
set -euo pipefail

# Simple script to build and push CLI tools OCI artifact using docker buildx

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-mkm29}"
REPOSITORY="${REPOSITORY:-uds-k3d-cilium/tools}"
TAG="${TAG:-v1.0.0}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Tool versions (can be overridden)
UDS_VERSION="${UDS_VERSION:-v0.27.7}"
HELM_VERSION="${HELM_VERSION:-v3.18.3}"
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.18.4}"
HUBBLE_VERSION="${HUBBLE_VERSION:-v1.17.5}"
K3D_VERSION="${K3D_VERSION:-v5.8.3}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.33.2}"
K9S_VERSION="${K9S_VERSION:-v0.50.6}"

# Full image name
IMAGE="${REGISTRY}/${NAMESPACE}/${REPOSITORY}:${TAG}"

echo "Building multi-platform tools image..."
echo "Image: ${IMAGE}"
echo "Platforms: ${PLATFORMS}"
echo ""
echo "Tool versions:"
echo "  UDS CLI: ${UDS_VERSION}"
echo "  Helm: ${HELM_VERSION}"
echo "  Cilium CLI: ${CILIUM_CLI_VERSION}"
echo "  Hubble CLI: ${HUBBLE_VERSION}"
echo "  k3d: ${K3D_VERSION}"
echo "  kubectl: ${KUBECTL_VERSION}"
echo "  k9s: ${K9S_VERSION}"
echo ""

# Ensure buildx is available
if ! docker buildx version &>/dev/null; then
    echo "Error: docker buildx is not available. Please install Docker Desktop or enable buildx."
    exit 1
fi

# Check authentication
if ! docker_login "${REGISTRY}" "${NAMESPACE}"; then
    echo ""
    echo "For more details, see: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry"
    echo ""
    exit 1
fi

# Create or use existing buildx builder
BUILDER_NAME="uds-tools-builder"
if ! docker buildx ls --format "{{.Name}}" | grep "${BUILDER_NAME}"; then
    echo "Creating buildx builder: ${BUILDER_NAME}"
    docker buildx create --name "${BUILDER_NAME}" --use --platform "${PLATFORMS}"
else
    echo "Using existing buildx builder: ${BUILDER_NAME}"
    docker buildx use "${BUILDER_NAME}"
fi

# Build and push the multi-platform image
echo "Building and pushing image..."
docker buildx build \
    --platform "${PLATFORMS}" \
    --build-arg UDS_VERSION="${UDS_VERSION}" \
    --build-arg HELM_VERSION="${HELM_VERSION}" \
    --build-arg CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION}" \
    --build-arg HUBBLE_VERSION="${HUBBLE_VERSION}" \
    --build-arg K3D_VERSION="${K3D_VERSION}" \
    --build-arg KUBECTL_VERSION="${KUBECTL_VERSION}" \
    --build-arg K9S_VERSION="${K9S_VERSION}" \
    -t "${IMAGE}" \
    --push .

echo ""
echo "✅ Successfully built and pushed: ${IMAGE}"
echo ""
echo "To use the tools:"
echo "  docker run --rm -v \$PWD:/workspace ${IMAGE} uds version"
echo "  docker run --rm -v \$PWD:/workspace ${IMAGE} kubectl version --client"
echo ""
echo "Or extract the binaries:"
echo "  docker create --name tools-temp ${IMAGE}"
echo "  docker cp tools-temp:/bin ."
echo "  docker rm tools-temp"