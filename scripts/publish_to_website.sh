#!/usr/bin/env bash
set -euo pipefail

# Synchronise l'ISO et la documentation vers global-os.net
# Variables attendues :
#   TARGET_HOST (ex: global-os.net)
#   TARGET_PATH (ex: /var/www/global-os)
#   SSH_OPTS    (facultatif, ex: '-i ~/.ssh/globalos')

TARGET_HOST=${TARGET_HOST:-"global-os.net"}
TARGET_PATH=${TARGET_PATH:-"/var/www/global-os"}
SSH_OPTS=${SSH_OPTS:-""}

if ! command -v rsync >/dev/null; then
  echo "rsync manquant" >&2
  exit 1
fi

# Trouver la dernière ISO générée (hash optionnel si généré manuellement)
ISO_FILE=$(ls -1t *.iso 2>/dev/null | head -n1 || true)
SHA_FILE=$(ls -1t *.sha256 2>/dev/null | head -n1 || true)

if [[ -z "$ISO_FILE" ]]; then
  echo "Aucune ISO trouvée. Lancez scripts/build.sh d'abord." >&2
  exit 1
fi

# Publier artefacts
if [[ -n "$SHA_FILE" ]]; then
  rsync -av $SSH_OPTS "$ISO_FILE" "$SHA_FILE" "${TARGET_HOST}:${TARGET_PATH}/artifacts/"
else
  echo "[!] Aucun hash .sha256 détecté ; publication de l'ISO seule."
  rsync -av $SSH_OPTS "$ISO_FILE" "${TARGET_HOST}:${TARGET_PATH}/artifacts/"
fi

# Publier site statique et docs
rsync -av --delete $SSH_OPTS site/ "${TARGET_HOST}:${TARGET_PATH}/site/"
rsync -av --delete $SSH_OPTS docs/ "${TARGET_HOST}:${TARGET_PATH}/docs/"

echo "Publication terminée sur ${TARGET_HOST}:${TARGET_PATH}" && exit 0
