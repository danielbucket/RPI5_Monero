# Wallet directory for Monero wallets

# This directory is mounted in the Docker container to persist wallet files

# IMPORTANT SECURITY NOTICE:

# - Wallet files contain sensitive cryptographic keys

# - Always backup your wallet files and mnemonic seed phrases

# - Use strong passwords for wallet encryption

# - Consider using hardware wallets for large amounts

# This directory will contain:

# - Wallet files (.wallet extension)

# - Wallet cache files

# - Wallet logs

# Usage:

# - Create new wallet: docker compose exec monero-miner-rpi5 monero-wallet-cli --generate-new-wallet /home/miner/.bitmonero/my-wallet --daemon-address monerod-rpi5:18081 --trusted-daemon

# - Access wallet: docker compose exec monero-miner-rpi5 monero-wallet-cli --wallet-file /home/miner/.bitmonero/my-wallet --daemon-address monerod-rpi5:18081 --trusted-daemon

# - Check CLI version: docker compose exec monero-miner-rpi5 monero-wallet-cli --version

# Security tips:

# 1. Regularly backup this entire directory

# 2. Store backups in multiple secure locations

# 3. Test wallet restoration periodically

# 4. Never share wallet files or passwords
