#!/bin/bash
set -euo pipefail

# This script bootstraps a Global-K-OS live-build workspace.
# It expects to be executed on a Debian host with the live-build tooling installed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

require_cmd() {
  local cmd="$1"
  local pkg_hint="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[!] Missing required command: ${cmd} (install package: ${pkg_hint})" >&2
    exit 1
  fi
}

require_cmd lb live-build
# bubblewrap installs the `bwrap` binary
require_cmd bwrap bubblewrap
require_cmd xdg-dbus-proxy xdg-dbus-proxy
require_cmd newuidmap uidmap

USERNS_SYSCTL="/proc/sys/kernel/unprivileged_userns_clone"
if [ -f "${USERNS_SYSCTL}" ]; then
  USERNS_VALUE="$(cat "${USERNS_SYSCTL}")"
  if [ "${USERNS_VALUE}" != "1" ]; then
    echo "[!] User namespaces are disabled (kernel.unprivileged_userns_clone=${USERNS_VALUE})." >&2
    echo "    Enable temporarily: sudo sysctl -w kernel.unprivileged_userns_clone=1" >&2
    echo "    Persist (root): echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf" >&2
    exit 1
  fi
else
  echo "[!] Cannot detect unprivileged user namespace support at ${USERNS_SYSCTL}." >&2
  echo "    Please ensure user namespaces are enabled before building." >&2
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
  --iso-application "Global-K-OS" \
  --iso-publisher "GlobalOS" \
  --iso-volume "Global-K-OS-1.0"

# Package selection: core desktop/tooling and meta-packages
mkdir -p config/package-lists
# Avoid copying the same file onto itself (CI reported identical source/dest paths)
CORE_SRC="${REPO_ROOT}/config/package-lists/core.list.chroot"
CORE_DST="config/package-lists/core.list.chroot"
if [ "$(readlink -f "${CORE_SRC}")" != "$(readlink -f "${CORE_DST}")" ]; then
  cp -f "${CORE_SRC}" "${CORE_DST}"
fi
cat > config/package-lists/my.list.chroot <<'EOF_LIST'
kali-grapheneos-core kali-grapheneos-web-tools sway
EOF_LIST

# Include user configuration skeletons
SWAY_DEST="config/includes.chroot/etc/skel/.config/sway"
SHARED_SWAY="config/includes.chroot/usr/local/share/kali-grapheneos/sway"
mkdir -p "${SWAY_DEST}" "${SHARED_SWAY}"

if [ -f "${HOME}/.config/sway/config" ]; then
  cp "${HOME}/.config/sway/config" "${SWAY_DEST}/"
  cp "${HOME}/.config/sway/config" "${SHARED_SWAY}/config"
else
  cp "${REPO_ROOT}/sway/config" "${SWAY_DEST}/"
  cp "${REPO_ROOT}/sway/config" "${SHARED_SWAY}/config"
fi

mkdir -p config/includes.chroot/usr/local/bin
cp sandbox/firefox-sandbox.sh config/includes.chroot/usr/local/bin/
chmod 0755 config/includes.chroot/usr/local/bin/firefox-sandbox.sh

# Hooks and shared assets
mkdir -p config/hooks/live
cp -f "${REPO_ROOT}/config/hooks/live/001-permissions.chroot" config/hooks/live/

# Build the ISO
lb build

shopt -s nullglob
ISO_CANDIDATES=("" ./*.hybrid.iso ./*.iso)
if [ ${#ISO_CANDIDATES[@]} -gt 1 ]; then
  ISO_PATH="${ISO_CANDIDATES[1]}"
else
  ISO_PATH=""
fi

if [ -z "${ISO_PATH}" ]; then
  echo "[!] Unable to locate built ISO (expected *.hybrid.iso or *.iso in $(pwd))." >&2
  exit 1
fi

echo "[+] ISO created at ${ISO_PATH}"
if command -v sha256sum >/dev/null 2>&1; then
  echo "[+] Computing SHA-256 checksum..."
  sha256sum "${ISO_PATH}" | tee "${ISO_PATH}.sha256"
  echo "[+] SHA-256 saved to ${ISO_PATH}.sha256"
else
  echo "[!] sha256sum not available; cannot emit ISO hash." >&2
fi
