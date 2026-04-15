#!/usr/bin/env bash
set -euo pipefail

# Prepare Fish Speech voice clone from reference audio + transcription
# Uploads assets to droplet and registers cloned voice

DROPLET_IP="${1:-}"
DROPLET_USER="${DROPLET_USER:-root}"
INSTALL_DIR="/opt/fish-speech"
ASSETS_DIR="$(dirname "$0")/../assets"

log() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ -z "$DROPLET_IP" ]]; then
  err "Usage: $0 <DROPLET_IP> [DROPLET_USER]"
fi

log "Preparing voice clone: reference.mp3 + transcription"

# Upload reference audio and transcription
log "Uploading reference audio and transcription..."
ssh -u "$DROPLET_USER" "$DROPLET_IP" "mkdir -p ${INSTALL_DIR}/references" || true

scp -r "$ASSETS_DIR/reference.mp3" "$DROPLET_USER@$DROPLET_IP:${INSTALL_DIR}/references/"
scp -r "$ASSETS_DIR/reference.txt" "$DROPLET_USER@$DROPLET_IP:${INSTALL_DIR}/references/"

log "Reference uploaded to droplet: ${INSTALL_DIR}/references/"

# Upload English texts
log "Extracting and uploading English texts..."
if [[ -f "$ASSETS_DIR/english-texts.zip" ]]; then
  TEMP_EXTRACT=$(mktemp -d)
  unzip -q "$ASSETS_DIR/english-texts.zip" -d "$TEMP_EXTRACT"
  scp -r "$TEMP_EXTRACT"/* "$DROPLET_USER@$DROPLET_IP:${INSTALL_DIR}/references/"
  rm -rf "$TEMP_EXTRACT"
  log "English texts uploaded"
else
  log "Warning: english-texts.zip not found"
fi

log "Voice clone prep complete!"
echo
echo "Next steps on droplet:"
echo "  1. SSH: ssh root@${DROPLET_IP}"
echo "  2. Register reference: docker exec fish-speech-server python -m fish_speech.tools.voice_clone --reference ${INSTALL_DIR}/references/reference.mp3 --transcript '$(cat ${INSTALL_DIR}/references/reference.txt)' --output cloned_voice"
echo "  3. List English texts: ls ${INSTALL_DIR}/references/"
echo "  4. Test TTS: curl -X POST http://127.0.0.1:8080/v1/tts -H 'Content-Type: application/json' -d '{\"text\": \"Hello world\", \"voice_id\": \"cloned_voice\"}'"
echo
