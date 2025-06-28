#!/bin/bash
# Quick installer script for UDS k3d Cilium tools
# Usage: curl -sL https://raw.githubusercontent.com/mkm29/uds-k3d-cilium/main/tools/install.sh | bash
# This script downloads and runs use-tools-artifact.sh which uses ORAS to pull the tools

set -euo pipefail

# Detect OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Convert architecture names
case ${ARCH} in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    arm64)
        # macOS already uses arm64
        ;;
    *)
        echo "Error: Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

echo "🚀 Installing UDS k3d Cilium tools for ${OS}/${ARCH}..."
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf ${TEMP_DIR}' EXIT

# Download the installer script
echo "📥 Downloading installer..."
curl -sL https://raw.githubusercontent.com/mkm29/uds-k3d-cilium/main/tools/use-tools-artifact.sh -o "${TEMP_DIR}/use-tools-artifact.sh"
chmod +x "${TEMP_DIR}/use-tools-artifact.sh"

# Run the installer
echo ""
exec "${TEMP_DIR}/use-tools-artifact.sh" "$@"