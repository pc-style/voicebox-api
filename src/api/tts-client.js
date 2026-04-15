import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Fish Speech S2 TTS Client
 * Synthesizes text with cloned voice via Fish Speech API
 */
class TTSClient {
  constructor(apiUrl = 'http://127.0.0.1:8080', voiceId = 'cloned_voice') {
    this.apiUrl = apiUrl;
    this.voiceId = voiceId;
  }

  /**
   * Synthesize text to speech
   * @param {string} text - Text to synthesize
   * @param {object} options - Optional: { voiceId, format, speed }
   * @returns {Promise<Buffer>} Audio data
   */
  async synthesize(text, options = {}) {
    const voiceId = options.voiceId || this.voiceId;
    
    const payload = {
      text,
      voice_id: voiceId,
      format: options.format || 'wav',
      speed: options.speed || 1.0
    };

    const res = await fetch(`${this.apiUrl}/v1/tts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      throw new Error(`TTS failed: ${res.status} ${res.statusText}`);
    }

    return Buffer.from(await res.arrayBuffer());
  }

  /**
   * Synthesize multiple texts in batch
   * @param {string[]} texts - Array of texts
   * @param {string} outputDir - Output directory for audio files
   * @param {object} options - Optional: { voiceId, format, speed }
   */
  async synthesizeBatch(texts, outputDir, options = {}) {
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    console.log(`Synthesizing ${texts.length} texts...`);

    for (let i = 0; i < texts.length; i++) {
      const text = texts[i];
      try {
        console.log(`[${i + 1}/${texts.length}] Synthesizing: "${text.slice(0, 50)}..."`);
        
        const audio = await this.synthesize(text, options);
        const filename = `output-${String(i + 1).padStart(3, '0')}.wav`;
        const filepath = path.join(outputDir, filename);
        
        fs.writeFileSync(filepath, audio);
        console.log(`  → ${filename}`);
      } catch (err) {
        console.error(`  ✗ Error: ${err.message}`);
      }
    }

    console.log(`Complete! Audio files in ${outputDir}`);
  }
}

// CLI usage
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
Fish Speech S2 TTS Client

Usage:
  node tts-client.js <text>                    Synthesize single text
  node tts-client.js --file <path>            Synthesize texts from file (one per line)
  node tts-client.js --json <path>            Synthesize texts from JSON array

Options:
  --api <url>                                  API endpoint (default: http://127.0.0.1:8080)
  --voice <id>                                 Voice ID (default: cloned_voice)
  --output <dir>                               Output directory (default: ./output)
  --format <fmt>                               Audio format: wav, mp3 (default: wav)
  --speed <n>                                  Playback speed 0.5-2.0 (default: 1.0)

Examples:
  node tts-client.js "Hello, how are you?"
  node tts-client.js --file texts.txt --voice cloned_voice --output ./audio
  node tts-client.js --json english-texts.json --output ./audio
    `);
    process.exit(0);
  }

  const api = process.argv.indexOf('--api') > -1 
    ? process.argv[process.argv.indexOf('--api') + 1]
    : 'http://127.0.0.1:8080';
  
  const voiceId = process.argv.indexOf('--voice') > -1
    ? process.argv[process.argv.indexOf('--voice') + 1]
    : 'cloned_voice';
  
  const outputDir = process.argv.indexOf('--output') > -1
    ? process.argv[process.argv.indexOf('--output') + 1]
    : './output';

  const format = process.argv.indexOf('--format') > -1
    ? process.argv[process.argv.indexOf('--format') + 1]
    : 'wav';

  const speed = process.argv.indexOf('--speed') > -1
    ? parseFloat(process.argv[process.argv.indexOf('--speed') + 1])
    : 1.0;

  const client = new TTSClient(api, voiceId);
  const options = { voiceId, format, speed };

  try {
    // Single text
    if (args[0] && !args[0].startsWith('--')) {
      const audio = await client.synthesize(args[0], options);
      const outputFile = path.join(outputDir, 'output.wav');
      
      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }
      
      fs.writeFileSync(outputFile, audio);
      console.log(`✓ Synthesized: ${outputFile}`);
      return;
    }

    // File-based
    if (args[0] === '--file' && args[1]) {
      const filePath = args[1];
      const texts = fs.readFileSync(filePath, 'utf8').split('\n').filter(t => t.trim());
      await client.synthesizeBatch(texts, outputDir, options);
      return;
    }

    // JSON array
    if (args[0] === '--json' && args[1]) {
      const filePath = args[1];
      const texts = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      if (!Array.isArray(texts)) {
        throw new Error('JSON must be an array of strings');
      }
      await client.synthesizeBatch(texts, outputDir, options);
      return;
    }

    console.error('Invalid arguments');
    process.exit(1);
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}

main();

export default TTSClient;
