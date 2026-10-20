// Draws every reel and post as a pure function of time, so the same code can
// play live in a browser and render frame-exact video in headless Chromium.
(function (root) {
  const PAL = {
    dark: {
      bg: '#121317', card: '#1B1D22', card2: '#23262C', text: '#F1F2F4',
      sub: '#9EA3AD', line: '#2E3138', empty: '#34373E', filled: '#666B75',
      primary: '#8C95F0', button: '#4F5BD5', correct: '#34A86E',
      present: '#C99A1A', absent: '#3C4048', streak: '#FF8A3D', glow: 0.22,
    },
    light: {
      bg: '#F8F8FA', card: '#FFFFFF', card2: '#F0F1F4', text: '#1B1D22',
      sub: '#666B75', line: '#E2E4E9', empty: '#D9DCE1', filled: '#8A8F98',
      primary: '#4F5BD5', button: '#4F5BD5', correct: '#2F9E66',
      present: '#D6A419', absent: '#7C818A', streak: '#F2711C', glow: 0.14,
    },
  };
  const FONT = 'Inter, "Inter Display", system-ui, sans-serif';
  const LOGO = ['correct', 'present', 'absent', 'correct', 'present', 'correct'];
  const STATE = { c: 'correct', p: 'present', a: 'absent' };

  const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
  const seg = (t, a, d) => clamp((t - a) / d);
  const lerp = (a, b, k) => a + (b - a) * k;
  const ease = {
    out: (x) => 1 - Math.pow(1 - x, 3),
    inOut: (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2),
    back: (x) => 1 + 2.70158 * Math.pow(x - 1, 3) + 1.70158 * Math.pow(x - 1, 2),
  };

  function rng(seed) {
    let s = seed >>> 0;
    return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
  }

  // ---------------------------------------------------------------- drawing

  function setFont(ctx, size, weight = 700) {
    ctx.font = `${weight} ${size}px ${FONT}`;
  }

  function text(ctx, s, x, y, o = {}) {
    ctx.save();
    setFont(ctx, o.size || 40, o.weight || 700);
    ctx.fillStyle = o.color || '#000';
    ctx.textAlign = o.align || 'center';
    ctx.textBaseline = 'middle';
    ctx.globalAlpha *= o.alpha ?? 1;
    if (o.spacing) ctx.letterSpacing = o.spacing + 'px';
    ctx.fillText(s, x, y);
    ctx.restore();
  }

  function wrap(ctx, s, maxW, size, weight) {
    setFont(ctx, size, weight);
    const lines = [];
    for (const para of s.split('\n')) {
      let line = '';
      for (const w of para.split(' ')) {
        const next = line ? line + ' ' + w : w;
        if (ctx.measureText(next).width > maxW && line) {
          lines.push(line);
          line = w;
        } else line = next;
      }
      lines.push(line);
    }
    return lines;
  }

  // Wrapped text that rises in line by line from t0. Returns its height.
  function para(ctx, s, x, y, t, t0, o = {}) {
    const size = o.size || 44;
    const lh = o.lh || size * 1.3;
    const lines = wrap(ctx, s, o.maxW || 860, size, o.weight || 500);
    lines.forEach((l, i) => {
      const k = ease.out(seg(t, t0 + i * 0.08, 0.5));
      text(ctx, l, x, y + i * lh + (1 - k) * 30, { ...o, size, alpha: k * (o.alpha ?? 1) });
    });
    return lines.length * lh;
  }

  // Headline whose words pop in one after another.
  function headline(ctx, s, cx, y, t, t0, o = {}) {
    // Shrink until the text fits in the allowed number of lines.
    let size = o.size || 110;
    let lines = wrap(ctx, s, o.maxW || 940, size, 800);
    while (lines.length > (o.lines || 1) && size > (o.size || 110) * 0.6) {
      size -= 4;
      lines = wrap(ctx, s, o.maxW || 940, size, 800);
    }
    const lh = size * 1.08;
    let n = 0;
    lines.forEach((line, li) => {
      setFont(ctx, size, 800);
      ctx.letterSpacing = '-2px';
      const words = line.split(' ');
      const space = ctx.measureText(' ').width;
      const widths = words.map((w) => ctx.measureText(w).width);
      ctx.letterSpacing = '0px';
      const total = widths.reduce((a, b) => a + b, 0) + space * (words.length - 1);
      let x = cx - total / 2;
      words.forEach((w, wi) => {
        const k = seg(t, t0 + n++ * 0.09, 0.45);
        const sc = 0.6 + 0.4 * ease.back(k);
        ctx.save();
        ctx.translate(x + widths[wi] / 2, y + li * lh + (1 - ease.out(k)) * 40);
        ctx.scale(sc, sc);
        text(ctx, w, 0, 0, {
          size, weight: 800, spacing: -2, alpha: clamp(k * 2) * (o.alpha ?? 1),
          color: (o.accent && o.accent.includes(w)) ? o.accentColor : o.color,
        });
        ctx.restore();
        x += widths[wi] + space;
      });
    });
    return lines.length * lh;
  }

  function pill(ctx, label, cx, cy, o = {}) {
    const size = o.size || 30;
    setFont(ctx, size, 800);
    ctx.letterSpacing = (o.spacing ?? 2) + 'px';
    const w = ctx.measureText(label).width + size * 1.6 + (o.icon ? size * 1.1 : 0);
    ctx.letterSpacing = '0px';
    const h = size * 2;
    const k = o.k ?? 1;
    if (k <= 0) return w;
    ctx.save();
    ctx.translate(cx, cy);
    const sc = (0.6 + 0.4 * ease.back(k)) * (o.scale || 1);
    ctx.scale(sc, sc);
    ctx.globalAlpha *= clamp(k * 2);
    if (o.shadow) {
      ctx.shadowColor = o.bg;
      ctx.shadowBlur = 40;
    }
    ctx.fillStyle = o.bg;
    ctx.beginPath();
    ctx.roundRect(-w / 2, -h / 2, w, h, h / 2);
    ctx.fill();
    ctx.shadowBlur = 0;
    if (o.border) {
      ctx.strokeStyle = o.border;
      ctx.lineWidth = 3;
      ctx.stroke();
    }
    let tx = 0;
    if (o.icon === 'play') {
      tx = size * 0.55;
      const ix = -w / 2 + size * 1.05;
      ctx.fillStyle = o.color;
      ctx.beginPath();
      ctx.moveTo(ix, -size * 0.42);
      ctx.lineTo(ix + size * 0.72, 0);
      ctx.lineTo(ix, size * 0.42);
      ctx.closePath();
      ctx.fill();
    }
    text(ctx, label, tx, 2, { size, weight: 800, color: o.color, spacing: o.spacing ?? 2 });
    ctx.restore();
    return w;
  }

  // One letter tile. flip runs 0..1: the tile folds shut, then opens in its colour.
  function tile(ctx, P, x, y, s, letter, state, o = {}) {
    const flip = o.flip ?? 1;
    const pop = o.pop ?? 0;
    const alpha = o.alpha ?? 1;
    if (alpha <= 0) return;
    const shown = state && flip >= 0.5;
    const sy = state && flip < 1 ? Math.abs(1 - 2 * flip) : 1;
    const sc = (o.scale ?? 1) * (1 + 0.14 * Math.sin(Math.PI * pop));
    ctx.save();
    ctx.translate(x, y + (o.dy || 0));
    ctx.scale(sc, sc * Math.max(sy, 0.001));
    ctx.globalAlpha *= alpha;
    const r = s * 0.12;
    ctx.beginPath();
    ctx.roundRect(-s / 2, -s / 2, s, s, r);
    if (shown) {
      ctx.fillStyle = P[state];
      ctx.fill();
    } else {
      ctx.fillStyle = o.fill || P.card;
      ctx.fill();
      ctx.lineWidth = s * 0.04;
      ctx.strokeStyle = o.border || (letter && letter !== ' ' ? P.filled : P.empty);
      ctx.stroke();
    }
    if (letter && letter !== ' ') {
      text(ctx, letter.toUpperCase(), 0, s * 0.03, {
        size: s * 0.54, weight: 800,
        color: shown ? '#FFFFFF' : (o.letterColor || P.text),
      });
    }
    ctx.restore();
  }

  function rowWidth(n, s, gap) {
    return n * s + (n - 1) * gap;
  }

  // A guess being typed from tType and flipped from tFlip.
  function guessRow(ctx, P, cx, y, s, gap, word, states, t, tType, tFlip, o = {}) {
    const n = word.length;
    const x0 = cx - rowWidth(n, s, gap) / 2 + s / 2;
    for (let i = 0; i < n; i++) {
      const ti = tType + i * (o.typeStep ?? 0.07);
      const typed = t >= ti;
      const fl = tFlip == null ? 0 : seg(t, tFlip + i * (o.flipStep ?? 0.15), o.flipDur ?? 0.4);
      const bounce = o.tWin != null ? Math.sin(Math.PI * seg(t, o.tWin + i * 0.08, 0.35)) : 0;
      tile(ctx, P, x0 + i * (s + gap), y, s, typed ? word[i] : '', fl > 0 ? states[i] : null, {
        flip: fl, pop: seg(t, ti, 0.14), dy: -bounce * s * 0.35, alpha: o.alpha,
      });
    }
  }

  function emptyRow(ctx, P, cx, y, s, gap, n, o = {}) {
    const x0 = cx - rowWidth(n, s, gap) / 2 + s / 2;
    for (let i = 0; i < n; i++) {
      const k = o.t0 == null ? 1 : ease.back(seg(o.t, o.t0 + i * (o.step ?? 0.04), 0.35));
      tile(ctx, P, x0 + i * (s + gap), y, s, o.letter || '', null, {
        scale: k, alpha: clamp(k * 2) * (o.alpha ?? 1), border: o.border,
        letterColor: o.letterColor, fill: o.fill,
      });
    }
  }

  function background(ctx, P, t, w, h, seed = 1) {
    ctx.fillStyle = P.bg;
    ctx.fillRect(0, 0, w, h);
    const blobs = [
      [P.primary, 0.2, 0.18, 0.21],
      [P.correct, 0.85, 0.55, 0.17],
      [P.present, 0.25, 0.9, 0.13],
    ];
    blobs.forEach(([c, bx, by, sp], i) => {
      const x = w * (bx + 0.08 * Math.sin(t * sp * 2 + i * 2 + seed));
      const y = h * (by + 0.05 * Math.cos(t * sp * 1.7 + i + seed));
      const r = w * 0.75;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, hexA(c, P.glow));
      g.addColorStop(1, hexA(c, 0));
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, w, h);
    });
    // Faint tiles drifting upward.
    const R = rng(seed * 97 + 3);
    ctx.save();
    for (let i = 0; i < 14; i++) {
      const s = 40 + R() * 70;
      const x = R() * w;
      const speed = 18 + R() * 30;
      const y = ((R() * (h + 200) - t * speed) % (h + 200) + h + 200) % (h + 200) - 100;
      ctx.globalAlpha = 0.05 + R() * 0.05;
      ctx.translate(x, y);
      ctx.rotate(R() * 0.6 - 0.3 + t * 0.05);
      ctx.strokeStyle = P.sub;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.roundRect(-s / 2, -s / 2, s, s, s * 0.14);
      ctx.stroke();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
    }
    ctx.restore();
  }

  function hexA(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
  }

  function logo(ctx, P, cx, cy, s, t, t0) {
    const gap = s * 0.12;
    const x0 = cx - rowWidth(6, s, gap) / 2 + s / 2;
    for (let i = 0; i < 6; i++) {
      const k = seg(t, t0 + i * 0.09, 0.45);
      tile(ctx, P, x0 + i * (s + gap), cy, s, 'WORDLE'[i], LOGO[i], {
        flip: k, alpha: clamp(k * 4),
      });
    }
  }

  function card(ctx, P, x, y, w, h, o = {}) {
    ctx.save();
    ctx.globalAlpha *= o.alpha ?? 1;
    ctx.shadowColor = 'rgba(0,0,0,0.18)';
    ctx.shadowBlur = 30;
    ctx.shadowOffsetY = 8;
    ctx.fillStyle = o.fill || P.card;
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, o.r ?? 36);
    ctx.fill();
    ctx.shadowColor = 'transparent';
    ctx.strokeStyle = P.line;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.restore();
  }

  function confetti(ctx, P, t, t0, cx, cy, n = 90, seed = 7) {
    const dt = t - t0;
    if (dt < 0 || dt > 3.2) return;
    const R = rng(seed);
    const colors = [P.correct, P.present, P.primary, P.streak, '#FFFFFF'];
    ctx.save();
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + (R() - 0.5) * 2.4;
      const v = 900 + R() * 1100;
      const x = cx + Math.cos(a) * v * dt;
      const y = cy + Math.sin(a) * v * dt + 1300 * dt * dt;
      const rot = R() * 6 + dt * (R() * 10 - 5);
      const s = 14 + R() * 18;
      ctx.globalAlpha = clamp(1 - (dt - 2.2));
      ctx.fillStyle = colors[i % colors.length];
      ctx.translate(x, y);
      ctx.rotate(rot);
      ctx.fillRect(-s / 2, -s / 4, s, s / 2);
      ctx.setTransform(1, 0, 0, 1, 0, 0);
    }
    ctx.restore();
  }

  function fade(ctx, a, fn) {
    if (a <= 0) return;
    ctx.save();
    ctx.globalAlpha *= a;
    fn();
    ctx.restore();
  }

  // Bouncing call to action pinned near the bottom of the frame.
  function cta(ctx, P, t, t0, cx, cy, label, sub) {
    const k = seg(t, t0, 0.5);
    if (k <= 0) return;
    const pulse = 1 + 0.035 * Math.sin((t - t0) * 6) * clamp((t - t0 - 0.5) * 2);
    pill(ctx, label, cx, cy, {
      k, bg: P.button, color: '#FFFFFF', size: 40, icon: 'play', spacing: 0.5,
      scale: pulse, shadow: true,
    });
    if (sub) text(ctx, sub, cx, cy + 92, { size: 32, weight: 600, color: P.sub, alpha: seg(t, t0 + 0.3, 0.4) });
  }

  function arrowDown(ctx, color, x, y, t) {
    const b = Math.sin(t * 5) * 10;
    ctx.save();
    ctx.translate(x, y + b);
    ctx.strokeStyle = color;
    ctx.lineWidth = 8;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(-22, -10);
    ctx.lineTo(0, 12);
    ctx.lineTo(22, -10);
    ctx.stroke();
    ctx.restore();
  }

  // --------------------------------------------------------- feature icons

  function flame(ctx, x, y, s, color, t) {
    const f = 1 + 0.05 * Math.sin(t * 9) + 0.03 * Math.sin(t * 13);
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s / 100, (s / 100) * f);
    const path = (sc) => {
      ctx.beginPath();
      ctx.moveTo(0, -100 * sc);
      ctx.bezierCurveTo(40 * sc, -50 * sc, 70 * sc, -20 * sc, 60 * sc, 25 * sc);
      ctx.bezierCurveTo(52 * sc, 70 * sc, -52 * sc, 70 * sc, -60 * sc, 25 * sc);
      ctx.bezierCurveTo(-66 * sc, -5 * sc, -40 * sc, -30 * sc, -25 * sc, -45 * sc);
      ctx.bezierCurveTo(-25 * sc, -20 * sc, -10 * sc, -10 * sc, -5 * sc, -15 * sc);
      ctx.bezierCurveTo(-15 * sc, -50 * sc, -5 * sc, -80 * sc, 0, -100 * sc);
      ctx.closePath();
    };
    ctx.shadowColor = color;
    ctx.shadowBlur = 50;
    ctx.fillStyle = color;
    path(1);
    ctx.fill();
    ctx.shadowBlur = 0;
    ctx.translate(0, 25);
    ctx.fillStyle = '#FFD27A';
    path(0.5);
    ctx.fill();
    ctx.restore();
  }

  function bolt(ctx, x, y, s, color) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s / 100, s / 100);
    ctx.fillStyle = color;
    ctx.shadowColor = color;
    ctx.shadowBlur = 40;
    ctx.beginPath();
    ctx.moveTo(15, -100);
    ctx.lineTo(-55, 15);
    ctx.lineTo(-5, 15);
    ctx.lineTo(-20, 100);
    ctx.lineTo(55, -20);
    ctx.lineTo(5, -20);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function bulb(ctx, x, y, s, color, glow) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(s / 100, s / 100);
    if (glow > 0) {
      const g = ctx.createRadialGradient(0, -20, 0, 0, -20, 160);
      g.addColorStop(0, hexA(color, 0.5 * glow));
      g.addColorStop(1, hexA(color, 0));
      ctx.fillStyle = g;
      ctx.fillRect(-200, -220, 400, 400);
    }
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(0, -25, 55, Math.PI * 0.8, Math.PI * 2.2);
    ctx.lineTo(25, 45);
    ctx.lineTo(-25, 45);
    ctx.closePath();
    ctx.fill();
    ctx.fillRect(-25, 55, 50, 12);
    ctx.fillRect(-18, 74, 36, 10);
    ctx.restore();
  }

  // The animated illustration in a feature reel, centred on (cx, cy).
  function illustration(ctx, P, kind, t, t0, cx, cy) {
    const lt = t - t0;
    if (lt < 0) return [];
    const ev = [];
    switch (kind) {
      case 'flame': {
        const k = ease.back(seg(t, t0, 0.6));
        flame(ctx, cx - 170, cy, 230 * k, P.streak, t);
        const n = Math.floor(lerp(0, 7, seg(t, t0 + 0.5, 2.6)));
        text(ctx, String(n), cx + 130, cy - 30, { size: 220, weight: 900, color: P.text, alpha: k });
        text(ctx, 'day streak', cx + 130, cy + 110, { size: 44, weight: 700, color: P.sub, alpha: k });
        break;
      }
      case 'calendar': {
        const w = 820;
        const h = 640;
        card(ctx, P, cx - w / 2, cy - h / 2, w, h, { alpha: seg(t, t0, 0.4) });
        text(ctx, 'November', cx - w / 2 + 50, cy - h / 2 + 70, { size: 44, weight: 800, color: P.text, align: 'left', alpha: seg(t, t0, 0.4) });
        const cs = 92;
        const gx = cx - (7 * cs) / 2 + cs / 2;
        'MTWTFSS'.split('').forEach((d, i) =>
          text(ctx, d, gx + i * cs, cy - h / 2 + 150, { size: 30, weight: 700, color: P.sub, alpha: seg(t, t0, 0.4) }));
        for (let i = 0; i < 28; i++) {
          const x = gx + (i % 7) * cs;
          const y = cy - h / 2 + 230 + Math.floor(i / 7) * cs;
          const k = seg(t, t0 + 0.4 + i * 0.07, 0.3);
          const played = i < 23 && i !== 9 && i !== 16;
          const today = i === 23;
          ctx.save();
          ctx.globalAlpha *= seg(t, t0 + 0.2, 0.4);
          ctx.beginPath();
          ctx.arc(x, y, 36 * (played ? 0.7 + 0.3 * ease.back(k) : 1), 0, Math.PI * 2);
          if (played && k > 0) {
            ctx.fillStyle = (i === 9 || i === 16) ? P.present : P.correct;
            ctx.fill();
          } else if (today) {
            ctx.strokeStyle = P.primary;
            ctx.lineWidth = 5 + 2 * Math.sin(t * 5);
            ctx.stroke();
          }
          ctx.restore();
          text(ctx, String(i + 1), x, y + 1, {
            size: 30, weight: 700, alpha: seg(t, t0 + 0.2, 0.4),
            color: played && k > 0.5 ? '#FFFFFF' : P.sub,
          });
          if (played && i % 2 === 0 && k > 0 && k < 0.2) ev.push('pop');
        }
        break;
      }
      case 'practice': {
        const items = [['4', 'Easy', P.correct], ['5', 'Classic', P.present], ['6', 'Hard', P.button]];
        items.forEach(([n, label, c], i) => {
          const k = ease.back(seg(t, t0 + i * 0.25, 0.5));
          const x = cx + (i - 1) * 290;
          const float = Math.sin(t * 2 + i) * 10;
          ctx.save();
          ctx.translate(x, cy + float);
          ctx.scale(k, k);
          card(ctx, P, -125, -170, 250, 340);
          ctx.fillStyle = c;
          ctx.beginPath();
          ctx.roundRect(-65, -115, 130, 130, 16);
          ctx.fill();
          text(ctx, n, 0, -48, { size: 76, weight: 900, color: '#FFFFFF' });
          text(ctx, n + ' letters', 0, 70, { size: 36, weight: 800, color: P.text });
          text(ctx, label, 0, 118, { size: 30, weight: 600, color: P.sub });
          ctx.restore();
        });
        break;
      }
      case 'theme': {
        const w = 760;
        const h = 700;
        const x = cx - w / 2;
        const y = cy - h / 2;
        const split = cx + Math.sin(lt * 1.6) * 300;
        const k = seg(t, t0, 0.5);
        ctx.save();
        ctx.globalAlpha *= k;
        ctx.beginPath();
        ctx.roundRect(x, y, w, h, 48);
        ctx.clip();
        [['light', x, split - x], ['dark', split, x + w - split]].forEach(([m, sx, sw]) => {
          const Q = PAL[m];
          ctx.save();
          ctx.beginPath();
          ctx.rect(sx, y, sw, h);
          ctx.clip();
          ctx.fillStyle = Q.bg;
          ctx.fillRect(x, y, w, h);
          logo(ctx, Q, cx, y + 90, 56, 99, 0);
          const rows = [['stare', 'apaap'], ['heart', 'cpcpc'], ['earth', 'ccccc']];
          rows.forEach(([wd, st], r) => {
            const states = st.split('').map((c) => STATE[c]);
            guessRow(ctx, Q, cx, y + 230 + r * 120, 104, 12, wd, states, 99, 0, 0);
          });
          emptyRow(ctx, Q, cx, y + 590, 104, 12, 5);
          ctx.restore();
        });
        ctx.restore();
        ctx.save();
        ctx.globalAlpha *= k;
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(split - 3, y, 6, h);
        ctx.beginPath();
        ctx.arc(split, cy, 40, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = P.button;
        ctx.beginPath();
        ctx.arc(split, cy, 18, Math.PI * 0.5, Math.PI * 1.5);
        ctx.fill();
        ctx.restore();
        break;
      }
      case 'share': {
        const grid = ['apaap', 'apcpa', 'ccapc', 'ccccc'];
        const s = 96;
        grid.forEach((row, r) => {
          row.split('').forEach((c, i) => {
            const k = ease.back(seg(t, t0 + r * 0.4 + i * 0.06, 0.35));
            const x = cx + (i - 2) * (s + 14);
            const y = cy - 230 + r * (s + 14);
            ctx.save();
            ctx.translate(x, y);
            ctx.scale(k, k);
            ctx.fillStyle = P[STATE[c]];
            ctx.beginPath();
            ctx.roundRect(-s / 2, -s / 2, s, s, 14);
            ctx.fill();
            ctx.restore();
          });
        });
        const tk = ease.out(seg(t, t0 + 2.3, 0.5));
        if (tk > 0) {
          ctx.save();
          ctx.translate(cx, cy + 300 + (1 - tk) * 80);
          ctx.globalAlpha *= tk;
          ctx.fillStyle = '#1B1D22';
          ctx.beginPath();
          ctx.roundRect(-330, -55, 660, 110, 24);
          ctx.fill();
          text(ctx, 'Result copied to clipboard', 0, 2, { size: 36, weight: 700, color: '#FFFFFF' });
          ctx.restore();
        }
        break;
      }
      case 'stats': {
        const vals = [2, 9, 21, 14, 6, 1];
        const max = 21;
        text(ctx, `${Math.round(lerp(0, 94, seg(t, t0, 1.6)))}%`, cx - 200, cy - 260, { size: 120, weight: 900, color: P.text });
        text(ctx, 'win rate', cx - 200, cy - 170, { size: 36, weight: 600, color: P.sub });
        text(ctx, `${Math.round(lerp(0, 12, seg(t, t0, 1.6)))}`, cx + 200, cy - 260, { size: 120, weight: 900, color: P.text });
        text(ctx, 'best streak', cx + 200, cy - 170, { size: 36, weight: 600, color: P.sub });
        vals.forEach((v, i) => {
          const k = ease.out(seg(t, t0 + 0.3 + i * 0.12, 0.8));
          const y = cy - 60 + i * 74;
          const w = 90 + 560 * (v / max) * k;
          text(ctx, String(i + 1), cx - 330, y, { size: 36, weight: 800, color: P.sub });
          ctx.fillStyle = i === 2 ? P.correct : P.absent;
          ctx.beginPath();
          ctx.roundRect(cx - 290, y - 28, w, 56, 10);
          ctx.fill();
          text(ctx, String(Math.round(v * k)), cx - 290 + w - 30, y + 1, { size: 30, weight: 800, color: '#FFFFFF' });
        });
        break;
      }
      case 'hint': {
        const glow = seg(t, t0 + 0.8, 0.5) * (0.8 + 0.2 * Math.sin(t * 6));
        bulb(ctx, cx, cy - 200, 160, P.present, glow);
        const fl = seg(t, t0 + 1.4, 0.5);
        const x0 = cx - rowWidth(5, 120, 12) / 2 + 60;
        for (let i = 0; i < 5; i++) {
          if (i === 2) tile(ctx, P, x0 + i * 132, cy + 150, 120, fl >= 0.5 ? 'a' : '?', 'present', { flip: fl });
          else tile(ctx, P, x0 + i * 132, cy + 150, 120, '', null);
        }
        pill(ctx, 'HINT  -2 PTS', cx, cy + 310, { k: seg(t, t0 + 2.0, 0.4), bg: P.present, color: '#FFFFFF', size: 32 });
        break;
      }
      case 'hard': {
        const k = ease.back(seg(t, t0, 0.5));
        bolt(ctx, cx, cy - 170, 200 * k, P.present);
        const states = ['correct', 'absent', 'present', 'absent', 'absent'];
        guessRow(ctx, P, cx, cy + 90, 116, 12, 'brave', states, t, t0 + 0.4, t0 + 0.9);
        emptyRow(ctx, P, cx, cy + 222, 116, 12, 5, { t, t0: t0 + 1.8 });
        const lk = seg(t, t0 + 2.1, 0.3);
        tile(ctx, P, cx - 2 * 128, cy + 222, 116, 'b', null, { pop: lk, alpha: clamp(lk * 3), border: P.correct });
        tile(ctx, P, cx + 128, cy + 222, 116, 'a', null, { pop: lk, alpha: clamp(lk * 3), border: P.present });
        pill(ctx, '+3 POINTS PER WIN', cx, cy + 330, { k: seg(t, t0 + 2.6, 0.4), bg: P.correct, color: '#FFFFFF', size: 34 });
        break;
      }
      case 'clock': {
        const k = ease.back(seg(t, t0, 0.5));
        const r = 230 * k;
        ctx.save();
        ctx.translate(cx, cy - 40);
        ctx.fillStyle = P.card;
        ctx.strokeStyle = P.primary;
        ctx.lineWidth = 14;
        ctx.beginPath();
        ctx.arc(0, 0, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        for (let i = 0; i < 12; i++) {
          const a = (i / 12) * Math.PI * 2;
          ctx.fillStyle = P.sub;
          ctx.beginPath();
          ctx.arc(Math.sin(a) * r * 0.82, -Math.cos(a) * r * 0.82, 8 * k, 0, Math.PI * 2);
          ctx.fill();
        }
        const p = ease.inOut(seg(t, t0 + 0.4, 2.2));
        const hourA = lerp(-0.9, 0, p) * Math.PI * 2 / 12 * 12 * 0.15;
        const minA = lerp(-4.5, 0, p) * Math.PI * 2;
        ctx.lineCap = 'round';
        ctx.strokeStyle = P.text;
        ctx.lineWidth = 16;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(Math.sin(hourA) * r * 0.5, -Math.cos(hourA) * r * 0.5);
        ctx.stroke();
        ctx.lineWidth = 10;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(Math.sin(minA) * r * 0.72, -Math.cos(minA) * r * 0.72);
        ctx.stroke();
        ctx.restore();
        pill(ctx, 'NEW PUZZLE', cx, cy + 300, { k: seg(t, t0 + 2.6, 0.4), bg: P.correct, color: '#FFFFFF', size: 40, shadow: true });
        break;
      }
      case 'keyboard': {
        const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
        const word = 'TYPED';
        const ks = 78;
        rows.forEach((row, r) => {
          const x0 = cx - (row.length * (ks + 10)) / 2 + ks / 2;
          row.split('').forEach((ch, i) => {
            const idx = word.indexOf(ch);
            const press = idx >= 0 ? Math.sin(Math.PI * seg(t, t0 + 0.5 + idx * 0.35, 0.25)) : 0;
            ctx.save();
            ctx.translate(x0 + i * (ks + 10), cy + 60 + r * 120 + press * 8);
            ctx.globalAlpha *= seg(t, t0, 0.4);
            ctx.fillStyle = press > 0.1 ? P.button : P.card2;
            ctx.beginPath();
            ctx.roundRect(-ks / 2, -52, ks, 104, 12);
            ctx.fill();
            text(ctx, ch, 0, 2, { size: 36, weight: 700, color: press > 0.1 ? '#FFFFFF' : P.text });
            ctx.restore();
          });
        });
        const x0 = cx - rowWidth(5, 116, 12) / 2 + 58;
        for (let i = 0; i < 5; i++) {
          const ti = t0 + 0.5 + i * 0.35;
          tile(ctx, P, x0 + i * 128, cy - 200, 116, t >= ti ? word[i] : '', null, { pop: seg(t, ti, 0.14) });
        }
        break;
      }
    }
    return ev;
  }

  // ------------------------------------------------------------ timelines

  // Collects sound cues while a scene lays out its timeline.
  function cues() {
    const list = [];
    return {
      list,
      add: (t, type) => list.push({ t: +t.toFixed(3), type }),
      typing: (t0, n, step = 0.07) => { for (let i = 0; i < n; i++) list.push({ t: +(t0 + i * step).toFixed(3), type: 'type' }); },
      flips: (t0, n, step = 0.15) => { for (let i = 0; i < n; i++) list.push({ t: +(t0 + i * step + 0.2).toFixed(3), type: 'flip' }); },
    };
  }

  // Schedules guesses one after another; returns the time the last flip lands.
  function schedule(guesses, t0, cue, o = {}) {
    const step = o.typeStep ?? 0.07;
    const fstep = o.flipStep ?? 0.15;
    let t = t0;
    return {
      rows: guesses.map((g) => {
        const n = g.word.length;
        const row = { ...g, tType: t, tFlip: t + n * step + 0.25 };
        cue.typing(t, n, step);
        cue.flips(row.tFlip, n, fstep);
        t = row.tFlip + (n - 1) * fstep + 0.4 + (o.pause ?? 0.3);
        row.tDone = row.tFlip + (n - 1) * fstep + 0.4;
        return row;
      }),
      end: t,
    };
  }

  function statesOf(spec) {
    const [word, st] = spec.split(':');
    return { word, states: st.split('').map((c) => STATE[c]) };
  }

  const TILE = { 4: 136, 5: 124, 6: 112 };
  const titleCase = (w) => w.toUpperCase();

  // ----------------------------------------------------------------- reels

  function reelHeader(ctx, P, t, d, label) {
    logo(ctx, P, 540, 190, 74, t, 0.05);
    pill(ctx, label, 540, 300, { k: seg(t, 0.5, 0.4), bg: P.card2, color: P.sub, size: 32, border: P.line });
  }

  function reel(d) {
    const W = 1080;
    const H = 1920;
    const P = PAL.dark;
    const cue = cues();
    const r = d.reel;
    const L = d.length;
    const chip = `DAILY #${d.day}  ·  ${d.dateLabel.toUpperCase()}`;
    const playLabel = `Play Daily #${d.day}`;
    const playSub = 'Free to play  ·  link in bio';
    let dur;
    let draw;
    cue.add(0.05, 'whoosh');

    if (r.type === 'launch') {
      dur = 15;
      for (let i = 0; i < 6; i++) cue.add(0.4 + i * 0.12 + 0.2, 'flip');
      cue.add(2.6, 'whoosh');
      const rows = [
        ['crane', ['correct', null, null, null, null], 'C is in the right spot'],
        ['pilot', [null, null, 'present', null, null], 'L is in the wrong spot'],
        ['vague', [null, null, null, 'absent', null], 'U is not in the word'],
      ].map(([word, states, label], i) => {
        const tt = 5.2 + i * 1.2;
        cue.typing(tt, 5, 0.05);
        cue.add(tt + 0.4 + 0.2 + states.findIndex(Boolean) * 0.08, 'flip');
        return { word, states, label, tt };
      });
      cue.add(9.8, 'whoosh');
      for (let i = 0; i < L; i++) cue.add(10.4 + i * 0.08, 'pop');
      cue.add(12, 'chime');
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        const mv = ease.inOut(seg(t, 2.4, 0.8));
        logo(ctx, P, 540, lerp(760, 190, mv), lerp(132, 74, mv), t, 0.4);
        pill(ctx, chip, 540, 300, { k: seg(t, 3.0, 0.4), bg: P.card2, color: P.sub, size: 32, border: P.line });
        fade(ctx, 1 - seg(t, 9.4, 0.4), () => {
          headline(ctx, 'One word. Every day.', 540, 470, t, 3.2, { size: 116, lines: 2, maxW: 700, color: P.text, accent: ['Every', 'day.'], accentColor: P.primary });
          para(ctx, 'The same puzzle for everyone. 4 to 6 letters, 6 tries.', 540, 735, t, 4.2, { size: 40, color: P.sub, maxW: 820 });
          rows.forEach((row, i) => {
            const y = 950 + i * 210;
            guessRow(ctx, P, 540, y, 112, 12, row.word, row.states, t, row.tt, row.tt + 0.4, { typeStep: 0.05, flipStep: 0.08 });
            text(ctx, row.label, 540, y + 90, { size: 34, weight: 700, color: P.sub, alpha: seg(t, row.tt + 0.9, 0.3) });
          });
        });
        fade(ctx, seg(t, 9.8, 0.4), () => {
          headline(ctx, 'Day 1 is live', 540, 620, t, 9.8, { size: 120, color: P.text, accent: ['live'], accentColor: P.correct });
          emptyRow(ctx, P, 540, 880, TILE[L], 12, L, { t, t0: 10.4, step: 0.08, letter: '?', letterColor: P.sub });
          text(ctx, `${L} letters  ·  6 tries  ·  1 shot a day`, 540, 1040, { size: 40, weight: 700, color: P.sub, alpha: seg(t, 11, 0.4) });
        });
        cta(ctx, P, t, 12, 540, 1480, playLabel, playSub);
      };
    }

    if (r.type === 'hint') {
      dur = 14;
      cue.add(0.9, 'pop');
      for (let i = 0; i < L; i++) cue.add(2.0 + i * 0.12, 'pop');
      const clueT = 3.8;
      const cps = 34;
      for (let i = 0; i < d.clue.length; i += 2) cue.add(clueT + i / cps, 'type');
      const factT = clueT + d.clue.length / cps + 0.5;
      [0, 1, 2].forEach((i) => cue.add(factT + i * 0.25, 'pop'));
      cue.add(factT + 1.6, 'whoosh');
      cue.add(factT + 2.6, 'chime');
      const doubles = new Set(d.word).size < d.word.length;
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        reelHeader(ctx, P, t, d, chip);
        pill(ctx, 'HINT', 540, 440, { k: seg(t, 0.8, 0.4), bg: P.present, color: '#FFFFFF', size: 32 });
        headline(ctx, 'Stuck on today?', 540, 570, t, 1.0, { size: 104, color: P.text });
        const s = TILE[L];
        const x0 = 540 - rowWidth(L, s, 12) / 2 + s / 2;
        for (let i = 0; i < L; i++) {
          const k = seg(t, 2.0 + i * 0.12, 0.45);
          const drop = (1 - ease.back(k)) * -260;
          tile(ctx, P, x0 + i * (s + 12), 780 + drop, s, '?', null, { alpha: clamp(k * 3), letterColor: P.sub, pop: seg(t, 2.3 + i * 0.12, 0.2) });
        }
        const ck = ease.out(seg(t, 3.4, 0.5));
        card(ctx, P, 90, 920 + (1 - ck) * 40, 900, 300, { alpha: ck });
        fade(ctx, ck, () => {
          text(ctx, '“', 150, 990, { size: 140, weight: 900, color: P.primary, align: 'left' });
          const shown = d.clue.slice(0, Math.floor(clamp((t - clueT) * cps, 0, d.clue.length)));
          const lines = wrap(ctx, d.clue, 740, 52, 700);
          let used = 0;
          lines.forEach((l, i) => {
            const part = shown.slice(used, used + l.length);
            used += l.length + 1;
            text(ctx, part, 540, 1040 + i * 66 - (lines.length - 1) * 33 + 30, { size: 52, weight: 700, color: P.text });
          });
        });
        const facts = [`${L} letters`, `${d.vowels} vowel${d.vowels === 1 ? '' : 's'}`, doubles ? 'Has a double letter' : 'No repeats'];
        const fw = [];
        facts.forEach((f) => { setFont(ctx, 34, 800); fw.push(ctx.measureText(f).width + 64); });
        let fx = 540 - (fw.reduce((a, b) => a + b, 0) + 20 * (facts.length - 1)) / 2;
        facts.forEach((f, i) => {
          pill(ctx, f, fx + fw[i] / 2, 1300, { k: seg(t, factT + i * 0.25, 0.4), bg: P.card2, color: P.text, size: 34, spacing: 0, border: P.filled });
          fx += fw[i] + 20;
        });
        fade(ctx, seg(t, factT + 1.4, 0.4), () => {
          text(ctx, 'Comment your first guess', 540, 1400, { size: 44, weight: 800, color: P.text });
          arrowDown(ctx, P.primary, 540, 1460, t);
        });
        cta(ctx, P, t, factT + 2.4, 540, 1580, playLabel, null);
      };
      dur = factT + 5.5;
    }

    if (r.type === 'replay') {
      const prevL = d.prev.length;
      const s = TILE[prevL];
      const sch = schedule(r.guesses, 2.2, cue);
      const last = sch.rows[sch.rows.length - 1];
      const tWin = last.tDone + 0.1;
      cue.add(tWin, 'win');
      cue.add(tWin + 1.8, 'whoosh');
      cue.add(tWin + 2.4, 'chime');
      dur = tWin + 5;
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        reelHeader(ctx, P, t, d, `DAILY #${d.day - 1} REPLAY`);
        headline(ctx, "Yesterday's answer", 540, 430, t, 0.6, { size: 92, color: P.text });
        text(ctx, `Spoiler for Daily #${d.day - 1}`, 540, 520, { size: 36, weight: 700, color: P.present, alpha: seg(t, 1.2, 0.4) });
        const top = 610 + s / 2;
        for (let rI = 0; rI < 6; rI++) {
          const y = top + rI * (s + 12);
          const row = sch.rows[rI];
          if (row) {
            emptyRow(ctx, P, 540, y, s, 12, prevL, { t, t0: 1.3 + rI * 0.06 });
            guessRow(ctx, P, 540, y, s, 12, row.word, row.states, t, row.tType, row.tFlip, { tWin: row === last ? tWin : null });
          } else emptyRow(ctx, P, 540, y, s, 12, prevL, { t, t0: 1.3 + rI * 0.06 });
        }
        confetti(ctx, P, t, tWin, 540, top + (sch.rows.length - 1) * (s + 12), 110, d.day);
        const bannerY = top + 6 * (s + 12) + 20;
        const fadeOut = 1 - seg(t, tWin + 1.8, 0.3);
        pill(ctx, `SOLVED IN ${sch.rows.length}/6`, 540, bannerY, { k: seg(t, tWin + 0.4, 0.4) * fadeOut, bg: P.correct, color: '#FFFFFF', size: 38, shadow: true });
        fade(ctx, seg(t, tWin + 1.9, 0.4), () => {
          text(ctx, `Daily #${d.day} is live  ·  ${L} letters`, 540, bannerY, { size: 42, weight: 800, color: P.text });
        });
        cta(ctx, P, t, tWin + 2.4, 540, bannerY + 140, playLabel, null);
      };
    }

    if (r.type === 'pause') {
      const s = 124;
      const clues = r.guesses.slice(0, -1);
      const answer = r.guesses[r.guesses.length - 1];
      const sch = schedule(clues, 2.0, cue, { typeStep: 0.05, flipStep: 0.12, pause: 0.15 });
      const tc = sch.end + 0.4;
      for (let i = 0; i < 5; i++) cue.add(tc + i, 'tick');
      const tr = tc + 5;
      const rev = schedule([answer], tr, cue, { typeStep: 0.06, flipStep: 0.12 });
      const tWin = rev.rows[0].tDone + 0.05;
      cue.add(tWin, 'win');
      cue.add(tWin + 2.2, 'chime');
      dur = tWin + 5.2;
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day + 50);
        reelHeader(ctx, P, t, d, 'PAUSE & SOLVE');
        headline(ctx, 'Can you solve it?', 540, 430, t, 0.6, { size: 96, color: P.text });
        text(ctx, `Practice puzzle  ·  clue: ${r.clue}`, 540, 520, { size: 32, weight: 600, color: P.sub, alpha: seg(t, 1.2, 0.4) });
        const top = 600 + s / 2;
        const qRow = clues.length;
        for (let i = 0; i < 6; i++) {
          const y = top + i * (s + 12);
          emptyRow(ctx, P, 540, y, s, 12, 5, { t, t0: 1.3 + i * 0.06 });
          if (i < qRow) guessRow(ctx, P, 540, y, s, 12, sch.rows[i].word, sch.rows[i].states, t, sch.rows[i].tType, sch.rows[i].tFlip, { typeStep: 0.05, flipStep: 0.12 });
          if (i === qRow) {
            if (t < tr) {
              const pulse = 0.5 + 0.5 * Math.sin(t * 6);
              emptyRow(ctx, P, 540, y, s, 12, 5, {
                letter: '?', letterColor: P.primary, alpha: seg(t, tc - 0.3, 0.3),
                border: hexA(P.primary, 0.5 + 0.5 * pulse),
              });
            } else {
              guessRow(ctx, P, 540, y, s, 12, answer.word, answer.states, t, rev.rows[0].tType, rev.rows[0].tFlip, { typeStep: 0.06, flipStep: 0.12, tWin });
            }
          }
        }
        confetti(ctx, P, t, tWin, 540, top + qRow * (s + 12), 110, d.day + 3);
        const by = top + 6 * (s + 12) + 40;
        if (t >= tc - 0.3 && t < tr) {
          const left = Math.ceil(tr - t);
          const frac = (tr - t) % 1;
          const k = seg(t, tc - 0.3, 0.3);
          ctx.save();
          ctx.globalAlpha *= k;
          ctx.translate(250, by + 10);
          ctx.strokeStyle = P.line;
          ctx.lineWidth = 12;
          ctx.beginPath();
          ctx.arc(0, 0, 66, 0, Math.PI * 2);
          ctx.stroke();
          ctx.strokeStyle = P.present;
          ctx.lineCap = 'round';
          ctx.beginPath();
          ctx.arc(0, 0, 66, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ((tr - t) / 5));
          ctx.stroke();
          text(ctx, String(left), 0, 2, { size: 72 * (1 + 0.15 * frac), weight: 900, color: P.text });
          ctx.restore();
          text(ctx, 'Pause now and', 620, by - 22, { size: 40, weight: 700, color: P.sub, alpha: k });
          text(ctx, 'comment your answer', 620, by + 34, { size: 44, weight: 800, color: P.text, alpha: k });
        }
        fade(ctx, seg(t, tWin + 0.3, 0.4) * (1 - seg(t, tWin + 2.0, 0.3)), () => {
          text(ctx, `It was ${titleCase(answer.word)}! Did you get it?`, 540, by, { size: 46, weight: 800, color: P.text });
        });
        fade(ctx, seg(t, tWin + 2.1, 0.4), () => {
          text(ctx, `Now try today's real one`, 540, by - 20, { size: 40, weight: 700, color: P.sub });
        });
        cta(ctx, P, t, tWin + 2.2, 540, by + 90, playLabel, null);
      };
    }

    if (r.type === 'tip') {
      const tip = r.tip;
      const demo = tip.demo.map(statesOf);
      let tt = 3.6;
      const rows = demo.map((g) => {
        const sch = schedule([g], tt, cue, { typeStep: 0.06, flipStep: 0.12 });
        tt = sch.end;
        return sch.rows[0];
      });
      const tEnd = Math.max(tt, 6.5);
      cue.add(tEnd + 0.4, 'chime');
      dur = tEnd + 4.6;
      const idx = Math.floor(d.day / 5) + 1;
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        reelHeader(ctx, P, t, d, `PRO TIP #${idx}`);
        headline(ctx, tip.title, 540, 470, t, 0.7, { size: 108, color: P.text });
        para(ctx, tip.body, 540, 640, t, 1.8, { size: 44, color: P.sub, maxW: 840 });
        const n = rows.length;
        rows.forEach((row, i) => {
          const len = row.word.length;
          const s = Math.min(TILE[len] || 112, 124);
          const y = 1020 + (i - (n - 1) / 2) * (s + 40);
          emptyRow(ctx, P, 540, y, s, 12, len, { t, t0: 3.0 + i * 0.1 });
          guessRow(ctx, P, 540, y, s, 12, row.word, row.states, t, row.tType, row.tFlip, { typeStep: 0.06, flipStep: 0.12 });
        });
        cta(ctx, P, t, tEnd + 0.4, 540, 1480, 'Try it today', playSub);
      };
    }

    if (r.type === 'feature') {
      const f = r.feature;
      dur = 12;
      cue.add(3.0, 'whoosh');
      [3.4, 3.8, 4.2, 4.6, 5.0].forEach((x) => cue.add(x, 'pop'));
      cue.add(8.2, 'chime');
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        reelHeader(ctx, P, t, d, 'IN THE APP');
        headline(ctx, f.title, 540, 470, t, 0.7, { size: 112, color: P.text });
        para(ctx, f.body, 540, 620, t, 1.8, { size: 44, color: P.sub, maxW: 820 });
        illustration(ctx, P, f.icon, t, 3.0, 540, 1080);
        cta(ctx, P, t, 8.2, 540, 1520, playLabel, playSub);
      };
    }

    if (r.type === 'finale') {
      const past = r.past;
      const cols = 4;
      const s = 36;
      const g = 4;
      cue.add(0.6, 'pop');
      past.forEach((_, i) => { if (i % 3 === 0) cue.add(2.6 + i * 0.07, 'flip'); });
      const tWall = 2.6 + past.length * 0.07 + 0.5;
      cue.add(tWall + 0.2, 'win');
      cue.add(tWall + 2.6, 'chime');
      dur = tWall + 6;
      draw = (ctx, t) => {
        background(ctx, P, t, W, H, d.day);
        reelHeader(ctx, P, t, d, chip);
        headline(ctx, '50 days. 49 words.', 540, 450, t, 0.6, { size: 104, color: P.text, accent: ['49', 'words.'], accentColor: P.correct });
        const rows = Math.ceil(past.length / cols);
        past.forEach((w, i) => {
          const c = i % cols;
          const rI = Math.floor(i / cols);
          const cx = 540 + (c - (cols - 1) / 2) * 245;
          const y = 720 + rI * (s + 16);
          const tt = 2.6 + i * 0.07;
          const x0 = cx - rowWidth(w.length, s, g) / 2 + s / 2;
          for (let j = 0; j < w.length; j++) {
            const k = seg(t, tt + j * 0.03, 0.3);
            tile(ctx, P, x0 + j * (s + g), y, s, w[j], 'correct', { flip: k, alpha: clamp(k * 4) });
          }
        });
        const yEnd = 720 + rows * (s + 16);
        confetti(ctx, P, t, tWall + 0.2, 540, 720, 140, 50);
        fade(ctx, seg(t, tWall + 0.6, 0.5), () => {
          text(ctx, 'How many did you get?', 540, yEnd + 50, { size: 50, weight: 800, color: P.text });
          text(ctx, 'Thanks for playing. Word 50 is waiting.', 540, yEnd + 120, { size: 36, weight: 600, color: P.sub });
        });
        cta(ctx, P, t, tWall + 2.6, 540, yEnd + 250, playLabel, null);
      };
    }

    return { w: W, h: H, dur: +dur.toFixed(2), events: cue.list, draw };
  }

  // ----------------------------------------------------------------- posts

  // Each post is a two-slide carousel. Slides animate in, and the video
  // version swipes from the first to the second.
  function postSlides(d) {
    const P = PAL.light;
    const p = d.post;
    const L = d.length;
    const W = 1080;
    const H = 1350;

    const frame = (ctx, t, k, n) => {
      background(ctx, P, t, W, H, d.day + k * 9);
      logo(ctx, P, 540, 100, 50, t, 0);
      // Carousel dots.
      for (let i = 0; i < n; i++) {
        ctx.fillStyle = i === k ? P.button : P.empty;
        ctx.beginPath();
        ctx.arc(540 + (i - (n - 1) / 2) * 30, 1290, 9, 0, Math.PI * 2);
        ctx.fill();
      }
    };
    const swipe = (ctx, t, t0, y) => {
      fade(ctx, seg(t, t0, 0.4), () => {
        text(ctx, 'Swipe', 520, y, { size: 36, weight: 800, color: P.primary, align: 'right' });
        const b = Math.sin(t * 5) * 10;
        ctx.save();
        ctx.translate(560 + b, y);
        ctx.strokeStyle = P.primary;
        ctx.lineWidth = 7;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(-14, -18);
        ctx.lineTo(8, 0);
        ctx.lineTo(-14, 18);
        ctx.stroke();
        ctx.restore();
      });
    };
    const handle = (ctx, t, s) => text(ctx, s, 540, 1235, { size: 30, weight: 600, color: P.sub, alpha: seg(t, 0.6, 0.4) });
    const ts = Math.min(TILE[L], 120);

    let slides = [];
    let cue = cues();

    if (p.type === 'teaser') {
      const doubles = new Set(d.word).size < d.word.length;
      for (let i = 0; i < L; i++) cue.add(1.4 + i * 0.08, 'pop');
      slides = [
        (ctx, t) => {
          frame(ctx, t, 0, 2);
          pill(ctx, `DAILY #${d.day}`, 540, 210, { k: seg(t, 0.2, 0.4), bg: P.button, color: '#FFFFFF', size: 28 });
          text(ctx, d.dateLabel, 540, 290, { size: 38, weight: 700, color: P.sub, alpha: seg(t, 0.4, 0.4) });
          headline(ctx, d.day === 1 ? 'Day one starts now' : "Today's puzzle is live", 540, 410, t, 0.5, { size: 88, color: P.text, maxW: 900 });
          emptyRow(ctx, P, 540, 640, ts, 12, L, { t, t0: 1.4, step: 0.08, letter: '?', letterColor: P.filled });
          const ck = ease.out(seg(t, 2.0, 0.5));
          card(ctx, P, 110, 760, 860, 230, { alpha: ck });
          fade(ctx, ck, () => {
            text(ctx, 'CLUE', 540, 815, { size: 26, weight: 800, color: P.primary, spacing: 3 });
            para(ctx, d.clue, 540, 875, t, 2.1, { size: 46, weight: 700, color: P.text, maxW: 760, lh: 58 });
          });
          pill(ctx, 'Play now  ·  link in bio', 540, 1070, { k: seg(t, 2.6, 0.4), bg: P.button, color: '#FFFFFF', size: 34, icon: 'play', spacing: 0 });
          swipe(ctx, t, 3.0, 1170);
        },
        (ctx, t) => {
          frame(ctx, t, 1, 2);
          headline(ctx, 'The hint ladder', 540, 240, t, 0.1, { size: 92, color: P.text });
          text(ctx, 'Only climb as far as you need', 540, 340, { size: 36, weight: 600, color: P.sub, alpha: seg(t, 0.4, 0.4) });
          const rungs = [
            ['1', `${L} letters, ${d.vowels} vowel${d.vowels === 1 ? '' : 's'}`],
            ['2', doubles ? 'One letter shows up twice' : 'No letter repeats'],
            ['3', `It starts with ${d.word[0].toUpperCase()}`],
          ];
          rungs.forEach(([n, s], i) => {
            const k = ease.out(seg(t, 0.6 + i * 0.35, 0.5));
            const y = 470 + i * 190;
            card(ctx, P, 110 + (1 - k) * 60, y - 75, 860, 150, { alpha: k });
            fade(ctx, k, () => {
              tile(ctx, P, 200 + (1 - k) * 60, y, 92, n, ['correct', 'present', 'absent'][i]);
              text(ctx, s, 280 + (1 - k) * 60, y + 2, { size: 42, weight: 700, color: P.text, align: 'left' });
            });
          });
          fade(ctx, seg(t, 1.8, 0.4), () => {
            text(ctx, 'Comment your first guess below', 540, 1060, { size: 44, weight: 800, color: P.text });
            text(ctx, "We'll reveal the answer tomorrow", 540, 1125, { size: 34, weight: 600, color: P.sub });
          });
          handle(ctx, t, `Daily #${d.day}  ·  ${d.date}`);
        },
      ];
    }

    if (p.type === 'guess' || p.type === 'recap' || p.type === 'fill') {
      let answer;
      let first;
      if (p.type === 'guess') {
        answer = p.answer;
        const sch = schedule(p.guesses, 1.2, cue, { typeStep: 0.05, flipStep: 0.1, pause: 0.1 });
        const s = 112;
        first = (ctx, t) => {
          frame(ctx, t, 0, 2);
          pill(ctx, 'GUESS THE WORD', 540, 210, { k: seg(t, 0.2, 0.4), bg: P.present, color: '#FFFFFF', size: 28 });
          headline(ctx, `Solve it in ${p.guesses.length + 1}?`, 540, 320, t, 0.4, { size: 88, color: P.text });
          const n = p.guesses.length + 1;
          const top = 470;
          sch.rows.forEach((row, i) => {
            const y = top + i * (s + 12);
            emptyRow(ctx, P, 540, y, s, 12, 5, { t, t0: 0.8 + i * 0.05 });
            guessRow(ctx, P, 540, y, s, 12, row.word, row.states, t, row.tType, row.tFlip, { typeStep: 0.05, flipStep: 0.1 });
          });
          const pulse = 0.5 + 0.5 * Math.sin(t * 5);
          emptyRow(ctx, P, 540, top + (n - 1) * (s + 12), s, 12, 5, {
            t, t0: sch.end, letter: '?', letterColor: P.primary, border: hexA(P.primary, 0.4 + 0.6 * pulse),
          });
          const by = top + n * (s + 12) + 10;
          text(ctx, `Clue: ${p.clue}`, 540, by, { size: 34, weight: 600, color: P.sub, alpha: seg(t, sch.end, 0.4) });
          text(ctx, 'Comment your answer', 540, by + 70, { size: 42, weight: 800, color: P.text, alpha: seg(t, sch.end + 0.2, 0.4) });
          swipe(ctx, t, sch.end + 0.4, by + 150);
        };
      }
      if (p.type === 'recap') {
        answer = d.prev;
        first = (ctx, t) => {
          frame(ctx, t, 0, 2);
          pill(ctx, `DAILY #${d.day - 1} RECAP`, 540, 210, { k: seg(t, 0.2, 0.4), bg: P.absent, color: '#FFFFFF', size: 28 });
          headline(ctx, "Yesterday's answer", 540, 330, t, 0.4, { size: 92, color: P.text });
          emptyRow(ctx, P, 540, 560, Math.min(TILE[answer.length], 120), 12, answer.length, { t, t0: 1.0, step: 0.08, letter: '?', fill: P.card2, letterColor: P.filled });
          const ck = ease.out(seg(t, 1.6, 0.5));
          card(ctx, P, 110, 690, 860, 210, { alpha: ck });
          fade(ctx, ck, () => {
            text(ctx, 'THE CLUE WAS', 540, 745, { size: 26, weight: 800, color: P.primary, spacing: 3 });
            para(ctx, p.clue, 540, 805, t, 1.7, { size: 44, weight: 700, color: P.text, maxW: 760, lh: 56 });
          });
          text(ctx, 'Did you get it? Comment your score', 540, 1000, { size: 40, weight: 800, color: P.text, alpha: seg(t, 2.2, 0.4) });
          swipe(ctx, t, 2.5, 1100);
        };
      }
      if (p.type === 'fill') {
        answer = p.answer;
        for (let i = 0; i < 5; i++) cue.add(1.0 + i * 0.1, 'pop');
        first = (ctx, t) => {
          frame(ctx, t, 0, 2);
          pill(ctx, 'FILL THE GAPS', 540, 210, { k: seg(t, 0.2, 0.4), bg: P.correct, color: '#FFFFFF', size: 28 });
          headline(ctx, 'Finish the word', 540, 330, t, 0.4, { size: 96, color: P.text });
          const s = 130;
          const x0 = 540 - rowWidth(5, s, 14) / 2 + s / 2;
          for (let i = 0; i < 5; i++) {
            const c = p.pattern[i];
            const k = ease.back(seg(t, 1.0 + i * 0.1, 0.4));
            if (c === '_') tile(ctx, P, x0 + i * (s + 14), 560, s, '', null, { scale: k, alpha: clamp(k * 2), border: hexA(P.primary, 0.5 + 0.5 * Math.sin(t * 5 + i)) });
            else tile(ctx, P, x0 + i * (s + 14), 560, s, c, 'correct', { scale: k, alpha: clamp(k * 2) });
          }
          const ck = ease.out(seg(t, 1.7, 0.5));
          card(ctx, P, 110, 700, 860, 200, { alpha: ck });
          fade(ctx, ck, () => {
            text(ctx, 'CLUE', 540, 755, { size: 26, weight: 800, color: P.primary, spacing: 3 });
            para(ctx, p.clue, 540, 815, t, 1.8, { size: 44, weight: 700, color: P.text, maxW: 760, lh: 56 });
          });
          text(ctx, 'Type your answer in the comments', 540, 1000, { size: 40, weight: 800, color: P.text, alpha: seg(t, 2.3, 0.4) });
          swipe(ctx, t, 2.6, 1100);
        };
      }
      const revealT = 0.5;
      const states = answer.split('').map(() => 'correct');
      const n = answer.length;
      const s2 = Math.min(TILE[n] || 124, 130);
      const second = (ctx, t) => {
        frame(ctx, t, 1, 2);
        pill(ctx, 'THE ANSWER', 540, 210, { k: seg(t, 0.1, 0.4), bg: P.correct, color: '#FFFFFF', size: 28 });
        guessRow(ctx, P, 540, 430, s2, 14, answer, states, t, revealT, revealT + 0.1 + n * 0.06, { typeStep: 0.06, flipStep: 0.12, tWin: revealT + 1.2 + n * 0.18 });
        confetti(ctx, P, t, revealT + 1.2 + n * 0.18, 540, 430, 80, d.day);
        headline(ctx, `${titleCase(answer)}`, 540, 640, t, 1.6, { size: 120, color: P.correct });
        if (p.type === 'recap') {
          text(ctx, `Daily #${d.day} is live now`, 540, 820, { size: 48, weight: 800, color: P.text, alpha: seg(t, 2.2, 0.4) });
          text(ctx, `${L} letters  ·  can you keep your streak?`, 540, 885, { size: 36, weight: 600, color: P.sub, alpha: seg(t, 2.3, 0.4) });
          pill(ctx, 'Play now  ·  link in bio', 540, 1020, { k: seg(t, 2.6, 0.4), bg: P.button, color: '#FFFFFF', size: 34, icon: 'play', spacing: 0 });
        } else {
          text(ctx, 'Did you get it?', 540, 820, { size: 52, weight: 800, color: P.text, alpha: seg(t, 2.2, 0.4) });
          text(ctx, 'Reply with a  ✓  or a  ✗  below', 540, 890, { size: 38, weight: 600, color: P.sub, alpha: seg(t, 2.3, 0.4) });
          pill(ctx, `Now play Daily #${d.day}`, 540, 1020, { k: seg(t, 2.6, 0.4), bg: P.button, color: '#FFFFFF', size: 34, icon: 'play', spacing: 0 });
        }
        handle(ctx, t, `Daily Wordle  ·  ${d.dateLabel}`);
      };
      slides = [first, second];
    }

    if (p.type === 'poll') {
      const poll = p.poll;
      [0, 1, 2, 3].forEach((i) => cue.add(1.3 + i * 0.2, 'pop'));
      const letters = 'ABCD';
      const colors = ['correct', 'present', 'button', 'absent'];
      slides = [
        (ctx, t) => {
          frame(ctx, t, 0, 2);
          pill(ctx, 'POLL', 540, 210, { k: seg(t, 0.2, 0.4), bg: P.button, color: '#FFFFFF', size: 28 });
          const h = headline(ctx, poll.q, 540, 320, t, 0.4, { size: 76, lines: 3, color: P.text, maxW: 900 });
          const top = 320 + h + 30;
          poll.opts.forEach((o, i) => {
            const k = ease.out(seg(t, 1.3 + i * 0.2, 0.5));
            const y = top + i * 150;
            card(ctx, P, 140 + (1 - k) * 80, y, 800, 120, { alpha: k, r: 30 });
            fade(ctx, k, () => {
              ctx.fillStyle = P[colors[i]];
              ctx.beginPath();
              ctx.roundRect(170 + (1 - k) * 80, y + 18, 84, 84, 14);
              ctx.fill();
              text(ctx, letters[i], 212 + (1 - k) * 80, y + 62, { size: 46, weight: 900, color: '#FFFFFF' });
              text(ctx, o, 290 + (1 - k) * 80, y + 62, { size: 42, weight: 700, color: P.text, align: 'left' });
            });
          });
          text(ctx, 'Vote in the comments: A, B, C or D', 540, top + 4 * 150 + 50, { size: 38, weight: 800, color: P.primary, alpha: seg(t, 2.3, 0.4) });
          swipe(ctx, t, 2.6, top + 4 * 150 + 130);
        },
        (ctx, t) => {
          frame(ctx, t, 1, 2);
          headline(ctx, 'Your turn', 540, 300, t, 0.1, { size: 120, color: P.text });
          const steps = ['Comment your letter', 'Tag a friend who picks differently', `Then play Daily #${d.day}`];
          steps.forEach((s, i) => {
            const k = ease.out(seg(t, 0.6 + i * 0.3, 0.5));
            const y = 520 + i * 170;
            fade(ctx, k, () => {
              tile(ctx, P, 220, y, 100, String(i + 1), ['correct', 'present', 'correct'][i], { flip: k });
              text(ctx, s, 300, y + 2, { size: 42, weight: 700, color: P.text, align: 'left' });
            });
          });
          text(ctx, 'Results in tomorrow’s story', 540, 1040, { size: 38, weight: 600, color: P.sub, alpha: seg(t, 1.8, 0.4) });
          handle(ctx, t, `Daily Wordle  ·  ${d.dateLabel}`);
        },
      ];
    }
    return { w: W, h: H, slides, events: cue.list };
  }

  // A post as one video: slide 1, a swipe, then slide 2.
  function post(d) {
    const ps = postSlides(d);
    const sw = 4.2;
    const tw = 0.45;
    const dur = 9.5;
    const events = ps.events.slice();
    events.push({ t: sw, type: 'whoosh' });
    events.push({ t: sw + 0.9, type: 'flip' }, { t: sw + 1.1, type: 'flip' }, { t: sw + 1.9, type: 'win' });
    const draw = (ctx, t) => {
      if (t < sw) return ps.slides[0](ctx, t);
      const k = ease.inOut(seg(t, sw, tw));
      if (k >= 1) return ps.slides[1](ctx, t - sw - tw * 0.5);
      ctx.save();
      ctx.translate(-ps.w * k, 0);
      ps.slides[0](ctx, sw);
      ctx.translate(ps.w, 0);
      ps.slides[1](ctx, 0);
      ctx.restore();
    };
    return { w: ps.w, h: ps.h, dur, events, draw, slides: ps.slides, still: 6 };
  }

  root.WordleSocial = { reel, post, postSlides, PAL };
})(typeof window !== 'undefined' ? window : globalThis);
