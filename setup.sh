#!/bin/bash

# Quick setup script for Monero mining with integrated wallet
# This script helps automate the initial setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Monero Mining & Wallet Setup for Raspberry Pi 5 ===${NC}"
echo

# Check if Docker and Docker Compose are installed
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: Docker is not installed${NC}"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Error: Docker Compose is not installed${NC}"; exit 1; }

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file${NC}"
    echo -e "${BLUE}Please edit the .env file to configure your settings${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Check if wallet address is configured
if grep -q "your_monero_wallet_address_here" .env 2>/dev/null; then
    echo -e "${YELLOW}⚠ Warning: Wallet address not configured in .env file${NC}"
    
    read -p "Do you want to create a new wallet now? (y/N): " create_wallet
    if [[ $create_wallet =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Building container (this may take a while on first run)...${NC}"
        docker-compose build
        
        echo -e "${BLUE}Creating new wallet...${NC}"
        docker-compose run --rm monero-miner wallet create
        
        echo -e "${YELLOW}Please update the WALLET_ADDRESS in your .env file with the address shown above${NC}"
    else
        echo -e "${YELLOW}Please configure your wallet address in the .env file before starting mining${NC}"
    fi
else
    echo -e "${GREEN}✓ Wallet address is configured${NC}"
fi

# Check if directories exist
echo -e "${BLUE}Checking directory structure...${NC}"
for dir in "config" "scripts" "logs" "wallets"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $dir directory exists${NC}"
    else
        echo -e "${RED}✗ $dir directory missing${NC}"
    fi
done

# Make scripts executable
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}✓ Scripts are executable${NC}"

echo
echo -e "${BLUE}=== Setup Summary ===${NC}"
echo -e "${GREEN}Your Monero mining container is ready!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Edit .env file with your configuration:"
echo "   - Set WALLET_ADDRESS to your Monero wallet address"
echo "   - Choose your mining pool (POOL_URL)"
echo "   - Adjust performance settings if needed"
echo
echo "2. Start mining:"
echo "   docker-compose up -d"
echo
echo "3. Monitor your mining:"
echo "   ./scripts/monitor.sh"
echo
echo "4. Manage your wallet:"
echo "   docker-compose exec monero-miner wallet help"
echo
echo -e "${YELLOW}Important Security Notes:${NC}"
echo "- Always backup your wallet files and mnemonic seeds"
echo "- Use strong passwords for wallet encryption"
echo "- Monitor system temperature during mining"
echo "- Consider the power consumption and profitability"
echo
echo -e "${GREEN}Happy mining! 🚀${NC}"