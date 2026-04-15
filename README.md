# Voicebox API

Fish Speech S2 deployment with monitoring dashboard on DigitalOcean H200 GPU droplet.

## One-Liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/pc-style/voicebox-api/main/install.sh | bash
```

This script:
- Installs Node.js 22+ (if not present)
- Clones the repo
- Installs dependencies
- Sets up dashboard config
- **Starts dashboard automatically on port 9900**

## Dashboard

After install, dashboard is live at **http://127.0.0.1:9900**

Displays real-time:
- **CPU usage** (all cores)
- **Memory usage** (GB)
- **GPU model** (H200 - 141GB VRAM)
- **Uptime** (formatted)
- **Accumulated cost** (counts from first launch)
- **Status** (always running)

Status is persisted in `~/voicebox-api/data/status.json`

## Manual Control

```bash
# Stop dashboard
kill $(cat ~/voicebox-api/.dashboard.pid)

# View logs
tail -f ~/voicebox-api/dashboard.log

# Restart
cd ~/voicebox-api && npm run start:dashboard
```

## Hardware

**Selected: H200** (vs H100)
- 141 GB VRAM (vs 80 GB) — **+76% more**
- 24 vCPU (vs 20 vCPU)
- 5 TB scratch NVMe
- $3.44/hr (vs $3.39/hr) — **only $0.05/hr more**

**Verdict**: H200 is better for production Fish Speech S2. Extra VRAM enables larger batches and concurrent requests.
