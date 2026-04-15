#!/usr/bin/env bash
set -euo pipefail

# Voicebox API Installation Script
# Fetches from GitHub, installs deps, sets up everything, starts dashboard

REPO_URL="${REPO_URL:-https://github.com/pc-style/voicebox-api.git}"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/voicebox-api}"
DASHBOARD_PORT="${DASHBOARD_PORT:-9900}"

log() {
  echo "==> $*"
}

err() {
  echo "ERROR: $*" >&2
  exit 1
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

install_node() {
  if check_cmd node && [[ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" -ge 22 ]]; then
    log "Node 22+ already installed: $(node -v)"
    return
  fi

  log "Installing Node.js 22+"
  if check_cmd brew; then
    brew install node@22
    brew link node@22 --force
  elif check_cmd apt-get; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
  else
    err "Please install Node.js 22+ manually from https://nodejs.org"
  fi
}

clone_repo() {
  log "Cloning repository to ${INSTALL_DIR}"
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" fetch origin
    git -C "${INSTALL_DIR}" reset --hard origin/main
  else
    rm -rf "${INSTALL_DIR}"
    git clone "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

install_deps() {
  log "Installing dependencies"
  cd "${INSTALL_DIR}"
  npm install
}

setup_dashboard() {
  log "Setting up dashboard configuration"
  cat > "${INSTALL_DIR}/.env" <<EOF
NODE_ENV=production
DASHBOARD_PORT=${DASHBOARD_PORT}
INSTALL_DIR=${INSTALL_DIR}
EOF
}

start_dashboard() {
  log "Starting dashboard on port ${DASHBOARD_PORT} (background)"
  cd "${INSTALL_DIR}"
  nohup npm run start:dashboard > "${INSTALL_DIR}/dashboard.log" 2>&1 &
  echo $! > "${INSTALL_DIR}/.dashboard.pid"
  sleep 2
  if curl -fs "http://127.0.0.1:${DASHBOARD_PORT}/health" >/dev/null; then
    log "Dashboard running: http://127.0.0.1:${DASHBOARD_PORT}"
  else
    err "Dashboard failed to start. Check ${INSTALL_DIR}/dashboard.log"
  fi
}

print_summary() {
  log "Installation complete!"
  echo
  echo "Install dir: ${INSTALL_DIR}"
  echo "Dashboard:   http://127.0.0.1:${DASHBOARD_PORT}"
  echo "Logs:        tail -f ${INSTALL_DIR}/dashboard.log"
  echo
  echo "To stop:     kill \$(cat ${INSTALL_DIR}/.dashboard.pid)"
  echo
}

main() {
  install_node
  clone_repo
  install_deps
  setup_dashboard
  start_dashboard
  print_summary
}

main "$@"
