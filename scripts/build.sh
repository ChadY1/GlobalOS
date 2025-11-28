#!/bin/bash
set -euo pipefail

# This script bootstraps a Kali-GrapheneOS live-build workspace.
# It expects to be executed on a Debian host with the live-build tooling installed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v lb >/dev/null 2>&1; then
  echo "[!] live-build (lb) is required but not found in PATH" >&2
  exit 1
fi

# Clean previous artifacts
lb clean

# Base configuration
lb config \
  --distribution testing \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --bootloader grub \
  --debian-installer-gui true \
  --linux-packages "linux-image-amd64 linux-headers-amd64" \
  --iso-application "Kali-GrapheneOS" \
  --iso-publisher "YourName" \
  --iso-volume "Kali-GOS-2025.1"

# Package selection: core, web tools, and the Sway desktop (overwrite to avoid duplicates)
mkdir -p config/package-lists
cat > config/package-lists/my.list.chroot <<'EOF'
kali-grapheneos-core kali-grapheneos-web-tools sway
EOF

# Include user configuration skeletons
SWAY_DEST="config/includes.chroot/etc/skel/.config/sway"
mkdir -p "${SWAY_DEST}"

if [ -f "${HOME}/.config/sway/config" ]; then
  cp "${HOME}/.config/sway/config" "${SWAY_DEST}/"
else
  cp "${REPO_ROOT}/sway/config" "${SWAY_DEST}/"
fi

mkdir -p config/includes.chroot/usr/local/bin
cp sandbox/firefox-sandbox.sh config/includes.chroot/usr/local/bin/
chmod 0755 config/includes.chroot/usr/local/bin/firefox-sandbox.sh

# Build the ISO
lb build

echo "[+] ISO created at $(pwd)/kali-grapheneos-live-amd64.hybrid.iso"
