#!/bin/bash
set -euo pipefail

# Script to build and push CLI tools as OCI artifacts using ORAS

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-mkm29}"
REPOSITORY="${REPOSITORY:-uds-k3d-cilium/tools}"
TAG="${TAG:-v1.0.0}"

# Tool versions (can be overridden)
UDS_VERSION="${UDS_VERSION:-v0.27.7}"
HELM_VERSION="${HELM_VERSION:-v3.18.3}"
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.18.4}"
HUBBLE_VERSION="${HUBBLE_VERSION:-v1.17.5}"
K3D_VERSION="${K3D_VERSION:-v5.8.3}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.33.2}"
K9S_VERSION="${K9S_VERSION:-v0.50.6}"

# Full artifact name
ARTIFACT="${REGISTRY}/${NAMESPACE}/${REPOSITORY}:${TAG}"

echo "Building ORAS artifact with CLI tools..."
echo "Artifact: ${ARTIFACT}"
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

# Install ORAS if needed
if ! install_oras; then
    exit 1
fi

# Check if required tools are installed
for tool in wget curl tar; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is required but not installed"
        exit 1
    fi
done

# Check authentication
if ! oras_login "${REGISTRY}" "${NAMESPACE}"; then
    exit 1
fi

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# download_with_retry function is already in common.sh

# Function to download tool for specific platform
download_tool() {
    local os=$1
    local arch=$2
    local tool_dir="${TEMP_DIR}/${os}-${arch}"

    echo ""
    echo "=== Downloading tools for ${os}/${arch} ==="
    echo "    Tool directory: ${tool_dir}"

    # Prepare OS variants for different naming conventions
    local os_lower="$(echo ${os} | tr '[:upper:]' '[:lower:]')"
    local os_cap="$(echo ${os} | sed 's/\b\(.\)/\U\1/g')"

    # Create and verify tool directory
    mkdir -p "${tool_dir}"
    if [ ! -d "${tool_dir}" ]; then
        echo "ERROR: Failed to create directory ${tool_dir}"
        return 1
    fi

    # UDS CLI (uses capitalized OS: Linux, Darwin)
    echo "  📥 UDS CLI ${UDS_VERSION}..."
    local uds_url="https://github.com/defenseunicorns/uds-cli/releases/download/${UDS_VERSION}/uds-cli_${UDS_VERSION}_${os_cap}_${arch}"
    echo "  Downloading from: ${uds_url}"
    if ! download_with_retry "${uds_url}" "${tool_dir}/uds"; then
        echo "Failed to download UDS CLI"
        return 1
    fi
    chmod +x "${tool_dir}/uds"

    # Helm (uses lowercase OS: linux, darwin)
    echo "  📥 Helm ${HELM_VERSION}..."
    local helm_url="https://get.helm.sh/helm-${HELM_VERSION}-${os_lower}-${arch}.tar.gz"
    echo "  Downloading from: ${helm_url}"
    if ! download_with_retry "${helm_url}" "${TEMP_DIR}/helm.tar.gz"; then
        echo "Failed to download Helm"
        return 1
    fi
    # Extract to a temporary directory to avoid conflicts
    local helm_extract_dir="${TEMP_DIR}/helm-extract"
    mkdir -p "${helm_extract_dir}"
    tar -xzf "${TEMP_DIR}/helm.tar.gz" -C "${helm_extract_dir}"
    mv "${helm_extract_dir}/${os_lower}-${arch}/helm" "${tool_dir}/helm"
    chmod +x "${tool_dir}/helm"
    # Clean up
    rm -rf "${TEMP_DIR}/helm.tar.gz" "${helm_extract_dir}"

    # Cilium CLI (uses lowercase OS: linux, darwin)
    echo "  📥 Cilium CLI ${CILIUM_CLI_VERSION}..."
    local cilium_url="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${os_lower}-${arch}.tar.gz"
    echo "  Downloading from: ${cilium_url}"
    if ! download_with_retry "${cilium_url}" "${TEMP_DIR}/cilium.tar.gz"; then
        echo "Failed to download Cilium CLI"
        return 1
    fi
    # Ensure directory exists and extract
    mkdir -p "${tool_dir}"
    if ! tar -xzf "${TEMP_DIR}/cilium.tar.gz" -C "${tool_dir}"; then
        echo "Failed to extract Cilium CLI"
        return 1
    fi
    chmod +x "${tool_dir}/cilium"
    rm -f "${TEMP_DIR}/cilium.tar.gz"

    # Hubble CLI (uses lowercase OS: linux, darwin)
    echo "  📥 Hubble CLI ${HUBBLE_VERSION}..."
    local hubble_url="https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-${os_lower}-${arch}.tar.gz"
    echo "  Downloading from: ${hubble_url}"
    if ! download_with_retry "${hubble_url}" "${TEMP_DIR}/hubble.tar.gz"; then
        echo "Failed to download Hubble CLI"
        return 1
    fi
    # Ensure directory exists and extract
    mkdir -p "${tool_dir}"
    if ! tar -xzf "${TEMP_DIR}/hubble.tar.gz" -C "${tool_dir}"; then
        echo "Failed to extract Hubble CLI"
        return 1
    fi
    chmod +x "${tool_dir}/hubble"
    rm -f "${TEMP_DIR}/hubble.tar.gz"

    # k3d (uses lowercase OS: linux, darwin)
    echo "  📥 k3d ${K3D_VERSION}..."
    local k3d_url="https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${os_lower}-${arch}"
    echo "  Downloading from: ${k3d_url}"
    if ! download_with_retry "${k3d_url}" "${tool_dir}/k3d"; then
        echo "Failed to download k3d"
        return 1
    fi
    chmod +x "${tool_dir}/k3d"

    # kubectl (uses lowercase OS: linux, darwin)
    echo "  📥 kubectl ${KUBECTL_VERSION}..."
    local kubectl_url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${os_lower}/${arch}/kubectl"
    echo "  Downloading from: ${kubectl_url}"
    if ! download_with_retry "${kubectl_url}" "${tool_dir}/kubectl"; then
        echo "Failed to download kubectl"
        return 1
    fi
    chmod +x "${tool_dir}/kubectl"

    # k9s (uses capitalized OS: Linux, Darwin)
    echo "  📥 k9s ${K9S_VERSION}..."
    local k9s_url="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${os_cap}_${arch}.tar.gz"
    echo "  Downloading from: ${k9s_url}"
    if ! download_with_retry "${k9s_url}" "${TEMP_DIR}/k9s.tar.gz"; then
        echo "Failed to download k9s"
        return 1
    fi
    tar -xzf "${TEMP_DIR}/k9s.tar.gz" -C "${tool_dir}" k9s
    chmod +x "${tool_dir}/k9s"
    rm "${TEMP_DIR}/k9s.tar.gz"

    echo "  ✅ Downloaded all tools for ${os}/${arch}"
    return 0
}

