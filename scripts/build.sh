#!/bin/bash
set -euo pipefail

# This script bootstraps a Global-K-OS live-build workspace.
# It expects to be executed on a Debian host with the live-build tooling installed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

usage() {
  cat <<'EOF'
Usage: scripts/build.sh [options]

Options:
  --mirror <url>        Override the Debian mirror (default: http://deb.debian.org/debian)
  --iso-version <ver>   Override the ISO version string (default: 4.0)
  --attempts <n>        Retry the build up to N times (default: 1)
  --preflight-only      Run dependency and namespace checks, then exit without building
  --skip-deps-check     Skip dependency checks (useful for a lightweight preflight)
  --skip-unpriv-check   Skip the unprivileged mount preflight (not recommended)
  -h, --help            Show this help
EOF
}

DEBIAN_MIRROR="http://deb.debian.org/debian"
ISO_VERSION="${ISO_VERSION:-4.0}"
ATTEMPTS=1
PREFLIGHT_ONLY=false
SKIP_DEPS_CHECK=false
SKIP_UNPRIV_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mirror)
      DEBIAN_MIRROR="$2"
      shift 2
      ;;
    --iso-version)
      ISO_VERSION="$2"
      shift 2
      ;;
    --attempts)
      ATTEMPTS="$2"
      shift 2
      ;;
    --preflight-only)
      PREFLIGHT_ONLY=true
      shift 1
      ;;
    --skip-deps-check)
      SKIP_DEPS_CHECK=true
      shift 1
      ;;
    --skip-unpriv-check)
      SKIP_UNPRIV_CHECK=true
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

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
require_cmd unshare util-linux

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

# Basic sanity check: ensure we can mount proc/devpts inside an unprivileged user
# namespace. Some container runtimes block these mounts unless started with
# --privileged, which causes live-build to fail deep inside the bootstrap. A
# quick self-test avoids the confusing downstream error.
check_unpriv_mounts() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/proc" "${sandbox}/dev/pts"

  if ! unshare -Ur sh -c 'set -e; mount -t proc proc "$1/proc"; mount -t devpts devpts "$1/dev/pts"' -- "${sandbox}" 2>/dev/null; then
    echo "[!] Unable to mount proc/devpts inside an unprivileged user namespace." >&2
    echo "    The host/container likely blocks user namespace mounts." >&2
    echo "    Rerun inside a VM, on bare metal, or with a privileged container (docker run --privileged)." >&2
    rm -rf "${sandbox}"
    exit 1
  fi

  rm -rf "${sandbox}"
}

check_unpriv_mounts

# Clean previous artifacts while keeping the tracked config tree intact
lb clean --purge

  if ! unshare -Ur sh -c 'set -e; mount -t proc proc "$1/proc"; mount -t devpts devpts "$1/dev/pts"' -- "${sandbox}" 2>/dev/null; then
    echo "[!] Unable to mount proc/devpts inside an unprivileged user namespace." >&2
    echo "    The host/container likely blocks user namespace mounts." >&2
    echo "    Rerun inside a VM, on bare metal, or with a privileged container (docker run --privileged)." >&2
    rm -rf "${sandbox}"
    exit 1
  fi

# Base configuration
DEBIAN_MIRROR="http://deb.debian.org/debian"
ISO_VERSION="4.0"

lb config \
  --mode debian \
  --distribution trixie \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --bootloader grub \
  --debian-installer-gui true \
  --linux-packages none \
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

if [ "${PREFLIGHT_ONLY}" = true ]; then
  echo "[+] Preflight completed; skipping ISO build as requested."
  exit 0
fi

# Base configuration
configure_live_build() {
  local args=(
    --mode debian
    --distribution trixie
    --archive-areas "main contrib non-free non-free-firmware"
    --debian-installer live
    --bootloader grub
    --debian-installer-gui true
    --linux-packages none
    --iso-application "Global-K-OS"
    --iso-publisher "GlobalOS"
    --iso-volume "Global-K-OS-${ISO_VERSION}"
    --mirror-bootstrap "${DEBIAN_MIRROR}"
    --mirror-chroot "${DEBIAN_MIRROR}"
    --mirror-binary "${DEBIAN_MIRROR}"
    --security false
  )

  lb config "${args[@]}"
}

run_build() {
  # Clean previous artifacts while keeping the tracked config tree intact
  lb clean --purge

  configure_live_build

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

# Autoinstall / preseed
AUTOINSTALL_SRC="${REPO_ROOT}/autoinstall/global-os.preseed"
AUTOINSTALL_DST="config/preseed/global-os.preseed"
if [ -f "${AUTOINSTALL_SRC}" ]; then
  mkdir -p "$(dirname "${AUTOINSTALL_DST}")"
  cp -f "${AUTOINSTALL_SRC}" "${AUTOINSTALL_DST}"
fi

# Ensure the apt Contents disablement is applied inside the chroot as well
APT_DISABLE_SRC="${REPO_ROOT}/config/apt/99disable-contents.conf"
APT_DISABLE_DST="config/includes.chroot/etc/apt/apt.conf.d/99disable-contents.conf"
mkdir -p "$(dirname "${APT_DISABLE_DST}")"
cp -f "${APT_DISABLE_SRC}" "${APT_DISABLE_DST}"

# Enforce the systemd backend by pinning live-config-sysvinit away inside the chroot
APT_PREF_SRC="${REPO_ROOT}/config/apt/preferences.d/99live-config-backend.pref"
APT_PREF_DST="config/includes.chroot/etc/apt/preferences.d/99live-config-backend.pref"
mkdir -p "$(dirname "${APT_PREF_DST}")"
cp -f "${APT_PREF_SRC}" "${APT_PREF_DST}"

# Build the ISO
lb build

shopt -s nullglob
ISO_CANDIDATES=("" ./*.hybrid.iso ./*.iso)
if [ ${#ISO_CANDIDATES[@]} -gt 1 ]; then
  ISO_PATH="${ISO_CANDIDATES[1]}"
else
  ISO_PATH=""
fi

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

  # Ensure the apt Contents disablement is applied inside the chroot as well
  APT_DISABLE_SRC="${REPO_ROOT}/config/apt/99disable-contents.conf"
  APT_DISABLE_DST="config/includes.chroot/etc/apt/apt.conf.d/99disable-contents.conf"
  mkdir -p "$(dirname "${APT_DISABLE_DST}")"
  cp -f "${APT_DISABLE_SRC}" "${APT_DISABLE_DST}"

  # Enforce the systemd backend by pinning live-config-sysvinit away inside the chroot
  APT_PREF_SRC="${REPO_ROOT}/config/apt/preferences.d/99live-config-backend.pref"
  APT_PREF_DST="config/includes.chroot/etc/apt/preferences.d/99live-config-backend.pref"
  mkdir -p "$(dirname "${APT_PREF_DST}")"
  cp -f "${APT_PREF_SRC}" "${APT_PREF_DST}"

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
    return 1
  fi

  echo "[+] ISO created at ${ISO_PATH}"
  return 0
}

attempt=1
while [ "${attempt}" -le "${ATTEMPTS}" ]; do
  echo "[+] Build attempt ${attempt}/${ATTEMPTS}"
  set +e
  run_build
  status=$?
  set -e

  if [ ${status} -eq 0 ]; then
    exit 0
  fi

  if [ "${attempt}" -lt "${ATTEMPTS}" ]; then
    echo "[!] Build failed (attempt ${attempt}). Retrying..."
  fi

  attempt=$((attempt + 1))

done

echo "[!] Build failed after ${ATTEMPTS} attempt(s)." >&2
exit 1
