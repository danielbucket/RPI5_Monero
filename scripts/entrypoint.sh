#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Monero Mining & Wallet Container for Raspberry Pi 5 ===${NC}"
echo -e "${GREEN}Available tools: XMRig miner + Monero CLI wallet tools${NC}"

# Check if this is a wallet operation
if [ "$1" = "wallet" ]; then
    echo -e "${BLUE}Starting wallet manager...${NC}"
    shift  # Remove 'wallet' from arguments
    exec /home/miner/scripts/wallet-manager.sh "$@"
fi

# Check if this is a direct CLI wallet call
if [ "$1" = "monero-wallet-cli" ]; then
    echo -e "${BLUE}Starting Monero CLI wallet...${NC}"
    shift  # Remove 'monero-wallet-cli' from arguments
    exec /opt/monero/monero-wallet-cli "$@"
fi

# Check if this is a wallet RPC call
if [ "$1" = "monero-wallet-rpc" ]; then
    echo -e "${BLUE}Starting Monero Wallet RPC...${NC}"
    shift  # Remove 'monero-wallet-rpc' from arguments
    exec /opt/monero/monero-wallet-rpc "$@"
fi

echo -e "${BLUE}Starting XMRig miner...${NC}"

# Check required environment variables
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${RED}ERROR: WALLET_ADDRESS environment variable is required${NC}"
    echo -e "${YELLOW}Please set your Monero wallet address in the .env file${NC}"
    exit 1
fi

if [ -z "$POOL_URL" ]; then
    echo -e "${RED}ERROR: POOL_URL environment variable is required${NC}"
    echo -e "${YELLOW}Please set your mining pool URL in the .env file${NC}"
    exit 1
fi

# Set defaults for optional variables
WORKER_NAME=${WORKER_NAME:-"rpi5-fullstack-miner-optimized"}
POOL_PASSWORD=${POOL_PASSWORD:-"x"}
CPU_THREADS=${CPU_THREADS:-3}
CPU_PRIORITY=${CPU_PRIORITY:-4}
HUGE_PAGES=${HUGE_PAGES:-false}
RANDOMX_MODE=${RANDOMX_MODE:-"auto"}
LOG_LEVEL=${LOG_LEVEL:-2}
API_ENABLED=${API_ENABLED:-true}
API_PORT=${API_PORT:-8080}

echo -e "${GREEN}Configuration:${NC}"
echo -e "  Pool URL: ${POOL_URL}"
echo -e "  Wallet: ${WALLET_ADDRESS:0:10}...${WALLET_ADDRESS: -10}"
echo -e "  Worker: ${WORKER_NAME}"
echo -e "  CPU Threads: ${CPU_THREADS}"
echo -e "  CPU Priority: ${CPU_PRIORITY}"
echo -e "  RandomX Mode: ${RANDOMX_MODE}"
echo -e "  API Enabled: ${API_ENABLED}"

# Create config from template
CONFIG_FILE="/home/miner/.xmrig/config.json"
TEMPLATE_FILE="/home/miner/.xmrig/config.template.json"

if [ -f "$TEMPLATE_FILE" ]; then
    echo -e "${BLUE}Generating configuration from template...${NC}"
    
    # Copy template and replace placeholders
    cp "$TEMPLATE_FILE" "$CONFIG_FILE"
    
    # Replace placeholders with environment variables
    sed -i "s|POOL_URL_PLACEHOLDER|${POOL_URL}|g" "$CONFIG_FILE"
    sed -i "s|WALLET_ADDRESS_PLACEHOLDER|${WALLET_ADDRESS}|g" "$CONFIG_FILE"
    sed -i "s|POOL_PASSWORD_PLACEHOLDER|${POOL_PASSWORD}|g" "$CONFIG_FILE"
    sed -i "s|WORKER_NAME_PLACEHOLDER|${WORKER_NAME}|g" "$CONFIG_FILE"
    
    # Update CPU threads configuration
    python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
cpu_threads = int('$CPU_THREADS')
cpu_priority = int('$CPU_PRIORITY')
huge_pages = '$HUGE_PAGES'.lower() == 'true'
randomx_mode = '$RANDOMX_MODE'
api_enabled = '$API_ENABLED'.lower() == 'true'
api_port = int('$API_PORT')

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Update CPU configuration
    config['cpu']['priority'] = cpu_priority
    config['cpu']['huge-pages'] = huge_pages
    config['randomx']['mode'] = randomx_mode
    
    # Update HTTP API configuration
    config['http']['enabled'] = api_enabled
    config['http']['port'] = api_port
    
    # Set CPU threads - create thread list for Raspberry Pi 5
    if cpu_threads > 0:
        thread_list = list(range(cpu_threads))
        config['cpu']['rx'] = thread_list
        config['cpu']['rx/wow'] = thread_list
        config['cpu']['cn/2'] = thread_list
        config['cpu']['cn/r'] = thread_list
        config['cpu']['cn-pico'] = thread_list
        config['cpu']['cn-heavy'] = thread_list
        config['cpu']['max-threads-hint'] = max(75, cpu_threads * 25)
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=4)
        
    print('Configuration updated successfully')
except Exception as e:
    print(f'Error updating configuration: {e}', file=sys.stderr)
    sys.exit(1)
"
else
    echo -e "${YELLOW}Warning: Template file not found, using existing config${NC}"
fi

# Ensure log directory exists and is writable
mkdir -p /var/log/miner
touch /var/log/miner/xmrig.log

# Display system information
echo -e "${BLUE}System Information:${NC}"
echo -e "  CPU: $(nproc) cores available"
echo -e "  Memory: $(free -h | awk '/^Mem:/ {print $2}') total"
echo -e "  Architecture: $(uname -m)"

# Display mining pool information
echo -e "${BLUE}Mining Pool Information:${NC}"
echo -e "  URL: ${POOL_URL}"
echo -e "  Algorithm: RandomX (Monero)"

# Function to handle shutdown gracefully
shutdown_handler() {
    echo -e "\n${YELLOW}Received shutdown signal, stopping miner gracefully...${NC}"
    if [ ! -z "$XMRIG_PID" ]; then
        kill -TERM "$XMRIG_PID" 2>/dev/null || true
        wait "$XMRIG_PID" 2>/dev/null || true
    fi
    echo -e "${GREEN}Miner stopped successfully${NC}"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Start XMRig
echo -e "${GREEN}Starting XMRig miner...${NC}"
echo -e "${BLUE}Monitor your mining at: http://localhost:${API_PORT}${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop mining${NC}"

# Start XMRig in background so we can handle signals
/opt/xmrig/xmrig "$@" &
XMRIG_PID=$!

# Wait for XMRig to finish
wait $XMRIG_PID