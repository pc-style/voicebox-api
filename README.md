# Fish Speech S2 API on DigitalOcean H200

This repo now targets **Fish Speech S2** deployment as an API service on a new DigitalOcean H200 GPU droplet.

What is included:

- `scripts/install_fish_speech_do_gpu.sh`: A-Z bootstrap script for Docker + NVIDIA runtime + Fish Speech API server.
- Exact `doctl` commands to create and configure an H200 droplet.
- API smoke checks for `GET /v1/health` and `POST /v1/tts`.

## 1) Install and Authenticate `doctl` (local machine)

```bash
brew install doctl
doctl auth init
doctl account get
```

## 2) Resolve Required Slugs and Region

H200 GPU size slugs:

- `gpu-h200x1-141gb`
- `gpu-h200x8-1128gb`

Check available H200 sizes:

```bash
doctl compute size list --format Slug,Description,Regions --no-header | rg "gpu-h200"
```

Find an NVIDIA AI/ML image slug (recommended so `nvidia-smi` works out of the box):

```bash
doctl compute image list-distribution --public --format Slug,Name,Distribution --no-header | rg -i "nvidia|cuda|ai/ml|gpu|ubuntu"
```

Export chosen values:

```bash
export DO_REGION="nyc2"
export DO_SIZE="gpu-h200x1-141gb"
export DO_IMAGE_SLUG="<replace-with-nvidia-aiml-image-slug>"
```

## 3) Prepare SSH Key

```bash
doctl compute ssh-key list
doctl compute ssh-key import "pcstyle-main" --public-key-file ~/.ssh/id_ed25519.pub
export DO_SSH_FINGERPRINT="$(doctl compute ssh-key list --format Name,Fingerprint --no-header | rg '^pcstyle-main' | awk '{print $2}')"
```

## 4) Create H200 Droplet

```bash
export DROPLET_NAME="fish-speech-h200-01"
doctl compute droplet create "${DROPLET_NAME}" \
  --size "${DO_SIZE}" \
  --image "${DO_IMAGE_SLUG}" \
  --region "${DO_REGION}" \
  --ssh-keys "${DO_SSH_FINGERPRINT}" \
  --enable-monitoring \
  --wait \
  --format ID,Name,PublicIPv4,Status
```

Get IP and SSH:

```bash
export DROPLET_IP="$(doctl compute droplet list --format Name,PublicIPv4 --no-header | rg "^${DROPLET_NAME}\s" | awk '{print $2}')"
echo "${DROPLET_IP}"
ssh root@"${DROPLET_IP}"
```

## 5) Run Bootstrap Script on Droplet

```bash
apt-get update -y
apt-get install -y git
git clone <this-repo-url> /opt/fish-speech-do
cd /opt/fish-speech-do
chmod +x scripts/install_fish_speech_do_gpu.sh
EXPOSE_PUBLIC=true FISH_API_PORT=8080 COMPILE=1 bash scripts/install_fish_speech_do_gpu.sh
```

What the script does:

- Installs Docker + Compose plugin + NVIDIA Container Toolkit.
- Clones `fishaudio/fish-speech` into `/opt/fish-speech`.
- Writes Fish `.env` (`BACKEND`, `COMPILE`, `API_PORT`, `CUDA_VER`, `UV_EXTRA`).
- Writes `docker-compose.override.yml` to expose API and request GPU.
- Starts `docker compose --profile server up -d --build`.
- Runs health check on `GET /v1/health`.

## 6) Add Model Checkpoints

Fish server needs checkpoints mounted at `/app/checkpoints` in container (host path: `/opt/fish-speech/checkpoints`).

On droplet:

```bash
cd /opt/fish-speech
mkdir -p checkpoints references
```

Then follow Fish model setup instructions and place S2 checkpoints in:

- `/opt/fish-speech/checkpoints/s2-pro`
- ensure codec file exists at `/opt/fish-speech/checkpoints/s2-pro/codec.pth`

Source docs:

- [Fish Installation (Docker)](https://speech.fish.audio/install/#docker-setup)
- [Fish Server API](https://speech.fish.audio/server/)

## 7) Verify API

Health:

```bash
curl -X GET "http://${DROPLET_IP}:8080/v1/health"
```

Expected:

```json
{"status":"ok"}
```

TTS test:

```bash
curl -X POST "http://${DROPLET_IP}:8080/v1/tts" \
  -H "Content-Type: application/json" \
  -d '{"text":"hello from fish speech on h200"}' \
  --output sample.wav
```

If API is local-only (`EXPOSE_PUBLIC=false`), use SSH tunnel:

```bash
ssh -L 8080:127.0.0.1:8080 root@"${DROPLET_IP}"
curl -X GET "http://127.0.0.1:8080/v1/health"
```

## 8) Useful Operations

```bash
cd /opt/fish-speech
docker compose ps
docker compose logs --tail=200 server
docker compose restart server
docker compose --profile server up -d --build
```

## Notes

- Fish API server entrypoint is `tools/api_server.py` and main endpoint is `POST /v1/tts`.
- Docker API profile is `docker compose --profile server up`.
- `COMPILE=1` can improve throughput; test with your exact model + prompt mix.

