# Voicebox Agent Guidelines

## Project Idea
Fish Speech S2 API server deployment on DigitalOcean H200 GPU droplet. Automatic bootstrap from bare droplet to production inference API in one script.

## Installation & Deployment (Droplet Context)
- **Setup script**: `/opt/fish-speech/scripts/install_fish_speech_do_gpu.sh` (run on fresh DO NVIDIA AI/ML droplet as root)
- **Install dir**: `/opt/fish-speech` (cloned Fish Speech repo)
- **Logs/monitoring**: `docker compose logs --tail=200 server` (Fish Speech container logs)
- **Health check**: `curl http://127.0.0.1:8080/v1/health` (API ready test)
- **No tests/linting**: This is deployment config, not a code project

## Architecture
- **Core**: Fish Speech S2 API server in Docker container with NVIDIA runtime
- **Config**: Environment vars in `/opt/fish-speech/.env` (BACKEND, COMPILE, CUDA_VER, UV_EXTRA)
- **Volumes**: `checkpoints/` (model weights), `references/` (voice samples)
- **Entry**: `/opt/fish-speech/tools/api_server.py`, endpoint: `POST /v1/tts`
- **Firewall**: UFW (SSH + API port 8080 if EXPOSE_PUBLIC=true)

## Critical Configuration Variables
```bash
EXPOSE_PUBLIC=(true|false)  # Bind to 0.0.0.0 or 127.0.0.1
FISH_API_PORT=8080          # API listen port
COMPILE=1                   # torch.compile optimization
CUDA_VER=12.9.0             # Must match GPU driver
BACKEND=cuda                # or cpu
```

## Important Paths (On Droplet)
- `/opt/fish-speech/` - Fish Speech repo root
- `/opt/fish-speech/checkpoints/s2-pro/` - Model weights (codec.pth required)
- `/opt/fish-speech/docker-compose.override.yml` - GPU & port config
- `/opt/fish-speech/.env` - Build args for Docker

## Common Operations
```bash
docker compose ps                 # Status
docker compose restart server      # Restart API
docker compose --profile server up -d --build  # Redeploy
docker compose down              # Stop all
```

## Style & Conventions
- **Bash**: Use `set -euo pipefail`, quote variables, prefer `shellcheck`
- **Docker**: Multi-stage builds, explicit CUDA versions, health checks
- **Config**: Environment vars + compose overrides (no hardcodes)
- **Errors**: Fail fast, clear log messages with context, verify GPU before running

## When Modifying Scripts
- Test locally first (simulate droplet conditions)
- Ensure idempotency (safe to re-run)
- Always require root check at top
- Update README.md with new environment vars or paths
