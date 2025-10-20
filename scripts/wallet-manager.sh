#!/bin/bash

# Monero Wallet Management Script for Raspberry Pi 5
# This script provides wallet creation, restoration, and management functions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WALLET_DIR="/home/miner/.bitmonero"
DAEMON_HOST=${DAEMON_HOST:-"node.supportxmr.com"}
DAEMON_PORT=${DAEMON_PORT:-"18081"}
WALLET_NAME=${WALLET_NAME:-"mining-wallet"}

# Function to display usage
show_usage() {
    echo -e "${BLUE}=== Monero Wallet Manager ===${NC}"
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  create        Create a new wallet"
    echo "  restore       Restore wallet from mnemonic seed"
    echo "  open          Open existing wallet"
    echo "  balance       Check wallet balance"
    echo "  address       Show wallet address"
    echo "  transfer      Send Monero (interactive)"
    echo "  status        Show wallet and daemon status"
    echo "  help          Show this help message"
    echo
    echo "Environment Variables:"
    echo "  WALLET_NAME     - Wallet filename (default: mining-wallet)"
    echo "  WALLET_PASSWORD - Wallet password (prompted if not set)"
    echo "  DAEMON_HOST     - Daemon host (default: node.supportxmr.com)"
    echo "  DAEMON_PORT     - Daemon port (default: 18081)"
    echo "  RESTORE_HEIGHT  - Block height for wallet restore"
}

# Function to check if daemon is accessible
check_daemon() {
    echo -e "${BLUE}Checking daemon connectivity...${NC}"
    if curl -s --connect-timeout 10 "http://${DAEMON_HOST}:${DAEMON_PORT}/get_info" > /dev/null; then
        echo -e "${GREEN}✓ Daemon is accessible at ${DAEMON_HOST}:${DAEMON_PORT}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Warning: Cannot connect to daemon at ${DAEMON_HOST}:${DAEMON_PORT}${NC}"
        echo -e "${YELLOW}  Wallet operations may be limited${NC}"
        return 1
    fi
}

# Function to prompt for password securely
get_password() {
    if [ -z "$WALLET_PASSWORD" ]; then
        echo -n "Enter wallet password: "
        read -s WALLET_PASSWORD
        echo
        if [ -z "$WALLET_PASSWORD" ]; then
            echo -e "${RED}Error: Password cannot be empty${NC}"
            exit 1
        fi
    fi
}

# Function to create a new wallet
create_wallet() {
    echo -e "${BLUE}=== Creating New Wallet ===${NC}"
    
    get_password
    
    echo -e "${YELLOW}Creating wallet: ${WALLET_NAME}${NC}"
    echo -e "${YELLOW}This will generate a new mnemonic seed phrase.${NC}"
    echo -e "${RED}IMPORTANT: Write down your seed phrase and store it safely!${NC}"
    echo
    
    # Create wallet directory if it doesn't exist
    mkdir -p "$WALLET_DIR"
    
    # Run wallet creation
    /opt/monero/monero-wallet-cli \
        --daemon-address "${DAEMON_HOST}:${DAEMON_PORT}" \
        --generate-new-wallet "${WALLET_DIR}/${WALLET_NAME}" \
        --password "$WALLET_PASSWORD" \
        --mnemonic-language English \
        --command exit
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Wallet created successfully!${NC}"
        echo -e "${BLUE}Wallet location: ${WALLET_DIR}/${WALLET_NAME}${NC}"
        
        # Show address
        get_address
    else
        echo -e "${RED}✗ Failed to create wallet${NC}"
        exit 1
    fi
}

# Function to restore wallet from seed
restore_wallet() {
    echo -e "${BLUE}=== Restoring Wallet from Seed ===${NC}"
    
    get_password
    
    echo -e "${YELLOW}Restoring wallet: ${WALLET_NAME}${NC}"
    echo "Enter your 25-word mnemonic seed phrase:"
    echo "(Words should be separated by spaces)"
    echo -n "Seed: "
    read -r MNEMONIC_SEED
    
    if [ -z "$MNEMONIC_SEED" ]; then
        echo -e "${RED}Error: Mnemonic seed cannot be empty${NC}"
        exit 1
    fi
    
    # Ask for restore height
    if [ -z "$RESTORE_HEIGHT" ]; then
        echo -e "${YELLOW}Enter restore height (block number when wallet was created):${NC}"
        echo -e "${YELLOW}If unsure, press Enter to scan from beginning (slower)${NC}"
        echo -n "Restore height: "
        read -r RESTORE_HEIGHT
    fi
    
    # Create wallet directory if it doesn't exist
    mkdir -p "$WALLET_DIR"
    
    # Prepare restore command
    RESTORE_CMD="/opt/monero/monero-wallet-cli \
        --daemon-address \"${DAEMON_HOST}:${DAEMON_PORT}\" \
        --generate-from-mnemonic \"${WALLET_DIR}/${WALLET_NAME}\" \
        --password \"$WALLET_PASSWORD\" \
        --mnemonic-language English"
    
    if [ -n "$RESTORE_HEIGHT" ]; then
        RESTORE_CMD="$RESTORE_CMD --restore-height $RESTORE_HEIGHT"
    fi
    
    echo -e "${BLUE}Starting wallet restoration...${NC}"
    echo -e "${YELLOW}You will be prompted to enter your seed phrase again.${NC}"
    
    # Run restoration (interactive)
    eval "$RESTORE_CMD"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Wallet restored successfully!${NC}"
        get_address
    else
        echo -e "${RED}✗ Failed to restore wallet${NC}"
        exit 1
    fi
}

