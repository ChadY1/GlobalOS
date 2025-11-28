#!/bin/bash
# Launch Firefox with a strict bubblewrap sandbox similar to GrapheneOS app isolation.
# Requires bubblewrap (`bwrap`) and a pre-created unprivileged user namespace on Debian.

set -euo pipefail

APP_CACHE="${XDG_CACHE_HOME:-/home/user/.cache/firefox}"

bwrap \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --tmpfs /tmp \
  --tmpfs "${APP_CACHE}" \
  --proc /proc \
  --dev /dev \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --unshare-all \
  --share-net \
  --die-with-parent \
  --new-session \
  firefox "$@"
