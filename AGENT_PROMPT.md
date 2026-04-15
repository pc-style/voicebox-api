# Agent Task: Bootstrap Fish Speech S2 API on DigitalOcean H200 Droplet

## Context
A DigitalOcean H200 GPU droplet has been created at IP: **162.243.235.203** (region: NYC2, size: gpu-h200x1-141gb).

This droplet runs Ubuntu 24.04 LTS and has SSH access via the `macbook-local` key (already configured).

## Current State
- ✓ Droplet provisioned and accessible via SSH
- ✓ Bootstrap script created at `scripts/bootstrap_droplet.sh`
- ✓ Bootstrap script pushed to GitHub

## Task: Complete Fish Speech S2 Deployment

Run the bootstrap script on the droplet to fully deploy Fish Speech S2 API server with GPU support.

### Steps

1. **SSH to droplet as root:**
   ```bash
   ssh root@162.243.235.203
   ```

2. **Run bootstrap script (will take 10-15 minutes):**
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/pc-style/voicebox-api/main/scripts/bootstrap_droplet.sh)
   ```

   The script will:
   - Install system packages (git, curl, python3, docker, nvidia-toolkit)
   - Configure NVIDIA Docker runtime
   - Clone Fish Speech repo to `/opt/fish-speech`
   - Create docker-compose GPU override config
   - Download S2-Pro models from HuggingFace to `/opt/fish-speech/checkpoints/s2-pro`
   - Start Fish Speech API server in Docker (port 8080)
   - Configure UFW firewall (SSH 22, API 8080, Dashboard 9900)
   - Print summary with API endpoint

3. **Verify API is healthy:**
   ```bash
   curl http://127.0.0.1:8080/v1/health
   # Should return: {"status": "ok"}
   ```

4. **Check Docker logs:**
   ```bash
   docker compose -C /opt/fish-speech logs --tail=50 server
   ```

5. **Verify GPU detection:**
   ```bash
   docker compose -C /opt/fish-speech exec server nvidia-smi
   # Should show H200 with 141GB VRAM
   ```

### Expected Output
When complete, the script prints:
```
==================================================
Fish Speech S2 API Server on H200 GPU
==================================================
API Endpoint:    http://<DROPLET_IP>:8080
Health Check:    curl http://127.0.0.1:8080/v1/health
Docker Status:   docker compose ps
Docker Logs:     docker compose logs --tail=50 server
```

## Success Criteria
- [ ] Bootstrap script runs without errors
- [ ] `curl http://127.0.0.1:8080/v1/health` returns `{"status": "ok"}`
- [ ] `docker compose ps` shows Fish Speech server running
- [ ] `nvidia-smi` shows H200 GPU allocated to container
- [ ] UFW firewall configured (allow SSH 22, API 8080)

## Next Steps (Post-Deployment)
After successful bootstrap:

1. Upload Polish reference audio to `/opt/fish-speech/references/`:
   ```bash
   scp assets/reference.mp3 root@162.243.235.203:/opt/fish-speech/references/
   scp assets/reference.txt root@162.243.235.203:/opt/fish-speech/references/
   ```

2. Register voice clone from reference audio

3. Test TTS synthesis with English texts

4. Deploy Voicebox dashboard (Node.js monitoring UI on port 9900)

## Troubleshooting

**Model download fails:**
- Check HuggingFace API is accessible: `curl https://huggingface.co/api/models/fishaudio/s2-pro`
- If gated, set HF_TOKEN before running bootstrap

**Docker fails to start:**
- NVIDIA runtime not loaded: `sudo systemctl restart docker`
- Check: `docker run --rm --runtime=nvidia nvidia/cuda:12.6.2-runtime-ubuntu24.04 nvidia-smi`

**GPU not detected in container:**
- Verify driver: `nvidia-smi` on host
- Check docker runtime: `docker info | grep nvidia`
- Restart Docker: `systemctl restart docker`

## Important Files
- Bootstrap script: `/opt/fish-speech/scripts/bootstrap_droplet.sh` (in repo)
- Models: `/opt/fish-speech/checkpoints/s2-pro/` (downloaded during bootstrap)
- Docker config: `/opt/fish-speech/docker-compose.override.yml` (created by bootstrap)
- Docker logs: `docker compose -C /opt/fish-speech logs`

## SSH Credentials
- Host: `162.243.235.203`
- User: `root`
- SSH Key: `macbook-local` (DigitalOcean)

---

**Agent**: When complete, report:
- Bootstrap script exit code
- Health check response
- Docker compose status
- Any errors encountered and how they were resolved
