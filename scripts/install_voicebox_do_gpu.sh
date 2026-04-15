#!/usr/bin/env bash
set -euo pipefail

# A-Z bootstrap for Fish Speech S2 API server on a fresh
# DigitalOcean NVIDIA GPU Droplet (Ubuntu 22.04/24.04).

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo bash scripts/install_fish_speech_do_gpu.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

FISH_REPO_URL="${FISH_REPO_URL:-https://github.com/fishaudio/fish-speech.git}"
FISH_BRANCH="${FISH_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/fish-speech}"
FISH_API_PORT="${FISH_API_PORT:-8080}"
EXPOSE_PUBLIC="${EXPOSE_PUBLIC:-false}" # true => bind API to 0.0.0.0
ENABLE_UFW="${ENABLE_UFW:-true}"
COMPILE="${COMPILE:-1}"
BACKEND="${BACKEND:-cuda}"
CUDA_VER="${CUDA_VER:-12.9.0}"
UV_EXTRA="${UV_EXTRA:-cu129}"

log() {
  echo
  echo "==> $*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_base_packages() {
  log "Installing base OS packages"
  apt-get update -y
  apt-get install -y \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    gnupg \
    libsox-dev \
    lsb-release \
    portaudio19-dev \
    ufw
}

install_docker() {
  if have_cmd docker; then
    log "Docker already installed"
  else
    log "Installing Docker Engine + Compose plugin"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    local codename
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y \
      containerd.io \
      docker-buildx-plugin \
      docker-ce \
      docker-ce-cli \
      docker-compose-plugin
  fi

  systemctl enable docker
  systemctl restart docker
}

configure_nvidia_container_runtime() {
  if ! have_cmd nvidia-smi; then
    echo "nvidia-smi not found. Use an NVIDIA AI/ML-ready image first."
    exit 1
  fi

  log "Configuring NVIDIA Container Toolkit"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

  apt-get update -y
  apt-get install -y nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
}

configure_ufw() {
  if [[ "${ENABLE_UFW}" != "true" ]]; then
    log "Skipping UFW configuration (ENABLE_UFW=${ENABLE_UFW})"
    return
  fi

  ufw allow OpenSSH >/dev/null 2>&1 || true
  if [[ "${EXPOSE_PUBLIC}" == "true" ]]; then
    ufw allow "${FISH_API_PORT}/tcp" >/dev/null 2>&1 || true
  fi
  ufw --force enable >/dev/null 2>&1 || true
}

clone_or_update_repo() {
  log "Cloning/updating Fish Speech in ${INSTALL_DIR}"
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" fetch --all --prune
    git -C "${INSTALL_DIR}" checkout "${FISH_BRANCH}"
    git -C "${INSTALL_DIR}" pull --ff-only origin "${FISH_BRANCH}"
  else
    rm -rf "${INSTALL_DIR}"
    git clone --branch "${FISH_BRANCH}" "${FISH_REPO_URL}" "${INSTALL_DIR}"
  fi
}

write_env_file() {
  log "Writing Fish Speech .env configuration"
  cat > "${INSTALL_DIR}/.env" <<EOF
BACKEND=${BACKEND}
COMPILE=${COMPILE}
API_PORT=${FISH_API_PORT}
CUDA_VER=${CUDA_VER}
UV_EXTRA=${UV_EXTRA}
EOF
}

write_compose_override() {
  log "Writing docker-compose.override.yml"
  local bind_host="127.0.0.1"
  if [[ "${EXPOSE_PUBLIC}" == "true" ]]; then
    bind_host="0.0.0.0"
  fi

  cat > "${INSTALL_DIR}/docker-compose.override.yml" <<EOF
services:
  server:
    ports:
      - "${bind_host}:${FISH_API_PORT}:8080"
    gpus: all
EOF
}

start_fish_server() {
  log "Starting Fish Speech API server via Docker Compose"
  cd "${INSTALL_DIR}"
  mkdir -p checkpoints references
  docker compose --profile server up -d --build
  docker compose ps
}

run_health_check() {
  log "Running API health check"
  local host="127.0.0.1"
  if [[ "${EXPOSE_PUBLIC}" == "true" ]]; then
    host="$(curl -fsSL https://ifconfig.me || echo "0.0.0.0")"
  fi

  echo "Health endpoint:"
  echo "curl -X GET http://${host}:${FISH_API_PORT}/v1/health"

  curl -fsS "http://127.0.0.1:${FISH_API_PORT}/v1/health" || {
    echo "Health check failed. Review logs with: docker compose logs --tail=200 server"
    exit 1
  }
}

verify_gpu_runtime() {
  log "Validating GPU access from CUDA container"
  docker run --rm --gpus all "nvidia/cuda:${CUDA_VER}-base-ubuntu22.04" nvidia-smi
}

print_next_steps() {
  local public_ip
  public_ip="$(curl -fsSL https://ifconfig.me || true)"
  echo
  echo "Fish Speech deployment complete."
  echo "Install dir: ${INSTALL_DIR}"
  echo "API port: ${FISH_API_PORT}"
  echo "Repo: ${FISH_REPO_URL} (${FISH_BRANCH})"
  echo
  echo "Important: mount/download model checkpoints into:"
  echo "  ${INSTALL_DIR}/checkpoints"
  echo
  if [[ "${EXPOSE_PUBLIC}" == "true" ]]; then
    echo "API URL: http://${public_ip:-<droplet-ip>}:${FISH_API_PORT}/v1/health"
  else
    echo "Bound to localhost only. Use SSH tunnel:"
    echo "ssh -L ${FISH_API_PORT}:127.0.0.1:${FISH_API_PORT} root@<droplet-ip>"
  fi
}

main() {
  install_base_packages
  install_docker
  configure_nvidia_container_runtime
  configure_ufw
  clone_or_update_repo
  write_env_file
  write_compose_override
  start_fish_server
  verify_gpu_runtime
  run_health_check
  print_next_steps
}

main "$@"
