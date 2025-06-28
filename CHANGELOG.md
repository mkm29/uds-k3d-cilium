# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-06-28

### Added

- **CLI Tools Distribution System**: New comprehensive system for building and distributing CLI tools
  - Docker-based multi-platform image supporting linux/amd64, linux/arm64, darwin/amd64, darwin/arm64
  - ORAS (OCI Registry As Storage) artifact support for direct file distribution
  - Automatic tool installer script with platform detection
  - Bundled tools: UDS CLI (v0.27.7), Helm (v3.18.3), Cilium CLI (v0.18.4), Hubble CLI (v1.17.5), k3d (v5.8.3), kubectl (v1.33.2), k9s (v0.50.6)

- **Authentication Improvements**:
  - Automatic GitHub Container Registry (ghcr.io) authentication using CR_PAT environment variable
  - Unified authentication logic abstracted into `common.sh` for code reuse
  - Support for both Docker and ORAS authentication methods

- **ORAS Artifact Support**:
  - Platform-specific ORAS artifacts with proper file annotations
  - Each binary is a separate layer with metadata for efficient pulling
  - Linux-only artifacts (linux/amd64, linux/arm64) following OCI container conventions
  - Platform-specific tags (e.g., `v1.0.1-linux-amd64`) due to ORAS index limitations

- **Installation Features**:
  - Auto-installation of ORAS CLI if not present
  - Automatic jq installation for JSON parsing
  - Intelligent detection of Docker images vs ORAS artifacts
  - Fallback mechanisms for different artifact types

### Changed

- **Script Organization**:
  - Created `tools/common.sh` with shared functions for authentication, downloads, and platform detection
  - Refactored all tool scripts to use common functions, reducing code duplication
  - Improved error handling and user feedback across all scripts

### Technical Notes

- ORAS 1.2.3 doesn't support `manifest index create` command, so platform-specific tags are used instead of multi-platform indices
- Docker images support all platforms while ORAS artifacts are Linux-only (containers run on Linux)

## [0.1.1] - 2025-06-27

### Fixed

- Fixed Cilium installation by using the Cilium CLI directly instead of `zarf tools helm install`
  - `zarf tools helm` is a subset of Helm CLI that only includes repo and dependency management commands
  - The `install` command is not available in `zarf tools helm`, which was causing deployment failures
  - Now uses `cilium install` command with `--values` flag for custom configuration

### Changed

- Updated installation method from Helm-based to Cilium CLI-based installation
- Removed unnecessary helm repo add command as Cilium CLI manages this internally

## [0.1.0] - 2025-06-27

### Added

- `k3s` arguments:
  - Set `--flannel-backend=none` to disable deploying default Flannel CNI
  - Disable K3s network policies with `--disable-network-policy`
- Install Cilium v1.17.4 as cluster CNI (for advanced eBPF-based networking and observability)
- Enable kube-proxy replacement mode for optimal performance
- Use Cilium to provide L2 Announcements for LoadBalancer services
- Enable Cilium Ingress Controller as the default ingress solution
- Add Hubble observability with UI and relay for network visibility
- Enable WireGuard encryption for secure node-to-node communication
- Add SPIRE integration for mutual TLS authentication
- Configure Cilium with custom values from `values/cilium-values.yaml`
- Add `cilium-l2-ip-pool` component to configure L2 IP address pool
- Add configurable network CIDRs via variables: `SUBNET_CIDR`, `POD_CIDR`, `SERVICE_CIDR`
  - Subnet: `10.0.0.0/16` (K3d internal network)
  - Pod: `10.1.0.0/16` (Kubernetes pod network)
  - Service: `10.96.0.0/12` (Kubernetes service network)
- Add configurable cluster topology via variables: `NUMBER_OF_SERVERS`, `NUMBER_OF_AGENTS`
- Add configurable TLS SANs via `EXTRA_TLS_SANS` variable for custom API server certificate SANs
- Add optional Docker Hub authentication via `DOCKER_HUB_USERNAME` and `DOCKER_HUB_PASSWORD` variables
- Add `CILIUM_VERSION` variable to allow custom Cilium versions (default: v1.17.4)

### Changed

- Mount BPF and cgroup2 filesystems on all nodes for eBPF support
- Install Cilium using the official Helm chart during cluster creation
  - Due to how Zarf operates, this step must be part of the `create-cluster` component as there will be no CNI until Cilium is installed
- Cilium configuration values:
  - Configure Cilium with kube-proxy replacement enabled (`kubeProxyReplacement: true`)
  - Enable L2 announcements for `LoadBalancer` service support
  - Enable Hubble for network observability with metrics collection
  - Configure `WireGuard` encryption for pod-to-pod communication
  - Enable `SPIRE` for service identity and mutual TLS
  - Use Cilium's built-in ingress controller as default
- Added `destroy` task in `tasks.yaml` that safely lists clusters or removes a specific cluster when `CLUSTER_NAME` is provided
- Updated k3d cluster creation to use variable references for network `CIDR`s and node counts
- Registry authentication uses Zarf template variables in `registries.yaml.tmpl` (optional: used to prevent rate-limiting from Docker Hub)
- Added automatic processing of registry configuration template during cluster creation
- Registry configuration flag only added when credentials are provided (`--registry-config`)

### Bug Fixes

* Fixed cluster networking by properly mounting BPF filesystem before Cilium installation
* Ensured proper node configuration for eBPF dataplane requirements
