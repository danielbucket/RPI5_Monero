# Multi-stage Dockerfile for Monero Mining on Raspberry Pi 5 (ARM64)
FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  cmake \
  git \
  wget \
  ca-certificates \
  pkg-config \
  libssl-dev \
  libhwloc-dev \
  libuv1-dev \
  && rm -rf /var/lib/apt/lists/*

# Download and build XMRig for ARM64 (optimized for Raspberry Pi)
WORKDIR /tmp
RUN git clone https://github.com/xmrig/xmrig.git
WORKDIR /tmp/xmrig
RUN mkdir build && cd build && \
  cmake .. -DCMAKE_BUILD_TYPE=Release -DWITH_HWLOC=ON && \
  make -j$(nproc)

# Download Monero CLI tools for ARM64
WORKDIR /tmp
RUN wget https://downloads.getmonero.org/cli/monero-linux-armv8-v0.18.4.2.tar.bz2 && \
  tar -xjf monero-linux-armv8-v0.18.4.2.tar.bz2 && \
  ls -la && \
  ls -la monero-*/ && \
  mv monero-*-v0.18.4.2 monero-cli

# Production stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
  wget \
  ca-certificates \
  libhwloc15 \
  libuv1 \
  htop \
  curl \
  python3 \
  python3-pip \
  jq \
  nano \
  screen \
  && rm -rf /var/lib/apt/lists/*

# Create user for mining with matching UID for proper file permissions
RUN useradd -m -s /bin/bash -u 1000 miner

# Create directories
RUN mkdir -p /opt/xmrig /opt/monero /var/log/miner /home/miner/.bitmonero

# Copy XMRig binary from builder stage
COPY --from=builder /tmp/xmrig/build/xmrig /opt/xmrig/

# Copy Monero CLI tools from builder stage  
COPY --from=builder /tmp/monero-cli/monero-wallet-cli /opt/monero/
COPY --from=builder /tmp/monero-cli/monero-wallet-rpc /opt/monero/
COPY --from=builder /tmp/monero-cli/monero-gen-trusted-multisig /opt/monero/

RUN chmod +x /opt/xmrig/xmrig /opt/monero/*

# Set ownership for all /opt directories after miner user is created
RUN chown -R miner:miner /opt/xmrig /opt/monero /var/log/miner /home/miner/.bitmonero

# Add Monero tools to PATH
ENV PATH="/opt/monero:${PATH}"

# Note: Monero CLI tools now included in container for wallet management
# The miner can run XMRig AND provide wallet CLI access

# Switch to miner user# Switch to miner user
USER miner
WORKDIR /home/miner

# Create config directory
RUN mkdir -p /home/miner/.xmrig /home/miner/.bitmonero

# Copy configuration files
COPY --chown=miner:miner config/ /home/miner/.xmrig/
COPY --chown=miner:miner scripts/ /home/miner/scripts/

# Make scripts executable
RUN chmod +x /home/miner/scripts/*.sh

# Set environment variables optimized for 16GB Raspberry Pi 5
ENV POOL_URL=""
ENV WALLET_ADDRESS=""
ENV WORKER_NAME="rpi5-fullstack-miner-optimized"
ENV CPU_THREADS=3
ENV CPU_PRIORITY=4
ENV HUGE_PAGES=false
ENV RANDOMX_MODE=auto
ENV LOG_LEVEL=2

# Wallet-related environment variables
ENV WALLET_NAME="mining-wallet"
# Note: WALLET_PASSWORD should be provided at runtime for security
ENV DAEMON_HOST="node.supportxmr.com"
ENV DAEMON_PORT="18081"
ENV RESTORE_HEIGHT=""

# Expose monitoring port and wallet RPC port
EXPOSE 8080 18082

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/1/summary || exit 1

# Entry point
ENTRYPOINT ["/home/miner/scripts/entrypoint.sh"]
CMD ["--config=/home/miner/.xmrig/config.json"]