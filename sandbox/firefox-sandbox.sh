#!/bin/bash
# Launch Firefox with a strict bubblewrap sandbox similar to GrapheneOS app isolation.
# Requires bubblewrap (`bwrap`) and a pre-created unprivileged user namespace on Debian.

set -euo pipefail

APP_CACHE="${XDG_CACHE_HOME:-/home/user/.cache/firefox}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/profiles"
SECCOMP_TMP=""

cleanup() {
  if [[ -n "${SESSION_PROXY_PID:-}" ]]; then
    kill "${SESSION_PROXY_PID}" 2>/dev/null || true
  fi
  if [[ -n "${SYSTEM_PROXY_PID:-}" ]]; then
    kill "${SYSTEM_PROXY_PID}" 2>/dev/null || true
  fi
  [[ -n "${PROXY_DIR:-}" ]] && rm -rf "${PROXY_DIR}"
  if [[ -n "${SECCOMP_TMP:-}" ]]; then
    exec 3<&-
    rm -f "${SECCOMP_TMP}"
  fi
}
trap cleanup EXIT

SECCOMP_ARGS=()
SECCOMP_PROFILE="${PROFILE_DIR}/firefox.seccomp"
if command -v seccomp-bpf >/dev/null 2>&1 && [[ -r "${SECCOMP_PROFILE}" ]]; then
  SECCOMP_TMP="$(mktemp)"
  if seccomp-bpf "${SECCOMP_PROFILE}" >"${SECCOMP_TMP}" 2>/dev/null; then
    exec 3<"${SECCOMP_TMP}"
    SECCOMP_ARGS=(--seccomp 3)
  else
    echo "[firefox-sandbox] Failed to compile seccomp profile, continuing without it" >&2
    rm -f "${SECCOMP_TMP}"
  fi
else
  echo "[firefox-sandbox] seccomp-bpf not available; running without seccomp filter" >&2
fi

PROXY_DIR="$(mktemp -d)"
SESSION_BUS_PROXY=""
SYSTEM_BUS_PROXY=""

if command -v xdg-dbus-proxy >/dev/null 2>&1; then
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    SESSION_BUS_PROXY="${PROXY_DIR}/session-bus"
    xdg-dbus-proxy "${DBUS_SESSION_BUS_ADDRESS}" "unix:path=${SESSION_BUS_PROXY}" \
      --filter \
      --talk=org.freedesktop.portal.* \
      --broadcast=org.freedesktop.portal.* \
      --see=org.freedesktop.portal.* \
      --own=org.mozilla.firefox.* \
      --log &
    SESSION_PROXY_PID=$!
  fi

  if [[ -n "${DBUS_SYSTEM_BUS_ADDRESS:-}" ]]; then
    SYSTEM_BUS_PROXY="${PROXY_DIR}/system-bus"
    xdg-dbus-proxy "${DBUS_SYSTEM_BUS_ADDRESS}" "unix:path=${SYSTEM_BUS_PROXY}" --filter --log &
    SYSTEM_PROXY_PID=$!
  fi
else
  echo "[firefox-sandbox] xdg-dbus-proxy not available; D-Bus access will not be filtered" >&2
fi

BWRAP_ARGS=(
  --ro-bind /usr /usr
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --tmpfs /tmp
  --tmpfs "${APP_CACHE}"
  --proc /proc
  --dev /dev
  --symlink usr/lib /lib
  --symlink usr/lib64 /lib64
  --unshare-all
  --share-net
  --die-with-parent
  --new-session
)

if [[ -n "${SESSION_BUS_PROXY}" ]]; then
  BWRAP_ARGS+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=${SESSION_BUS_PROXY}")
fi

if [[ -n "${SYSTEM_BUS_PROXY}" ]]; then
  BWRAP_ARGS+=(--setenv DBUS_SYSTEM_BUS_ADDRESS "unix:path=${SYSTEM_BUS_PROXY}")
fi

bwrap "${SECCOMP_ARGS[@]}" "${BWRAP_ARGS[@]}" firefox "$@"
