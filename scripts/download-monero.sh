#!/bin/bash
set -e

echo "=== Monero ARM64 Binary Download Script ==="

# Variables
MONERO_VERSION="0.18.4.2"
DOWNLOAD_URL="https://downloads.getmonero.org/cli/monero-linux-armv8-v${MONERO_VERSION}.tar.bz2"
ARCHIVE_NAME="monero-arm64.tar.bz2"
DEST_DIR="/opt/monero"

echo "Downloading Monero ARM64 v${MONERO_VERSION}..."
echo "URL: ${DOWNLOAD_URL}"

# Download with retries
for i in {1..3}; do
    echo "Download attempt ${i}/3..."
    if wget --no-check-certificate --timeout=30 --tries=3 -O "${ARCHIVE_NAME}" "${DOWNLOAD_URL}"; then
        echo "Download successful!"
        break
    else
        echo "Download attempt ${i} failed."
        if [ $i -eq 3 ]; then
            echo "All download attempts failed. Exiting."
            exit 1
        fi
        sleep 5
    fi
done

# Verify download
if [ ! -f "${ARCHIVE_NAME}" ]; then
    echo "Error: Archive file not found after download."
    exit 1
fi

echo "Archive size: $(du -h ${ARCHIVE_NAME} | cut -f1)"

# Extract archive
echo "Extracting archive..."
tar -xjf "${ARCHIVE_NAME}"

# Find the extracted directory
EXTRACTED_DIR=$(find . -maxdepth 1 -name "*armv8*" -type d | head -1)
if [ -z "${EXTRACTED_DIR}" ]; then
    echo "Error: Could not find extracted Monero directory."
    ls -la
    exit 1
fi

echo "Found extracted directory: ${EXTRACTED_DIR}"
echo "Contents:"
ls -la "${EXTRACTED_DIR}/"

# Create destination directory
mkdir -p "${DEST_DIR}"

# Copy files
echo "Copying files to ${DEST_DIR}..."
cp -r "${EXTRACTED_DIR}"/* "${DEST_DIR}/"

# Verify critical binaries exist
BINARIES=("monerod" "monero-wallet-cli" "monero-wallet-rpc")
for binary in "${BINARIES[@]}"; do
    if [ ! -f "${DEST_DIR}/${binary}" ]; then
        echo "Error: ${binary} not found in ${DEST_DIR}"
        exit 1
    fi
    echo "✓ ${binary} found"
done

# Set permissions
chown -R miner:miner "${DEST_DIR}"
chmod +x "${DEST_DIR}"/*

# Create symlinks
echo "Creating symlinks..."
ln -sf "${DEST_DIR}/monero-wallet-cli" /usr/local/bin/monero-wallet-cli
ln -sf "${DEST_DIR}/monero-wallet-rpc" /usr/local/bin/monero-wallet-rpc
ln -sf "${DEST_DIR}/monerod" /usr/local/bin/monerod

# Cleanup
echo "Cleaning up..."
rm -rf "${ARCHIVE_NAME}" "${EXTRACTED_DIR}"

echo "✓ Monero ARM64 installation completed successfully!"
echo "Installed binaries:"
ls -la "${DEST_DIR}/" | grep -E "(monerod|monero-wallet)"
echo "Symlinks:"
ls -la /usr/local/bin/monero*