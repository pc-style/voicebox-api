#!/usr/bin/env bash
set -euo pipefail

# Full Fish Speech bootstrap on DigitalOcean H200 GPU droplet
# Run as root on fresh Ubuntu 24.04 droplet
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/pc-style/voicebox-api/main/scripts/bootstrap_droplet.sh)

log() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ $(id -u) -eq 0 ]] || err "Must run as root"

INSTALL_DIR="${INSTALL_DIR:-/opt/fish-speech}"
REPO_URL="${REPO_URL:-https://github.com/fishaudio/fish-speech.git}"

# 1. Install base packages
log "Installing system packages..."
apt-get update -y
apt-get install -y \
  git curl wget \
  python3 python3-pip python3-venv \
  docker.io docker-compose-v2 \
  nvidia-container-toolkit \
  build-essential

# 2. Enable NVIDIA Docker runtime
log "Configuring NVIDIA Docker runtime..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "runc"
}
EOF
systemctl restart docker

# 3. Clone Fish Speech repo
log "Cloning Fish Speech repository..."
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 4. Create docker-compose override for GPU + port binding
log "Creating Docker Compose config..."
cat > docker-compose.override.yml <<'DOCKER'
version: '3.8'
services:
  server:
    runtime: nvidia
    ports:
      - "0.0.0.0:8080:8080"
    environment:
      FISH_API_BIND: "0.0.0.0"
      FISH_API_PORT: "8080"
      CUDA_VISIBLE_DEVICES: "0"
DOCKER

# 5. Create directories
mkdir -p checkpoints/s2-pro references data

# 6. Download models
log "Downloading Fish Speech S2 Pro models..."
python3 -m pip install -q huggingface_hub 2>/dev/null || true

python3 << 'PYEOF'
from huggingface_hub import snapshot_download
import os

target_dir = "/opt/fish-speech/checkpoints/s2-pro"
os.makedirs(target_dir, exist_ok=True)

print("Downloading fishaudio/s2-pro models...")
snapshot_download(
  "fishaudio/s2-pro",
  repo_type="model",
  local_dir=target_dir,
  allow_patterns=["*.pth", "*.json"],
  resume_download=True
)
print("✓ Models downloaded to " + target_dir)
PYEOF

# 7. Start Fish Speech API server
log "Starting Fish Speech API server..."
cd "$INSTALL_DIR"
docker compose --profile server up -d --build

# 8. Wait for API to be healthy
log "Waiting for API to be ready..."
for i in {1..30}; do
  if curl -fs http://127.0.0.1:8080/v1/health >/dev/null 2>&1; then
    log "✓ API is ready!"
    break
  fi
  sleep 2
done

# 9. Setup UFW firewall
log "Configuring firewall..."
apt-get install -y ufw
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp     # SSH
ufw allow 8080/tcp   # Fish Speech API
ufw allow 9900/tcp   # Dashboard (optional)

# 10. Print summary
log "Bootstrap complete!"
echo
echo "=================================================="
echo "Fish Speech S2 API Server on H200 GPU"
echo "=================================================="
echo "API Endpoint:    http://$(hostname -I | awk '{print $1}'):8080"
echo "Health Check:    curl http://127.0.0.1:8080/v1/health"
echo "Docker Status:   docker compose ps"
echo "Docker Logs:     docker compose logs --tail=50 server"
echo
echo "Next steps:"
echo "  1. Upload reference audio: scp reference.mp3 root@DROPLET_IP:/opt/fish-speech/references/"
echo "  2. Register voice clone: curl -X POST http://127.0.0.1:8080/v1/voice/clone -d '{...}'"
echo "  3. Synthesize with cloned voice"
echo
