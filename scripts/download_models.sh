#!/usr/bin/env bash
set -euo pipefail

# Download Fish Speech S2 Pro model checkpoints to /opt/fish-speech/checkpoints
# Requires: git (with git-lfs), huggingface_hub, or manual setup
#
# Environment variables:
#   INSTALL_DIR      - Fish Speech install root (default: /opt/fish-speech)
#   HF_REPO          - HuggingFace repo ID (default: fishaudio/s2-pro)
#   HF_TOKEN         - HuggingFace auth token (optional, for gated models)
#   HF_HOME          - HuggingFace cache directory (default: ~/.cache/huggingface)

INSTALL_DIR="${INSTALL_DIR:-/opt/fish-speech}"
HF_REPO="${HF_REPO:-fishaudio/s2-pro}"
TARGET_DIR="${INSTALL_DIR}/checkpoints/s2-pro"
export HF_HOME="${HF_HOME:-${HOME}/.cache/huggingface}"

log() {
  echo
  echo "==> $*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Check if we can use huggingface_hub (installed in Fish Speech environment)
download_with_huggingface_hub() {
  log "Downloading model with huggingface_hub"
  
  if ! have_cmd python3; then
    echo "Error: python3 not found"
    return 1
  fi
  
  python3 << 'EOF'
from huggingface_hub import snapshot_download
import os

target_dir = os.environ.get('TARGET_DIR', '/opt/fish-speech/checkpoints/s2-pro')
hf_repo = os.environ.get('HF_REPO', 'fishaudio/s2-pro')

print(f"Downloading {hf_repo} to {target_dir}...")
snapshot_download(
    hf_repo,
    repo_type="model",
    local_dir=target_dir,
    resume_download=True,
    allow_patterns=["*.pth", "*.json", "*.safetensors"]
)
print("Download complete!")
EOF
}

# Check if we can use git-lfs
download_with_git_lfs() {
  log "Downloading model with git-lfs"
  
  if ! have_cmd git; then
    echo "Error: git not found"
    return 1
  fi
  
  if ! have_cmd git-lfs; then
    echo "Installing git-lfs..."
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      if [[ "${ID}" == "ubuntu" ]] || [[ "${ID}" == "debian" ]]; then
        apt-get update -y && apt-get install -y git-lfs
      fi
    fi
  fi
  
  mkdir -p "${INSTALL_DIR}"
  
  # Clone repo with LFS support
  if [[ -d "${TARGET_DIR}/.git" ]]; then
    log "Updating existing repo"
    git -C "${TARGET_DIR}" pull
  else
    log "Cloning model repo"
    git clone "https://huggingface.co/${HF_REPO}" "${TARGET_DIR}"
  fi
}

print_links() {
  cat <<EOF

Fish Speech S2 Pro Model Download Links:
========================================

Manual Download Options:
  - HuggingFace: https://huggingface.co/fishaudio/s2-pro
  
Required Files:
  - s2-pro/codec.pth          (codec/compression model)
  - s2-pro/model.pth          (main S2 model)
  - s2-pro/config.json        (model configuration)
  
Place all files in: ${TARGET_DIR}

If auto-download fails, manually download from HF and extract to the path above.
EOF
}

main() {
  mkdir -p "${TARGET_DIR}"
  
  log "Fish Speech S2 Pro Model Download"
  log "Target: ${TARGET_DIR}"
  
  # Try huggingface_hub first (if Python/pip available)
  if have_cmd python3; then
    if python3 -c "import huggingface_hub" 2>/dev/null; then
      download_with_huggingface_hub && return 0
    fi
  fi
  
  # Try git-lfs
  if have_cmd git; then
    download_with_git_lfs && return 0
  fi
  
  # If both fail, print manual instructions
  log "Auto-download not available. Manual download required."
  print_links
}

main "$@"
