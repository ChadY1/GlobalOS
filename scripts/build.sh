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
require_cmd debootstrap debootstrap

USERNS_SYSCTL="/proc/sys/kernel/unprivileged_userns_clone"
USERNS_MAX="/proc/sys/user/max_user_namespaces"
if [ -f "${USERNS_SYSCTL}" ]; then
  USERNS_VALUE="$(cat "${USERNS_SYSCTL}")"
  if [ "${USERNS_VALUE}" != "1" ]; then
    echo "[!] User namespaces are disabled (kernel.unprivileged_userns_clone=${USERNS_VALUE})." >&2
    echo "    Enable temporarily: sudo sysctl -w kernel.unprivileged_userns_clone=1" >&2
    echo "    Persist (root): echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf" >&2
    exit 1
  fi
elif [ -f "${USERNS_MAX}" ]; then
  USERNS_MAX_VALUE="$(cat "${USERNS_MAX}")"
  if [ "${USERNS_MAX_VALUE}" -eq 0 ]; then
    echo "[!] User namespaces are disabled (user.max_user_namespaces=0)." >&2
    echo "    Enable temporarily: sudo sysctl -w user.max_user_namespaces=1024" >&2
    echo "    Persist (root): echo 'user.max_user_namespaces=1024' | sudo tee /etc/sysctl.d/99-userns.conf" >&2
    exit 1
  fi
  echo "[+] user.max_user_namespaces=${USERNS_MAX_VALUE} (kernel.unprivileged_userns_clone not present)."
else
  echo "[!] Cannot detect unprivileged user namespace support (no ${USERNS_SYSCTL} or ${USERNS_MAX})." >&2
  echo "    Please ensure user namespaces are enabled before building." >&2
  exit 1
fi

# Clean previous artifacts and stale configuration to avoid host-specific package lists (e.g., "casper")
lb clean
rm -rf config/package-lists config/includes.chroot config/hooks

# Base configuration
DEBIAN_MIRROR="http://deb.debian.org/debian"
ISO_VERSION="2.0.0-alpha"

lb config \
  --mode debian \
  --distribution testing \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --bootloader grub \
  --debian-installer-gui true \
  --linux-packages "linux-image linux-headers" \
  --linux-flavours "amd64" \
  --iso-application "Global-K-OS" \
  --iso-publisher "GlobalOS" \
  --iso-volume "Global-K-OS-${ISO_VERSION}" \
  --mirror-bootstrap "${DEBIAN_MIRROR}" \
  --mirror-chroot "${DEBIAN_MIRROR}" \
  --mirror-binary "${DEBIAN_MIRROR}" \
  --security false
# NOTE: We rely on the default keyring handling inside live-build/apt.
# Passing --keyring here currently triggers "Unsupported file ..." with newer
# apt toolchains, so we keep the default trusted key configuration.

# Package selection: core desktop/tooling (recreate clean tree every run)
mkdir -p config/package-lists
# Avoid copying the same file onto itself (CI reported identical source/dest paths)
CORE_SRC="${REPO_ROOT}/config/package-lists/core.list.chroot"
CORE_DST="config/package-lists/core.list.chroot"
if [ "$(readlink -f "${CORE_SRC}")" != "$(readlink -f "${CORE_DST}")" ]; then
  cp -f "${CORE_SRC}" "${CORE_DST}"
fi

# Extra packages limited to Debian mainline to avoid unavailable third-party deps
cat > config/package-lists/extra.list.chroot <<'EOF_LIST'
firefox-esr
vim-tiny
EOF_LIST

# Include user configuration skeletons without relying on external themes
SWAY_DEST="config/includes.chroot/etc/skel/.config/sway"
SHARED_SWAY="config/includes.chroot/usr/local/share/global-os/sway"
mkdir -p "${SWAY_DEST}" "${SHARED_SWAY}"

# Always copy the repo-provided defaults to avoid host-specific dependencies
cp "${REPO_ROOT}/sway/config" "${SWAY_DEST}/"
cp "${REPO_ROOT}/sway/config" "${SHARED_SWAY}/config"

mkdir -p config/includes.chroot/usr/local/bin
cp sandbox/firefox-sandbox.sh config/includes.chroot/usr/local/bin/
chmod 0755 config/includes.chroot/usr/local/bin/firefox-sandbox.sh

# Hooks and shared assets
mkdir -p config/hooks/live
HOOK_SRC="${REPO_ROOT}/config/hooks/live/001-permissions.chroot"
HOOK_DST="config/hooks/live/001-permissions.chroot"
if [ "$(readlink -f "${HOOK_SRC}")" != "$(readlink -f "${HOOK_DST}")" ]; then
  cp -f "${HOOK_SRC}" "${HOOK_DST}"
fi

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
