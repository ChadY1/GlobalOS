#!/bin/bash
set -euo pipefail

# This script bootstraps a Kali-GrapheneOS live-build workspace.
# It expects to be executed from the repository root on a Debian host
# with the live-build tooling installed.

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

# Package selection: core, web tools, and the Sway desktop
printf "kali-grapheneos-core kali-grapheneos-web-tools sway\n" >> config/package-lists/my.list.chroot

# Include user configuration skeletons
mkdir -p config/includes.chroot/etc/skel/.config/sway/
cp ${HOME}/.config/sway/config config/includes.chroot/etc/skel/.config/sway/ 2>/dev/null || true
cp sandbox/firefox-sandbox.sh config/includes.chroot/usr/local/bin/
chmod 0755 config/includes.chroot/usr/local/bin/firefox-sandbox.sh

# Build the ISO
lb build

echo "[+] ISO created at $(pwd)/kali-grapheneos-live-amd64.hybrid.iso"
