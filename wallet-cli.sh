#!/bin/bash
# Launch Monero wallet CLI with persistent daemon address

docker compose exec monero-miner-rpi5 monero-wallet-cli --wallet-file /home/miner/.bitmonero/rpi5-01-wallet --daemon-address monerod-rpi5:18081 "$@"