# Function to open existing wallet
open_wallet() {
    echo -e "${BLUE}=== Opening Wallet ===${NC}"
    
    if [ ! -f "${WALLET_DIR}/${WALLET_NAME}" ]; then
        echo -e "${RED}Error: Wallet file not found: ${WALLET_DIR}/${WALLET_NAME}${NC}"
        echo -e "${YELLOW}Available wallets:${NC}"
        ls -la "${WALLET_DIR}/" 2>/dev/null | grep -v "^d" || echo "No wallets found"
        exit 1
    fi
    
    get_password
    
    echo -e "${YELLOW}Opening wallet: ${WALLET_NAME}${NC}"
    
    /opt/monero/monero-wallet-cli \
        --daemon-address "${DAEMON_HOST}:${DAEMON_PORT}" \
        --wallet-file "${WALLET_DIR}/${WALLET_NAME}" \
        --password "$WALLET_PASSWORD"
}

# Function to get wallet address
get_address() {
    echo -e "${BLUE}=== Wallet Address ===${NC}"
    
    if [ ! -f "${WALLET_DIR}/${WALLET_NAME}" ]; then
        echo -e "${RED}Error: Wallet file not found${NC}"
        exit 1
    fi
    
    get_password
    
    ADDRESS=$(/opt/monero/monero-wallet-cli \
        --daemon-address "${DAEMON_HOST}:${DAEMON_PORT}" \
        --wallet-file "${WALLET_DIR}/${WALLET_NAME}" \
        --password "$WALLET_PASSWORD" \
        --command "address" \
        --command "exit" 2>/dev/null | grep "^4" | head -1)
    
    if [ -n "$ADDRESS" ]; then
        echo -e "${GREEN}Wallet Address:${NC}"
        echo "$ADDRESS"
        echo
        echo -e "${BLUE}Use this address for mining pool configuration${NC}"
    else
        echo -e "${RED}Failed to retrieve wallet address${NC}"
        exit 1
    fi
}

# Function to check balance
check_balance() {
    echo -e "${BLUE}=== Wallet Balance ===${NC}"
    
    if [ ! -f "${WALLET_DIR}/${WALLET_NAME}" ]; then
        echo -e "${RED}Error: Wallet file not found${NC}"
        exit 1
    fi
    
    get_password
    
    echo -e "${YELLOW}Refreshing wallet and checking balance...${NC}"
    
    /opt/monero/monero-wallet-cli \
        --daemon-address "${DAEMON_HOST}:${DAEMON_PORT}" \
        --wallet-file "${WALLET_DIR}/${WALLET_NAME}" \
        --password "$WALLET_PASSWORD" \
        --command "refresh" \
        --command "balance" \
        --command "exit"
}

# Function to show status
show_status() {
    echo -e "${BLUE}=== Wallet and Daemon Status ===${NC}"
    
    # Check daemon
    check_daemon
    
    echo
    echo -e "${BLUE}Wallet Information:${NC}"
    echo -e "  Name: ${WALLET_NAME}"
    echo -e "  Location: ${WALLET_DIR}/${WALLET_NAME}"
    
    if [ -f "${WALLET_DIR}/${WALLET_NAME}" ]; then
        echo -e "  Status: ${GREEN}Exists${NC}"
        echo -e "  Size: $(du -h "${WALLET_DIR}/${WALLET_NAME}" | cut -f1)"
        echo -e "  Modified: $(stat -c %y "${WALLET_DIR}/${WALLET_NAME}" 2>/dev/null || stat -f %Sm "${WALLET_DIR}/${WALLET_NAME}")"
    else
        echo -e "  Status: ${RED}Not found${NC}"
    fi
    
    echo
    echo -e "${BLUE}Available Wallets:${NC}"
    if [ -d "$WALLET_DIR" ]; then
        ls -la "$WALLET_DIR"/ 2>/dev/null | grep -v "^d" | grep -v "^total" || echo "No wallets found"
    else
        echo "Wallet directory does not exist"
    fi
}

# Main script logic
case "${1:-help}" in
    create)
        check_daemon
        create_wallet
        ;;
    restore)
        check_daemon
        restore_wallet
        ;;
    open)
        check_daemon
        open_wallet
        ;;
    address)
        get_address
        ;;
    balance)
        check_daemon
        check_balance
        ;;
    transfer)
        check_daemon
        echo -e "${BLUE}Opening wallet for transfer...${NC}"
        open_wallet
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$1'${NC}"
        echo
        show_usage
        exit 1
        ;;
esac