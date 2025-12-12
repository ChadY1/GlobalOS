#!/bin/bash
# Launch Firefox with a strict bubblewrap sandbox similar to GrapheneOS app isolation.
# Requires bubblewrap (`bwrap`) and a pre-created unprivileged user namespace on Debian.

set -euo pipefail

if ! command -v bwrap >/dev/null 2>&1; then
  echo "[!] bubblewrap (bwrap) is required but not installed." >&2
  exit 1
fi

if ! command -v firefox >/dev/null 2>&1; then
  echo "[!] Firefox is not available in PATH." >&2
  exit 1
fi

USER_NAME="${USER:-firefox}"
USER_ID="$(id -u)"
SANDBOX_HOME="/home/${USER_NAME}"
CACHE_ROOT="${SANDBOX_HOME}/.cache"
CONFIG_ROOT="${SANDBOX_HOME}/.config"
PROFILE_ROOT="${SANDBOX_HOME}/.mozilla/firefox"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${USER_ID}}"
WAYLAND_SOCKET="${WAYLAND_DISPLAY:-wayland-0}"
WAYLAND_PATH="${RUNTIME_DIR}/${WAYLAND_SOCKET}"

BWRAP_ARGS=(
  bwrap
  --unshare-all
  --share-net
  --die-with-parent
  --new-session
  --hostname firefox-sandbox
  --setenv HOME "${SANDBOX_HOME}"
  --setenv XDG_CACHE_HOME "${CACHE_ROOT}"
  --setenv XDG_CONFIG_HOME "${CONFIG_ROOT}"
  --proc /proc
  --dev-bind /dev /dev
  --ro-bind /usr /usr
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --ro-bind /etc /etc
  --tmpfs /home
  --dir "${SANDBOX_HOME}"
  --dir "${CACHE_ROOT}"
  --dir "${CONFIG_ROOT}"
  --dir "${PROFILE_ROOT}"
  --dir "${CACHE_ROOT}/firefox"
  --tmpfs /tmp
)

# Provide runtime access for Wayland/DBus if available
if [[ -d "${RUNTIME_DIR}" ]]; then
  BWRAP_ARGS+=(
    --dir /run
    --dir /run/user
    --bind "${RUNTIME_DIR}" "/run/user/${USER_ID}"
    --setenv XDG_RUNTIME_DIR "/run/user/${USER_ID}"
  )

  if [[ -S "${WAYLAND_PATH}" ]]; then
    BWRAP_ARGS+=(
      --setenv WAYLAND_DISPLAY "${WAYLAND_SOCKET}"
    )
  else
    echo "[-] Wayland socket not found at ${WAYLAND_PATH}; continuing without it." >&2
  fi
else
  echo "[-] XDG_RUNTIME_DIR not available; GUI integration may be limited." >&2
fi

exec "${BWRAP_ARGS[@]}" firefox "$@"
