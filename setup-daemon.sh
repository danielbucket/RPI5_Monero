#!/bin/bash

# Monero Full Stack Setup and Management Script
# Full daemon + miner + monitoring for Raspberry Pi 5
# Usage: ./setup-daemon.sh [start|stop|clean|status]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display usage
show_usage() {
    echo -e "${BLUE}=== Monero Full Stack Management ===${NC}"
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  start      Start full stack (miner + daemon + monitoring)"
    echo "  stop       Stop all services"
    echo "  restart    Restart all services"
    echo "  status     Show service status"
    echo "  logs       Follow service logs"
    echo "  clean      Clean up all data (WARNING: removes blockchain)"
    echo
    echo "This setup includes:"
    echo "  - XMRig miner (monero-miner-rpi5)"
    echo "  - Full Monero daemon (monerod-rpi5) - ~200GB blockchain"
    echo "  - Prometheus monitoring"
    echo "  - Grafana dashboards"
    echo "  - System monitoring (node-exporter, cadvisor)"
    echo
}

# Function to check system requirements
check_requirements() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    # Check available memory
    TOTAL_MEM=$(free -g | awk 'NR==2{print $2}')
    if [ "$TOTAL_MEM" -lt 8 ]; then
        echo -e "${YELLOW}Warning: Less than 8GB RAM detected. Consider using option3 (minimal).${NC}"
    fi
    
    # Check available disk space
    AVAIL_SPACE=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$AVAIL_SPACE" -lt 50 ]; then
        echo -e "${YELLOW}Warning: Less than 50GB free space. Consider using option3 (pruned).${NC}"
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ System check passed${NC}"
}

# Function to setup blockchain data directory
setup_blockchain_dir() {
    echo -e "${BLUE}Setting up blockchain data directory...${NC}"
    mkdir -p ./blockchain-data
    chmod 755 ./blockchain-data
    echo -e "${GREEN}✓ Blockchain directory created${NC}"
}

# Function to create environment file
create_env_file() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}Creating .env file...${NC}"
        cat > .env << EOF
# Mining Configuration - Optimized for 16GB Pi 5
POOL_URL=pool.supportxmr.com:3333
WALLET_ADDRESS=YOUR_WALLET_ADDRESS_HERE
WORKER_NAME=rpi5-fullstack-miner-optimized
CPU_THREADS=3
CPU_PRIORITY=4
POOL_PASSWORD=x

# API Configuration
API_ENABLED=true
API_PORT=8080

# Monitoring (for option4)
GRAFANA_PASSWORD=admin123
EOF
        echo -e "${YELLOW}Please edit .env file with your wallet address${NC}"
    fi
}

# Function to start services
start_services() {
    local compose_file=$1
    echo -e "${BLUE}Starting services with $compose_file...${NC}"
    
    docker-compose -f "$compose_file" up -d
    
    echo -e "${GREEN}✓ Services started successfully${NC}"
    echo -e "${BLUE}Checking service status...${NC}"
    
    docker-compose -f "$compose_file" ps
}

# Function to show access URLs
show_access_info() {
    echo -e "${GREEN}=== Access Information ===${NC}"
    echo -e "${BLUE}Mining API:${NC} http://192.168.1.12:8080/1/summary"
    echo -e "${BLUE}Monero Daemon:${NC} http://192.168.1.12:18081/get_info"
    echo -e "${BLUE}Prometheus:${NC} http://192.168.1.12:9090"
    echo -e "${BLUE}Grafana:${NC} http://192.168.1.12:3000 (admin/admin123)"
    echo
    echo -e "${YELLOW}Container Status:${NC}"
    echo -e "  • ${GREEN}monero-miner-rpi5${NC} - XMRig miner"
    echo -e "  • ${GREEN}monerod-rpi5${NC} - Full Monero daemon (~200GB)"
    echo -e "  • ${GREEN}prometheus${NC} - Metrics collection"
    echo -e "  • ${GREEN}grafana${NC} - Monitoring dashboards"
    echo
    echo -e "${YELLOW}Note: Initial blockchain sync will take 4-8 hours (~200GB).${NC}"
    echo -e "${YELLOW}Monitor progress: docker-compose logs -f monerod-rpi5${NC}"
}

# Main execution
case "${1:-help}" in
    start)
        echo -e "${GREEN}Starting Monero Full Stack${NC}"
        check_requirements
        setup_blockchain_dir
        create_env_file
        start_services "docker-compose.yml"
        show_access_info "fullstack"
        ;;
    stop)
        echo -e "${YELLOW}Stopping all services...${NC}"
        docker-compose down
        echo -e "${GREEN}✓ All services stopped${NC}"
        ;;
    restart)
        echo -e "${YELLOW}Restarting all services...${NC}"
        docker-compose down
        docker-compose up -d
        echo -e "${GREEN}✓ All services restarted${NC}"
        ;;
    status)
        echo -e "${BLUE}Service Status:${NC}"
        docker-compose ps
        echo
        echo -e "${BLUE}Container Health:${NC}"
        docker-compose exec -T monerod-rpi5 curl -f http://localhost:18081/get_info 2>/dev/null | jq '.synchronized' || echo "Daemon not ready yet"
        ;;
    logs)
        echo -e "${BLUE}Following service logs (Ctrl+C to exit):${NC}"
        docker-compose logs -f
        ;;
    clean)
        echo -e "${RED}WARNING: This will remove all blockchain data (~200GB)!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker-compose down -v 2>/dev/null || true
            docker volume prune -f
            rm -rf ./blockchain-data ./logs/*
            echo -e "${GREEN}✓ Cleanup completed${NC}"
        else
            echo "Cleanup cancelled"
        fi
        ;;
    help|--help|-h|*)
        show_usage
        exit 0
        ;;
esac