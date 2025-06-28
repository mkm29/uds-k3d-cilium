#!/bin/bash
set -euo pipefail

# Script to download and install CLI tools using ORAS

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Detect platform
PLATFORM=$(detect_platform)
if [ $? -ne 0 ]; then
    echo "Failed to detect platform"
    exit 1
fi

OS=$(echo "${PLATFORM}" | cut -d'/' -f1)
ARCH=$(echo "${PLATFORM}" | cut -d'/' -f2)

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-mkm29}"
REPOSITORY="${REPOSITORY:-uds-k3d-cilium/tools}"
TAG="${TAG:-v1.0.1}"
INSTALL_PATH="${INSTALL_PATH:-$HOME/.local/bin}"

# Full image name
IMAGE="${REGISTRY}/${NAMESPACE}/${REPOSITORY}:${TAG}"

echo "📦 UDS k3d Cilium Tools Installer (ORAS)"
echo "========================================"
echo ""
echo "Detected platform: ${OS}/${ARCH}"
echo "Installing to: ${INSTALL_PATH}"
echo ""

# Check if jq is installed (needed for manifest parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Installing jq for JSON parsing...${NC}"

    # Try to install jq based on OS
    if [ "${OS}" = "darwin" ]; then
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo -e "${RED}Please install jq: brew install jq${NC}"
            exit 1
        fi
    elif [ "${OS}" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            echo -e "${RED}Please install jq manually${NC}"
            exit 1
        fi
    fi
fi

# Install ORAS if needed
if ! install_oras "${INSTALL_PATH}"; then
    exit 1
fi

# Create install directory if it doesn't exist
mkdir -p "${INSTALL_PATH}"

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

echo "⬇️  Pulling tools artifact: ${IMAGE}"
echo ""

# Check authentication (but don't exit if it fails - might be public)
oras_login "${REGISTRY}" "${NAMESPACE}" || true

# Check if this is a Docker image or ORAS artifact by trying to fetch manifest
echo "Detecting artifact type..."
MANIFEST=$(oras manifest fetch "${IMAGE}" 2>/dev/null || echo "")

if [ -z "$MANIFEST" ]; then
    echo -e "${RED}Failed to fetch manifest. Please check authentication and image existence.${NC}"
    exit 1
fi

# Check if it's an ORAS artifact (has file annotations) or Docker image
if echo "$MANIFEST" | jq -e '.layers[0].annotations."org.opencontainers.image.title"' &>/dev/null; then
    # It's an ORAS artifact
    echo "Detected ORAS artifact"

    # For ORAS artifacts, we need to use platform-specific tags
    PLATFORM_IMAGE="${IMAGE}-${OS}-${ARCH}"
    echo "Pulling ${PLATFORM_IMAGE}..."

    if ! oras pull "${PLATFORM_IMAGE}" \
        -o "${TEMP_DIR}"; then
        echo ""
        echo -e "${RED}Failed to pull ORAS artifact.${NC}"
        echo "This might be because:"
        echo "1. The platform-specific tag doesn't exist"
        echo "2. Authentication is required"
        echo ""
        echo "Trying base tag with platform flag..."
        # Try with platform flag as fallback
        if ! oras pull "${IMAGE}" -o "${TEMP_DIR}"; then
            echo -e "${RED}Failed to pull ORAS artifact.${NC}"
            echo "See tools/SETUP.md for detailed setup instructions."
            exit 1
        fi
    fi
else
    # It's a Docker image - we need to extract it differently
    echo "Detected Docker image (not ORAS artifact)"
    echo ""
    echo -e "${YELLOW}This image was built with Docker, not ORAS.${NC}"
    echo "To use ORAS, build with: ./tools/build-oras-artifact.sh"
    echo ""
    echo "Falling back to Docker extraction method..."

    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is required to extract from Docker images${NC}"
        echo "Either install Docker or rebuild as ORAS artifact"
        exit 1
    fi

    # Create temporary container
    TEMP_CONTAINER="uds-tools-extract-$$"

    echo "Pulling Docker image..."
    if ! docker pull "${IMAGE}"; then
        echo -e "${RED}Failed to pull Docker image${NC}"
        exit 1
    fi

    echo "Extracting tools..."
    docker create --name "${TEMP_CONTAINER}" --platform "${OS}/${ARCH}" "${IMAGE}" >/dev/null 2>&1

    # Extract to temp directory
    for tool in uds helm cilium hubble k3d kubectl k9s; do
        if docker cp "${TEMP_CONTAINER}:/bin/${tool}" "${TEMP_DIR}/${tool}" 2>/dev/null; then
            chmod +x "${TEMP_DIR}/${tool}"
        fi
    done

    # Cleanup
    docker rm "${TEMP_CONTAINER}" >/dev/null 2>&1 || true
fi

# Install tools
echo ""
echo "🔧 Installing tools to ${INSTALL_PATH}..."

# The tools should be in ${TEMP_DIR}/bin/ for Docker images or root for ORAS
if [ -d "${TEMP_DIR}/bin" ]; then
    TOOLS_DIR="${TEMP_DIR}/bin"
else
    # ORAS artifacts or flat structure
    TOOLS_DIR="${TEMP_DIR}"
fi

for tool in uds helm cilium hubble k3d kubectl k9s; do
    if [ -f "${TOOLS_DIR}/${tool}" && ! command "${tool}" ]; then
        cp "${TOOLS_DIR}/${tool}" "${INSTALL_PATH}/${tool}"
        chmod +x "${INSTALL_PATH}/${tool}"
        echo -e "  ${GREEN}✓${NC} ${tool} installed"
    else
        echo -e "  ${RED}✗${NC} ${tool} not found in artifact"
    fi
done

# Verify installations
echo ""
echo "🔍 Verifying installations..."
echo ""

# Check if install path is in PATH
if [[ ":$PATH:" != *":${INSTALL_PATH}:"* ]]; then
    echo -e "${YELLOW}Warning: ${INSTALL_PATH} is not in your PATH${NC}"
    echo ""
    echo "Add it to your shell configuration:"
    echo "  export PATH=\"${INSTALL_PATH}:\$PATH\""
    echo ""
fi

# Verify each tool
for tool in uds helm cilium hubble k3d kubectl k9s; do
    if [ -f "${INSTALL_PATH}/${tool}" ]; then
        if [ "$tool" = "kubectl" ]; then
            version=$("${INSTALL_PATH}/${tool}" version --client --short 2>/dev/null || echo "unknown")
        else
            version=$("${tool}" version 2>/dev/null | head -n1 || echo "unknown")
        fi
        echo -e "  ${tool}: ${GREEN}${version}${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Tools installation complete!${NC}"
echo ""
echo "If ${INSTALL_PATH} is in your PATH, you can now use:"
echo "  uds version"
echo "  helm version"
echo "  cilium version"
echo "  hubble version"
echo "  k3d version"
echo "  kubectl version"
echo "  k9s"