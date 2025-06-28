# Multi-stage Dockerfile to collect all required CLI tools
FROM alpine:3.22.0 AS builder

# Install necessary build tools
RUN apk add --no-cache curl wget tar gzip

# Set up architecture and OS detection
ARG TARGETARCH
ARG TARGETOS
ARG TARGETVARIANT

# Create directory for binaries
RUN mkdir -p /tools/bin

# Install UDS CLI
ARG UDS_VERSION=v0.27.7
RUN wget -q https://github.com/defenseunicorns/uds-cli/releases/download/${UDS_VERSION}/uds-cli_${UDS_VERSION}_${TARGETOS}_${TARGETARCH} -O /tools/bin/uds && \
    chmod +x /tools/bin/uds

# Install Helm
ARG HELM_VERSION=v3.18.3
RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz -O helm.tar.gz && \
    tar -xzf helm.tar.gz && \
    # Helm extracts to OS-ARCH directory
    mv ${TARGETOS}-${TARGETARCH}/helm /tools/bin/helm && \
    chmod +x /tools/bin/helm && \
    rm -rf helm.tar.gz ${TARGETOS}-${TARGETARCH}

# # Install Cilium CLI
ARG CILIUM_CLI_VERSION=v0.18.4
RUN wget -q https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${TARGETOS}-${TARGETARCH}.tar.gz -O cilium.tar.gz && \
    tar -xzf cilium.tar.gz -C /tools/bin && \
    chmod +x /tools/bin/cilium && \
    rm cilium.tar.gz

# # Install Hubble CLI
ARG HUBBLE_VERSION=v1.17.5
RUN wget -q https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-${TARGETOS}-${TARGETARCH}.tar.gz -O hubble.tar.gz && \
    tar -xzf hubble.tar.gz -C /tools/bin && \
    chmod +x /tools/bin/hubble && \
    rm hubble.tar.gz

# # Install k3d
ARG K3D_VERSION=v5.8.3
RUN wget -q https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-${TARGETOS}-${TARGETARCH} -O /tools/bin/k3d && \
    chmod +x /tools/bin/k3d

# # Install kubectl
ARG KUBECTL_VERSION=v1.33.2
RUN wget -q https://dl.k8s.io/${KUBECTL_VERSION}/kubernetes-client-${TARGETOS}-${TARGETARCH}.tar.gz -O kubectl.tar.gz && \
    tar -xzf kubectl.tar.gz && \
    mv kubernetes/client/bin/kubectl /tools/bin/kubectl && \
    chmod +x /tools/bin/kubectl && \
    rm -rf kubectl.tar.gz kubernetes/

# # Install k9s
ARG K9S_VERSION=v0.50.6
RUN wget -q https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${TARGETOS}_${TARGETARCH}.tar.gz -O k9s.tar.gz && \
    tar -xzf k9s.tar.gz -C /tools/bin k9s && \
    chmod +x /tools/bin/k9s && \
    rm k9s.tar.gz

# Final stage - minimal image with just the tools
FROM scratch
COPY --from=builder /tools/bin /bin/

# Add metadata
LABEL maintainer="Mitchell Murphy <mitchell.murphy@defenseunicorns.com>" \
    org.opencontainers.image.title="UDS k3d Cilium Tools" \
    org.opencontainers.image.description="CLI tools required for UDS k3d Cilium deployment - Multi-platform support for linux/amd64, linux/arm64, darwin/amd64, darwin/arm64" \
    org.opencontainers.image.version="v1.0.0" \
    org.opencontainers.image.authors="UDS k3d Cilium Maintainers" \
    org.opencontainers.image.source="https://github.com/mkm29/uds-k3d-cilium" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.url="https://github.com/mkm29/uds-k3d-cilium" \
    org.opencontainers.image.documentation="https://github.com/mkm29/uds-k3d-cilium/blob/main/tools/README.md" \
    io.artifacthub.package.readme-url="https://raw.githubusercontent.com/mkm29/uds-k3d-cilium/main/README.md"