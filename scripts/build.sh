#!/bin/bash
set -euo pipefail

# This script bootstraps a Kali-GrapheneOS live-build workspace.
# It expects to be executed on a Debian host with the live-build tooling installed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

require_tool() {
  local cmd="$1"
  local pkg="$2"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[!] '${cmd}' is required but not found in PATH." >&2
    echo "    Install it with: sudo apt install ${pkg}" >&2
    exit 1
  fi
}

require_tool lb live-build
require_tool bwrap bubblewrap
require_tool xdg-dbus-proxy xdg-dbus-proxy
require_tool newuidmap uidmap

USERNS_TOGGLE="/proc/sys/kernel/unprivileged_userns_clone"
if [ -r "${USERNS_TOGGLE}" ]; then
  USERNS_VALUE="$(cat "${USERNS_TOGGLE}")"

  if [ "${USERNS_VALUE}" != "1" ]; then
    echo "[!] Unprivileged user namespaces are disabled (kernel.unprivileged_userns_clone=${USERNS_VALUE})." >&2

    if [ "${EUID}" -eq 0 ]; then
      echo "    Enabling temporarily for this session via sysctl..." >&2
      sysctl -w kernel.unprivileged_userns_clone=1 >/dev/null
    else
      echo "    Re-run this script as root or enable it manually:" >&2
      echo "      sudo sysctl -w kernel.unprivileged_userns_clone=1" >&2
      exit 1
    fi
  fi
else
  echo "[!] ${USERNS_TOGGLE} is missing; ensure your kernel supports unprivileged user namespaces." >&2
  echo "    See: https://www.kernel.org/doc/Documentation/admin-guide/sysctl/kernel.txt" >&2
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

# Package selection: rely on the repository-maintained lists in config/package-lists
if [ ! -f config/package-lists/core.list.chroot ]; then
  echo "[!] config/package-lists/core.list.chroot is missing; populate it with your base desktop and sandbox packages." >&2
  exit 1
fi

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
