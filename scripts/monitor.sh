#!/bin/bash

# Mining status monitoring script for Raspberry Pi 5
# This script provides quick monitoring of your Monero mining operation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_HOST=${API_HOST:-localhost}
API_PORT=${API_PORT:-8080}

echo -e "${BLUE}=== Monero Miner Status (Raspberry Pi 5) ===${NC}"

# Check if API is accessible
if ! curl -s "http://${API_HOST}:${API_PORT}/1/summary" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot connect to miner API at http://${API_HOST}:${API_PORT}${NC}"
    echo -e "${YELLOW}Make sure the miner is running and API is enabled${NC}"
    exit 1
fi

# Get miner summary
SUMMARY=$(curl -s "http://${API_HOST}:${API_PORT}/1/summary")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Miner is running!${NC}"
    echo
    
    # Parse and display key metrics using Python
    echo "$SUMMARY" | python3 -c "
import json
import sys
from datetime import datetime, timedelta

try:
    data = json.load(sys.stdin)
    
    # Connection info
    connection = data.get('connection', {})
    pool = connection.get('pool', 'Unknown')
    uptime = data.get('uptime', 0)
    
    # Hashrate info
    hashrate = data.get('hashrate', {})
    current_hr = hashrate.get('total', [0, 0, 0])
    
    # Results info
    results = data.get('results', {})
    shares_good = results.get('shares_good', 0)
    shares_total = results.get('shares_total', 0)
    avg_time = results.get('avg_time', 0)
    
    # CPU info
    cpu = data.get('cpu', {})
    threads = cpu.get('threads', 0)
    
    # Format uptime
    uptime_str = str(timedelta(seconds=uptime))
    
    # Calculate acceptance rate
    acceptance_rate = (shares_good / shares_total * 100) if shares_total > 0 else 0
    
    print('Pool: {}'.format(pool))
    print('Uptime: {}'.format(uptime_str))
    print('Threads: {}'.format(threads))
    if len(current_hr) >= 3:
        print('Hashrate (10s/60s/15m): {:.1f} / {:.1f} / {:.1f} H/s'.format(current_hr[0] or 0, current_hr[1] or 0, current_hr[2] or 0))
    else:
        print('Hashrate: {} H/s'.format(current_hr[0] if current_hr and current_hr[0] else 0))
    print('Shares: {} accepted, {} rejected ({:.1f}% accepted)'.format(shares_good, shares_total - shares_good, acceptance_rate))
    if avg_time > 0:
        print('Average share time: {}s'.format(avg_time))
    
except Exception as e:
    print('Error parsing miner data: {}'.format(e))
    sys.exit(1)
"
    
    echo
    echo -e "${BLUE}System Resources:${NC}"
    
    # Display CPU and memory usage
    echo -e "CPU Usage: $(top -bn1 | grep '%Cpu' | awk '{print $2}' | cut -d'%' -f1)%"
    echo -e "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    echo -e "Temperature: $(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo 'N/A')"
    
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  View logs: docker-compose logs -f monero-miner"
    echo -e "  Restart: docker-compose restart monero-miner"
    echo -e "  Stop: docker-compose down"
    echo -e "  Monitor: watch -n5 ./scripts/monitor.sh"
else
    echo -e "${RED}Failed to get miner status${NC}"
    exit 1
fi