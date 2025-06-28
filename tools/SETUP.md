# First-Time Setup Guide for UDS k3d Cilium Tools

This guide walks you through setting up everything needed to build and use the UDS k3d Cilium tools.

## Step 1: Install Docker Desktop

Download and install Docker Desktop from: https://www.docker.com/products/docker-desktop/

Docker Desktop includes:

- Docker Engine
- Docker Buildx (for multi-platform builds)
- Docker Compose

## Step 2: Create a GitHub Personal Access Token

1. Go to `https://github.com/settings/tokens/new`
2. Give your token a descriptive name (e.g., "Docker Package Registry")
3. Set an expiration (or select "No expiration" for permanent tokens)
4. Select the following scope:
   - `write:packages` (this automatically selects `read:packages`)
5. Click "Generate token"
6. **Copy the token immediately** (you won't be able to see it again!)

## Step 3: Authenticate to GitHub Container Registry

```bash
# Set your GitHub username
export GITHUB_USERNAME="your-github-username"

# Set your token (paste the token you just created)
export CR_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"

# Login to ghcr.io
echo $CR_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

You should see: `Login Succeeded`

## Step 4: Fork and Clone the Repository

1. Fork the repository on GitHub
2. Clone your fork:

   ```bash
   git clone https://github.com/YOUR_USERNAME/uds-k3d-cilium.git
   cd uds-k3d-cilium
   ```

## Step 5: Build and Push the Tools Image

```bash
# Update the namespace to your GitHub username
cd tools
NAMESPACE="YOUR_GITHUB_USERNAME" ./build-tools-artifact.sh
```

This will:

- Create a multi-platform Docker image with all tools
- Push it to `ghcr.io/YOUR_GITHUB_USERNAME/uds-k3d-cilium-tools:latest`

## Step 6: Make the Package Visible

By default, packages pushed from the command line are private and won't show up in your packages list. You have two options:

### Option A: Make the Package Public (Recommended)

1. Go to `https://github.com/YOUR_USERNAME?tab=packages`
2. If you don't see the package, go directly to: `https://github.com/users/YOUR_USERNAME/packages`
3. Click on the `uds-k3d-cilium` package
4. Click "Package settings" (gear icon)
5. Scroll down to "Danger Zone"
6. Click "Change visibility" and select "Public"

### Option B: Keep Private but Link to Repository

The package will remain private but will be visible in your packages list if linked to a repository. Our Dockerfile already includes the necessary label:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/uds-k3d-cilium"
```

However, you still need to make it public for others to use it.

## Step 7: Install the Tools Locally

Now you can install the tools using ORAS:

```bash
# Install to ~/.local/bin (ORAS will be auto-installed if needed)
./use-tools-artifact.sh

# Or specify your namespace
NAMESPACE="YOUR_GITHUB_USERNAME" ./use-tools-artifact.sh

# If the package is private, authenticate first
export CR_PAT="YOUR_GITHUB_TOKEN"
./use-tools-artifact.sh
```

The script uses ORAS (OCI Registry As Storage) to pull platform-specific binaries from the container registry.

## Troubleshooting

### "unauthorized: authentication required"

This means you're not logged in. Run:

```bash
echo $CR_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

### "denied: permission_denied: write_package"

Your token doesn't have the correct permissions. Create a new token with `write:packages` scope.

### "name unknown: repository not found"

Make sure you're using the correct namespace (your GitHub username) and that you've pushed the image.

### Platform Issues

If you get platform mismatch errors, ensure your Docker Desktop has multi-platform support enabled:

1. Open Docker Desktop settings
2. Go to "Features in development"
3. Enable "Use containerd for pulling and storing images"

## Next Steps

1. Add the tools directory to your PATH:

   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. Verify all tools are working:

   ```bash
   uds version
   kubectl version --client
   k3d version
   cilium version
   ```

3. Create your first UDS k3d cluster:

   ```bash
   cd ..  # Back to project root
   uds run deploy
   ```