# Download tools for Linux platforms only (OCI artifacts are for containers)
echo ""
echo "📦 Downloading tools for Linux platforms..."

if ! download_tool "linux" "amd64"; then
    echo "Failed to download tools for linux/amd64"
    exit 1
fi

if ! download_tool "linux" "arm64"; then
    echo "Failed to download tools for linux/arm64"
    exit 1
fi

echo ""
echo "ℹ️  Note: OCI artifacts only include Linux binaries (containers run on Linux)"
echo "   For macOS/Darwin, use the Docker image directly or download tools separately"

# This function will be called for each platform
create_platform_manifest_annotations() {
    local os=$1
    local arch=$2
    local output_file=$3

    cat > "${output_file}" <<EOF
{
  "\$manifest": {
    "org.opencontainers.image.title": "UDS k3d Cilium Tools",
    "org.opencontainers.image.description": "CLI tools for UDS k3d Cilium deployment (${os}/${arch})",
    "org.opencontainers.image.version": "${TAG}",
    "org.opencontainers.image.source": "https://github.com/mkm29/uds-k3d-cilium",
    "org.opencontainers.image.authors": "UDS k3d Cilium Maintainers",
    "org.opencontainers.image.licenses": "Apache-2.0",
    "org.opencontainers.image.architecture": "${arch}",
    "org.opencontainers.image.os": "${os}"
  }
}
EOF
}

# Push artifacts for each platform
echo ""
echo "🚀 Pushing artifacts to registry..."

