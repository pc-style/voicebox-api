import express from 'express';
import os from 'os';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const port = process.env.DASHBOARD_PORT || 9900;
const installDir = process.env.INSTALL_DIR || process.env.HOME + '/voicebox-api';
const statusFile = path.join(installDir, 'data', 'status.json');
const dataDir = path.join(installDir, 'data');

// GPU pricing (H200 selected)
const GPU_PRICE_PER_HOUR = 3.44;

// Ensure data directory exists
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

// Initialize status file
function initStatus() {
  if (!fs.existsSync(statusFile)) {
    const status = {
      startedAt: new Date().toISOString(),
      uptimeSeconds: 0,
      costAccumulated: 0
    };
    fs.writeFileSync(statusFile, JSON.stringify(status, null, 2));
    return status;
  }
  return JSON.parse(fs.readFileSync(statusFile, 'utf8'));
}

function getMetrics() {
  const status = JSON.parse(fs.readFileSync(statusFile, 'utf8'));
  const startTime = new Date(status.startedAt);
  const now = new Date();
  const uptimeSeconds = Math.floor((now - startTime) / 1000);
  const uptimeHours = uptimeSeconds / 3600;

  // Calculate cost
  const costAccumulated = uptimeHours * GPU_PRICE_PER_HOUR;

  // CPU metrics
  const cpus = os.cpus();
  let totalIdle = 0, totalTick = 0;
  cpus.forEach(cpu => {
    for (const type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  });
  const cpuUsage = (100 - ~~(100 * totalIdle / totalTick));

  // Memory metrics
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  const memUsagePercent = (usedMem / totalMem) * 100;

  return {
    timestamp: now.toISOString(),
    uptime: {
      seconds: uptimeSeconds,
      hours: uptimeHours.toFixed(2),
      formatted: formatUptime(uptimeSeconds)
    },
    cpu: {
      usage: cpuUsage.toFixed(2),
      cores: cpus.length
    },
    memory: {
      total: (totalMem / 1024 / 1024 / 1024).toFixed(2), // GB
      used: (usedMem / 1024 / 1024 / 1024).toFixed(2),   // GB
      free: (freeMem / 1024 / 1024 / 1024).toFixed(2),   // GB
      usage: memUsagePercent.toFixed(2)
    },
    gpu: {
      model: 'H200 (1x 141GB VRAM)',
      vram: '141 GB'
    },
    cost: {
      pricePerHour: GPU_PRICE_PER_HOUR,
      accumulated: costAccumulated.toFixed(2),
      currency: 'USD'
    }
  };
}

function updateStatus() {
  const metrics = getMetrics();
  const status = {
    startedAt: JSON.parse(fs.readFileSync(statusFile, 'utf8')).startedAt,
    uptimeSeconds: metrics.uptime.seconds,
    costAccumulated: parseFloat(metrics.cost.accumulated)
  };
  fs.writeFileSync(statusFile, JSON.stringify(status, null, 2));
}

function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  return `${days}d ${hours}h ${mins}m`;
}

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/api/metrics', (req, res) => {
  updateStatus();
  res.json(getMetrics());
});

app.get('/', (req, res) => {
  res.send(getDashboardHTML());
});

function getDashboardHTML() {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Voicebox Dashboard</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1e1e2e 0%, #2d2d44 100%);
      color: #e0e0e0;
      padding: 20px;
      min-height: 100vh;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    h1 { margin-bottom: 30px; font-size: 32px; text-align: center; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .card {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 12px;
      padding: 24px;
      backdrop-filter: blur(10px);
    }
    .card h2 { font-size: 14px; text-transform: uppercase; color: #888; margin-bottom: 12px; }
    .metric {
      font-size: 36px;
      font-weight: bold;
      color: #4ade80;
      margin-bottom: 8px;
    }
    .unit { font-size: 14px; color: #666; }
    .bar {
      width: 100%;
      height: 8px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 4px;
      margin-top: 12px;
      overflow: hidden;
    }
    .fill {
      height: 100%;
      background: linear-gradient(90deg, #4ade80, #60a5fa);
      transition: width 0.3s ease;
    }
    .cost { color: #fbbf24; }
    .timestamp {
      text-align: center;
      color: #666;
      font-size: 12px;
      margin-top: 20px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Voicebox Dashboard</h1>
    <div class="grid">
      <div class="card">
        <h2>CPU Usage</h2>
        <div class="metric" id="cpu-usage">--</div>
        <div class="unit">across <span id="cpu-cores">--</span> cores</div>
        <div class="bar"><div class="fill" id="cpu-bar" style="width: 0%"></div></div>
      </div>

      <div class="card">
        <h2>Memory Usage</h2>
        <div class="metric" id="mem-usage">--</div>
        <div class="unit"><span id="mem-used">--</span> / <span id="mem-total">--</span> GB</div>
        <div class="bar"><div class="fill" id="mem-bar" style="width: 0%"></div></div>
      </div>

      <div class="card">
        <h2>GPU</h2>
        <div class="metric" id="gpu-model" style="font-size: 16px; color: #60a5fa;">H200</div>
        <div class="unit"><span id="gpu-vram">141 GB</span> VRAM</div>
      </div>

      <div class="card">
        <h2>Uptime</h2>
        <div class="metric" id="uptime" style="font-size: 24px;">--</div>
        <div class="unit">Since startup</div>
      </div>

      <div class="card">
        <h2>Accumulated Cost</h2>
        <div class="metric cost" id="cost-total">$--</div>
        <div class="unit"><span id="cost-rate">$3.44</span>/hour</div>
      </div>

      <div class="card">
        <h2>Status</h2>
        <div class="metric" style="color: #4ade80; font-size: 24px;">RUNNING</div>
        <div class="unit">All systems nominal</div>
      </div>
    </div>

    <div class="timestamp">
      Last updated: <span id="timestamp">--</span>
    </div>
  </div>

  <script>
    async function updateDashboard() {
      try {
        const res = await fetch('/api/metrics');
        const data = await res.json();

        // CPU
        document.getElementById('cpu-usage').textContent = data.cpu.usage + '%';
        document.getElementById('cpu-cores').textContent = data.cpu.cores;
        document.getElementById('cpu-bar').style.width = data.cpu.usage + '%';

        // Memory
        document.getElementById('mem-usage').textContent = data.memory.usage + '%';
        document.getElementById('mem-used').textContent = data.memory.used;
        document.getElementById('mem-total').textContent = data.memory.total;
        document.getElementById('mem-bar').style.width = data.memory.usage + '%';

        // GPU (static)
        document.getElementById('gpu-vram').textContent = data.gpu.vram;

        // Uptime
        document.getElementById('uptime').textContent = data.uptime.formatted;

        // Cost
        document.getElementById('cost-total').textContent = '$' + data.cost.accumulated;
        document.getElementById('cost-rate').textContent = '$' + data.cost.pricePerHour + '/hour';

        // Timestamp
        document.getElementById('timestamp').textContent = new Date(data.timestamp).toLocaleTimeString();
      } catch (err) {
        console.error('Failed to fetch metrics:', err);
      }
    }

    updateDashboard();
    setInterval(updateDashboard, 2000);
  </script>
</body>
</html>
  `;
}

// Initialize
initStatus();
updateStatus();

app.listen(port, '127.0.0.1', () => {
  console.log(\`Dashboard running on http://127.0.0.1:\${port}\`);
});
