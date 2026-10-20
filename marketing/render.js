// Renders reels and posts to video and stills with headless Chromium.
//   node render.js <outDir> [days e.g. 1-50] [--only=reel|post] [--stills]
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');

const FPS = 30;
const [outDir, range = '1-50'] = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7);
const workers = +((process.argv.find((a) => a.startsWith('--workers=')) || '').slice(10) || 3);
const [lo, hi] = range.split('-').map(Number);
const days = JSON.parse(fs.readFileSync(path.join(__dirname, 'days.json'), 'utf8'));
const engine = fs.readFileSync(path.join(__dirname, 'engine.js'), 'utf8');

const jobs = [];
for (const d of days) {
  if (d.day < lo || d.day > (hi || lo)) continue;
  if (only !== 'post') jobs.push({ kind: 'reel', d });
  if (only !== 'reel') jobs.push({ kind: 'post', d });
}

function ffmpeg(args) {
  const p = spawn('ffmpeg', ['-v', 'error', '-y', ...args], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((res, rej) => p.on('close', (c) => (c ? rej(new Error('ffmpeg ' + c)) : res())));
  return { stdin: p.stdin, done };
}

async function setup(page, job) {
  return page.evaluate(([kind, d]) => {
    const s = kind === 'reel' ? WordleSocial.reel(d) : WordleSocial.post(d);
    window.__s = s;
    const c = document.getElementById('c');
    c.width = s.w;
    c.height = s.h;
    window.__ctx = c.getContext('2d');
    return { w: s.w, h: s.h, dur: s.dur, events: s.events, slides: s.slides ? s.slides.length : 0 };
  }, [job.kind, job.d]);
}

const grab = (page, fn, arg, type = 'image/jpeg') => page.evaluate(([fn, arg, type]) => {
  const ctx = window.__ctx;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  if (fn === 'frame') window.__s.draw(ctx, arg);
  else window.__s.slides[arg](ctx, 8);
  return ctx.canvas.toDataURL(type, 0.92).split(',')[1];
}, [fn, arg, type]);

async function run(page, job) {
  const dir = path.join(outDir, `day-${String(job.d.day).padStart(2, '0')}`);
  fs.mkdirSync(dir, { recursive: true });
  const info = await setup(page, job);
  const base = path.join(dir, job.kind);
  fs.writeFileSync(base + '.events.json', JSON.stringify({ dur: info.dur, events: info.events }));
  const silent = base + '.silent.mp4';
  const ff = ffmpeg(['-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', silent]);
  const frames = Math.round(info.dur * FPS);
  for (let i = 0; i < frames; i++) {
    const b64 = await grab(page, 'frame', i / FPS);
    if (!ff.stdin.write(Buffer.from(b64, 'base64'))) await new Promise((r) => ff.stdin.once('drain', r));
  }
  ff.stdin.end();
  await ff.done;
  if (job.kind === 'post') {
    for (let k = 0; k < info.slides; k++) {
      const png = await grab(page, 'slide', k, 'image/png');
      fs.writeFileSync(path.join(dir, `post-slide-${k + 1}.png`), Buffer.from(png, 'base64'));
    }
  }
  // Cover image for the reel: a frame near the end once everything is on screen.
  if (job.kind === 'reel') {
    const jpg = await grab(page, 'frame', info.dur - 1.2);
    fs.writeFileSync(path.join(dir, 'reel-cover.jpg'), Buffer.from(jpg, 'base64'));
  }
  return frames;
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
  const html = `<!doctype html><html><body style="margin:0"><canvas id="c"></canvas><script>${engine}</script></body></html>`;
  const t0 = Date.now();
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(workers, jobs.length) }, async () => {
    const page = await browser.newPage();
    await page.setContent(html);
    await page.evaluate(() => document.fonts.load('800 40px Inter'));
    while (next < jobs.length) {
      const job = jobs[next++];
      const s = Date.now();
      const n = await run(page, job);
      console.log(`day ${job.d.day} ${job.kind}: ${n} frames in ${((Date.now() - s) / 1000).toFixed(1)}s`);
    }
  }));
  await browser.close();
  console.log(`done in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
})().catch((e) => { console.error(e); process.exit(1); });