for platform_dir in "${TEMP_DIR}"/*-*; do
    if [ -d "$platform_dir" ]; then
        platform=$(basename "$platform_dir")
        os=$(echo "$platform" | cut -d'-' -f1)
        arch=$(echo "$platform" | cut -d'-' -f2)

        echo ""
        echo "  📤 Pushing ${os}/${arch}..."

        # Create platform-specific manifest annotations
        create_platform_manifest_annotations "${os}" "${arch}" "${platform_dir}/manifest-annotations.json"

        # Create file annotations for this platform
        cat > "${platform_dir}/file-annotations.json" <<EOF
{
  "uds": {
    "org.opencontainers.image.title": "uds",
    "org.opencontainers.image.description": "UDS CLI v${UDS_VERSION}",
    "dev.defenseunicorns.tool.version": "${UDS_VERSION}"
  },
  "helm": {
    "org.opencontainers.image.title": "helm",
    "org.opencontainers.image.description": "Helm v${HELM_VERSION}",
    "io.helm.version": "${HELM_VERSION}"
  },
  "cilium": {
    "org.opencontainers.image.title": "cilium",
    "org.opencontainers.image.description": "Cilium CLI v${CILIUM_CLI_VERSION}",
    "io.cilium.version": "${CILIUM_CLI_VERSION}"
  },
  "hubble": {
    "org.opencontainers.image.title": "hubble",
    "org.opencontainers.image.description": "Hubble CLI v${HUBBLE_VERSION}",
    "io.cilium.hubble.version": "${HUBBLE_VERSION}"
  },
  "k3d": {
    "org.opencontainers.image.title": "k3d",
    "org.opencontainers.image.description": "k3d v${K3D_VERSION}",
    "io.k3d.version": "${K3D_VERSION}"
  },
  "kubectl": {
    "org.opencontainers.image.title": "kubectl",
    "org.opencontainers.image.description": "kubectl v${KUBECTL_VERSION}",
    "io.k8s.kubectl.version": "${KUBECTL_VERSION}"
  },
  "k9s": {
    "org.opencontainers.image.title": "k9s",
    "org.opencontainers.image.description": "k9s v${K9S_VERSION}",
    "io.k9s.version": "${K9S_VERSION}"
  }
}
EOF

        # Push with platform-specific tag
        # Change to the platform directory to avoid absolute path issues
        pushd "${platform_dir}" > /dev/null

        # Create a config.json for this platform
        cat > "config.json" <<EOF
{
  "architecture": "${arch}",
  "os": "${os}"
}
EOF
        
        if ! oras push "${ARTIFACT}-${os}-${arch}" \
            --config "config.json:application/vnd.oci.image.config.v1+json" \
            --annotation-file "file-annotations.json" \
            --annotation-file "manifest-annotations.json" \
            "uds:application/vnd.uds.cli" \
            "helm:application/vnd.helm.cli" \
            "cilium:application/vnd.cilium.cli" \
            "hubble:application/vnd.cilium.hubble.cli" \
            "k3d:application/vnd.k3d.cli" \
            "kubectl:application/vnd.kubernetes.kubectl" \
            "k9s:application/vnd.k9s.cli"; then
            popd > /dev/null
            echo "  ❌ Failed to push ${os}/${arch}"
            exit 1
        fi

        popd > /dev/null
        echo "  ✅ Pushed ${os}/${arch}"
    fi
done

# Summary of what was pushed
echo ""
echo "📋 Platform-specific artifacts pushed:"
echo ""

# List all pushed artifacts
for platform_dir in "${TEMP_DIR}"/*-*; do
    if [ -d "$platform_dir" ]; then
        platform=$(basename "$platform_dir")
        echo "  ✅ ${ARTIFACT}-${platform}"
    fi
done

echo ""
echo "✅ Successfully built and pushed ORAS artifacts!"
echo ""
echo "To use the tools on Linux:"
echo "  oras pull ${ARTIFACT}-linux-amd64"
echo "  oras pull ${ARTIFACT}-linux-arm64"
echo ""
echo "Or use the installer script (auto-detects platform):"
echo "  ./tools/use-tools-artifact.sh"
echo ""
echo "Note: ORAS artifacts contain Linux binaries only."
echo "For macOS/Darwin, use the Docker image or download tools directly."