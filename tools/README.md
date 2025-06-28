# UDS k3d Cilium Tools OCI Artifact

This directory contains scripts to create and use an OCI artifact that bundles all the CLI tools required for UDS k3d Cilium deployment.

📚 **First time?** See the [First-Time Setup Guide](SETUP.md) for detailed instructions.

## What's Included

The OCI artifact contains:

- **UDS CLI** (v0.27.7): Defense Unicorns UDS CLI
- **Helm** (v3.16.3): Kubernetes package manager
- **Cilium CLI** (v0.18.4): Cilium CNI management tool
- **Hubble CLI** (v1.17.5): Hubble observability CLI for network flows
- **k3d** (v5.8.3): Lightweight Kubernetes in Docker
- **kubectl** (v1.33.2): Kubernetes command-line tool
- **k9s** (v0.50.6): Terminal-based Kubernetes UI

## Prerequisites

- Docker with buildx support (Docker Desktop includes this)
- Access to a container registry (e.g., GitHub Container Registry, Docker Hub)
- Authentication to your registry (see [Authentication](#authentication) section)
- ORAS CLI for pulling artifacts (auto-installed by use script if missing)

## Authentication

### GitHub Container Registry (ghcr.io)

1. **Create a Personal Access Token (PAT)**:
   - Go to `https://github.com/settings/tokens/new`
   - Select scope: `write:packages` (this automatically includes `read:packages`)
   - Copy the generated token

2. **Login to ghcr.io**:

   ```bash
   export CR_PAT=YOUR_TOKEN_HERE
   echo $CR_PAT | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```

3. **Verify authentication**:

   ```bash
   docker pull ghcr.io/YOUR_USERNAME/test:latest
   ```

### Docker Hub

```bash
docker login
# Enter your Docker Hub username and password
```

For more details, see the [official GitHub documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).

## Building the Tools Artifact

You can build the tools in two ways:

### Option 1: Docker Image (Multi-platform container)

```bash
# Build and push multi-platform Docker image
./tools/build-tools-artifact.sh

# Build for specific platforms
PLATFORMS="linux/amd64,linux/arm64" \
./tools/build-tools-artifact.sh

# Or specify custom registry and settings
REGISTRY=docker.io \
NAMESPACE=myusername \
REPOSITORY=uds-tools \
TAG=v1.0.0 \
./tools/build-tools-artifact.sh

# Override tool versions
UDS_VERSION=v0.27.7 \
HELM_VERSION=v3.18.3 \
CILIUM_CLI_VERSION=v0.18.4 \
./tools/build-tools-artifact.sh
```

The script uses `docker buildx` to create a multi-platform container image.

### Option 2: ORAS Artifact (Native OCI artifacts - Linux only)

```bash
# Build and push as ORAS artifacts (Linux platforms only)
./tools/build-oras-artifact.sh

# Or with custom settings
REGISTRY=ghcr.io \
NAMESPACE=myusername \
REPOSITORY=uds-tools-oras \
TAG=v1.0.0 \
./tools/build-oras-artifact.sh
```

This creates proper OCI artifacts with file annotations that ORAS can pull directly.
**Note**:

- ORAS artifacts only include Linux binaries (linux/amd64, linux/arm64) since OCI registries are primarily for container images that run on Linux.
- Each platform is pushed as a separate tagged artifact (e.g., `v1.0.1-linux-amd64`, `v1.0.1-linux-arm64`)
- ORAS doesn't currently support multi-platform index manifests like Docker, so platform-specific tags are used instead

### Direct Docker Buildx Command

```bash
# Build multi-platform image
docker buildx build \
  --platform linux/amd64,linux/arm64,darwin/amd64,darwin/arm64 \
  --build-arg UDS_VERSION=v0.27.7 \
  --build-arg HELM_VERSION=v3.18.3 \
  --build-arg CILIUM_CLI_VERSION=v0.16.22 \
  --build-arg HUBBLE_VERSION=v1.17.5 \
  --build-arg K3D_VERSION=v5.8.3 \
  --build-arg KUBECTL_VERSION=v1.33.2 \
  --build-arg K9S_VERSION=v0.50.6 \
  -t ghcr.io/mkm29/uds-k3d-cilium-tools:latest \
  -f tools/Dockerfile \
  --push .
```

## Using the Tools

### Quick Install

```bash
# One-line install (auto-detects OS and architecture)
curl -sL https://raw.githubusercontent.com/mkm29/uds-k3d-cilium/main/tools/install.sh | bash

# Download and install tools to ~/.local/bin
./tools/use-tools-artifact.sh

# Or specify custom location
INSTALL_PATH=/usr/local/bin ./tools/use-tools-artifact.sh

# With authentication (if private)
export CR_PAT=YOUR_GITHUB_TOKEN
./tools/use-tools-artifact.sh
```

The installer:

- Automatically detects your platform using `uname -s` and `uname -m`
- Auto-installs ORAS CLI if not present
- Detects whether the artifact is a Docker image or ORAS artifact
- Uses the appropriate method to extract tools
- Falls back to Docker for Docker images if ORAS can't handle them

### Manual Usage with ORAS

```bash
# Install ORAS if not present
brew install oras  # macOS
# or download from https://github.com/oras-project/oras/releases

# Login to registry (if private)
echo $CR_PAT | oras login ghcr.io -u YOUR_USERNAME --password-stdin

# Pull the artifact for your platform (platform-specific tags)
oras pull ghcr.io/mkm29/uds-k3d-cilium/tools:v1.0.1-linux-amd64 \
  -o ./tools-bin

# Or for ARM64
oras pull ghcr.io/mkm29/uds-k3d-cilium/tools:v1.0.1-linux-arm64 \
  -o ./tools-bin

# Tools will be in the tools-bin/bin/ directory
chmod +x ./tools-bin/bin/*
./tools-bin/bin/uds version

# Or install system-wide
sudo cp tools-bin/bin/* /usr/local/bin/
```

### Manual Usage with Docker

```bash
# Extract tools from the image
docker create --name tools ghcr.io/mkm29/uds-k3d-cilium-tools:latest
docker cp tools:/bin ./tools-bin
docker rm tools

# Tools will be in the tools-bin/ directory
./tools-bin/uds version
./tools-bin/helm version
./tools-bin/cilium version
./tools-bin/hubble version
./tools-bin/k3d version
./tools-bin/kubectl version --client
./tools-bin/k9s version

# Or install system-wide
sudo cp tools-bin/* /usr/local/bin/
```

### Run Tools Directly from Docker

```bash
# Run any tool directly from the container
docker run --rm ghcr.io/mkm29/uds-k3d-cilium-tools:latest uds version
docker run --rm ghcr.io/mkm29/uds-k3d-cilium-tools:latest kubectl version --client

# With volume mount for local files
docker run --rm -v $PWD:/workspace -w /workspace \
  ghcr.io/mkm29/uds-k3d-cilium-tools:latest \
  helm create mychart
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Extract UDS Tools
  run: |
    docker create --name tools ghcr.io/mkm29/uds-k3d-cilium-tools:latest
    sudo docker cp tools:/bin/. /usr/local/bin/
    docker rm tools

- name: Verify Tools
  run: |
    uds version
    helm version
    cilium version
    hubble version
    k3d version
    kubectl version --client
    k9s version
```

### GitLab CI Example

```yaml
install-tools:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker create --name tools ghcr.io/mkm29/uds-k3d-cilium-tools:latest
    - docker cp tools:/bin/. /usr/local/bin/
    - docker rm tools
    - uds version && helm version && cilium version && hubble version && k3d version && kubectl version --client && k9s version
```

## Making Your Package Visible

### Option 1: Make the Package Public (Recommended)

After your first push, the package will be private. To make it public:

1. Go to `https://github.com/users/YOUR_USERNAME/packages`
2. Click on the `uds-k3d-cilium` package
3. Click "Package settings" (gear icon)
4. Scroll down to "Danger Zone"
5. Click "Change visibility" and select "Public"

### Option 2: Link to Repository

The package will be automatically linked to your repository if it includes the proper label:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/uds-k3d-cilium"
```

This is already included in our Dockerfile. GitHub will also display multi-arch support if the manifest includes:

```json
{
  "annotations": {
    "org.opencontainers.image.description": "Multi-platform CLI tools..."
  }
}
```

## Customization

### Custom Tool Versions

```bash
# Override tool versions when building
UDS_VERSION=v0.21.0 \
HELM_VERSION=v3.17.0 \
CILIUM_CLI_VERSION=v0.17.0 \
HUBBLE_VERSION=v1.17.6 \
K3D_VERSION=v5.9.0 \
KUBECTL_VERSION=v1.34.0 \
K9S_VERSION=v0.51.0 \
./tools/build-tools-artifact.sh
```

### Private Registry

```bash
# Push to private registry
REGISTRY=my-registry.company.com \
NAMESPACE=platform-team \
REGISTRY_USERNAME=svcaccount \
REGISTRY_PASSWORD="${REGISTRY_TOKEN}" \
./tools/build-tools-artifact.sh
```

## Docker Image vs ORAS Artifact

### Docker Image (`build-tools-artifact.sh`)

- Creates a standard container image with binaries in `/bin`
- Supports all platforms (linux/amd64, linux/arm64, darwin/amd64, darwin/arm64)
- Can be run as a container or extracted with Docker
- ORAS can pull it but won't extract files (no file annotations)
- Best for container-based workflows and cross-platform support

### ORAS Artifact (`build-oras-artifact.sh`)

- Creates OCI artifacts with proper file annotations
- Linux-only (linux/amd64, linux/arm64) - follows OCI container conventions
- Each binary is a separate layer with metadata
- ORAS can pull and extract files directly
- Best for direct file distribution in Linux environments

## Repository Structure

```bash
tools/
├── build-tools-artifact.sh    # Build Docker image with CLI tools
├── build-oras-artifact.sh     # Build ORAS artifact with CLI tools
├── use-tools-artifact.sh      # Install tools from either Docker or ORAS
├── common.sh                  # Shared functions for authentication and utilities
├── Dockerfile                 # Multi-stage Dockerfile for tools
├── README.md                  # This documentation
└── SETUP.md                   # First-time setup guide
```

## Artifact Structure

```bash
.
├── bin/
│   ├── uds         # UDS CLI binary
│   ├── helm        # Helm binary
│   ├── cilium      # Cilium CLI binary
│   ├── hubble      # Hubble CLI binary
│   ├── k3d         # k3d binary
│   ├── kubectl     # Kubernetes CLI binary
│   └── k9s         # Terminal Kubernetes UI binary
├── manifest.json   # Artifact metadata
└── README.md       # Artifact documentation
```

## Benefits

1. **Single Source of Truth**: All required tools in one versioned artifact
2. **Multi-Platform Support**: Works on Linux and macOS (amd64 and arm64)
3. **CI/CD Friendly**: Easy to integrate into pipelines
4. **Version Control**: Pin specific versions of all tools
5. **Fast Downloads**: Binary distribution, no compilation needed
6. **Registry Agnostic**: Works with any OCI-compliant registry

## Troubleshooting

### Docker Buildx Not Available

```bash
# Enable experimental features in Docker
docker buildx version

# Create a new builder instance
docker buildx create --use
```

### Registry Authentication Issues

```bash
# Login to GitHub Container Registry (for Docker)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Login to GitHub Container Registry (for ORAS)
echo $CR_PAT | oras login ghcr.io -u USERNAME --password-stdin

# Login to Docker Hub
docker login docker.io -u USERNAME
oras login docker.io
```

### ORAS Issues

```bash
# ORAS not found
# The use-tools-artifact.sh script will auto-install it, or:
brew install oras  # macOS
# or download from https://github.com/oras-project/oras/releases

# Platform selection issues
# List available platforms
oras manifest fetch ghcr.io/mkm29/uds-k3d-cilium/tools:v1.0.0 | jq '.manifests[].platform'

# Pull without platform selection (gets all platforms)
oras pull ghcr.io/mkm29/uds-k3d-cilium/tools:v1.0.0 -o ./tools-all
```

### Wrong Platform

The scripts automatically detect and download the correct platform. If you need specific platforms:

```bash
# Download specific platform
PLATFORMS=darwin/arm64 ./tools/build-tools-artifact.sh

# Multiple platforms
PLATFORMS="linux/amd64,darwin/arm64" ./tools/build-tools-artifact.sh
```
