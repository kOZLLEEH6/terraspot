/*
 * Hero-Himmel: Sterne kreisen um den Himmelspol. `exposure` ist der Winkel in
 * Radiant, den die Erde während der Belichtung gedreht hat (15° pro Stunde).
 * app.js steuert exposure über die Scrollposition.
 *
 * Die Landschaft davor liegt in eigenen SVG-Ebenen ([data-land]). Ihre Pfade
 * entstehen hier einmal pro Aufbau; app.js verschiebt die Ebenen nur noch.
 * Sterne stehen im Unendlichen und bewegen sich bei der Kranfahrt nicht.
 */
(function () {
  const canvas = document.querySelector("[data-sky]");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  const COLORS = ["#ffc79a", "#ffe2c2", "#fff6ec", "#e9efff", "#c9d7ff", "#aec3ff"];
  const sky = {
    exposure: 0.004,
    spin: 0,
    running: true,
  };

  let W = 0, H = 0, DPR = 1;
  let pole = { x: 0, y: 0 };
  let buckets = [];
  let heads = [];
  let bg = null, glow = null;
  let lastW = 0, lastH = 0;

  // Glanzpunkte einmal vorrendern statt in jedem Frame neue Verläufe zu bauen
  const sprites = {};
  for (const c of COLORS) {
    const sp = document.createElement("canvas");
    sp.width = sp.height = 32;
    const g = sp.getContext("2d");
    const grd = g.createRadialGradient(16, 16, 0, 16, 16, 16);
    grd.addColorStop(0, c);
    grd.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = grd;
    g.fillRect(0, 0, 32, 32);
    sprites[c] = sp;
  }

  // kleiner deterministischer Zufallsgenerator, damit der Himmel bei jedem Besuch gleich aussieht
  function rng(seed) {
    return function () {
      seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // Bildaufbau je nach Format. Werte in Bruchteilen von Breite (u) und Höhe.
  // base/amp: mittlere Kammhöhe und Zerklüftung, peaks: [u, Höhe, Breite]
  // fore.rise: [u Beginn, u Ende, Höhe] der Hangschulter, auf deren Kante die Kamera steht
  const SCENE = {
    wide: {
      pole: [0.7, 0.3],
      glow: [0.63, 0.64],
      far: { base: 0.63, amp: 0.03, rough: 0.62, peaks: [[0.84, 0.1, 0.08], [0.95, 0.06, 0.05], [0.72, 0.035, 0.04], [0.27, 0.025, 0.1]] },
      mid: { base: 0.7, amp: 0.024, rough: 0.64, peaks: [[0.1, 0.07, 0.09], [0.4, 0.03, 0.06], [1.0, 0.065, 0.08]] },
      near: { base: 0.775, amp: 0.016, rough: 0.62, peaks: [[0.06, 0.02, 0.1], [0.3, 0.012, 0.08]], trees: 0.62 },
      fore: { base: 0.955, amp: 0.012, rough: 0.62, rise: [0.45, 0.605, 0.235], cam: 0.63,
        spruces: [[-0.008, 0.38], [0.03, 0.24], [0.8, 0.3], [0.865, 0.42], [0.918, 0.53], [0.972, 0.47], [1.03, 0.66]] },
    },
    narrow: {
      pole: [0.62, 0.3],
      glow: [0.7, 0.6],
      far: { base: 0.6, amp: 0.02, rough: 0.62, peaks: [[0.74, 0.075, 0.12], [0.16, 0.025, 0.12]] },
      mid: { base: 0.665, amp: 0.018, rough: 0.64, peaks: [[0.06, 0.04, 0.12], [0.98, 0.05, 0.1]] },
      near: { base: 0.735, amp: 0.012, rough: 0.62, peaks: [[0.5, 0.012, 0.15]], trees: 0.72 },
      fore: { base: 0.97, amp: 0.008, rough: 0.62, rise: [0.58, 0.78, 0.1], cam: 0.82,
        spruces: [[-0.07, 0.21], [0.955, 0.28], [1.06, 0.4]] },
    },
  };

  function build() {
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    W = canvas.clientWidth;
    H = canvas.clientHeight;
    canvas.width = Math.round(W * DPR);
    canvas.height = Math.round(H * DPR);
    lastW = W; lastH = H;

    const scene = W > 760 ? SCENE.wide : SCENE.narrow;
    pole = { x: W * scene.pole[0], y: H * scene.pole[1] };
    const rMax = Math.hypot(Math.max(pole.x, W - pole.x), Math.max(pole.y, H - pole.y));
    const count = Math.round(Math.min(1500, Math.max(380, (W * H) / 850)));
    const rand = rng(20261005);

    // Sterne nach Farbe und Helligkeit gruppieren: ein stroke() pro Gruppe
    buckets = [];
    for (let c = 0; c < COLORS.length; c++) {
      for (let b = 0; b < 3; b++) buckets.push({ color: COLORS[c], level: b, stars: [] });
    }
    heads = [];
    for (let i = 0; i < count; i++) {
      const r = Math.sqrt(rand()) * rMax;
      const a = rand() * Math.PI * 2;
      const m = rand();
      const level = m > 0.97 ? 2 : m > 0.8 ? 1 : 0;
      const temp = Math.min(COLORS.length - 1, Math.floor(Math.pow(rand(), 0.8) * COLORS.length));
      const star = { r, a };
      buckets[temp * 3 + level].stars.push(star);
      if (level === 2) heads.push({ star, color: COLORS[temp] });
    }
    // Polaris: fast im Pol, hell
    const polaris = { r: Math.min(W, H) * 0.012, a: 0.6 };
    buckets[2 * 3 + 2].stars.push(polaris);
    heads.push({ star: polaris, color: "#fff6ec", big: true });

    // Verläufe einmal pro Aufbau, nicht in jedem Frame.
    // Der Himmel ist über dem fernen Kamm am hellsten (Luftleuchten am Horizont).
    bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, "#04060c");
    bg.addColorStop(0.42, "#08101f");
    bg.addColorStop(scene.far.base, "#16223a");
    bg.addColorStop(1, "#16223a");
    // Restlicht hinter dem Kamm, dort steht auch die Kamera
    const gx = W * scene.glow[0], gy = H * scene.glow[1];
    glow = ctx.createRadialGradient(gx, gy, 0, gx, gy, Math.max(W, H) * 0.5);
    glow.addColorStop(0, "rgba(150, 102, 66, 0.26)");
    glow.addColorStop(0.45, "rgba(120, 82, 54, 0.08)");
    glow.addColorStop(1, "rgba(120, 82, 54, 0)");

    buildLand(scene);
  }

  // ---------- Landschaft ----------
  const r1 = (n) => Math.round(n * 10) / 10;

  // 1D-Mittelpunktverschiebung: zerklüftete Kämme statt glatter Sinuswellen
  function fractal(rand, n, rough) {
    const a = new Float32Array(n + 1);
    a[0] = rand() * 2 - 1;
    a[n] = rand() * 2 - 1;
    let scale = 1;
    for (let step = n; step > 1; step >>= 1) {
      const half = step >> 1;
      for (let i = half; i < n; i += step) a[i] = (a[i - half] + a[i + half]) / 2 + (rand() * 2 - 1) * scale;
      scale *= rough;
    }
    let m = 0;
    for (let i = 0; i <= n; i++) m = Math.max(m, Math.abs(a[i]));
    for (let i = 0; i <= n; i++) a[i] /= m || 1;
    return a;
  }

  const smooth = (a, b, x) => {
    const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  };

  // Kammlinie als y-Werte in Bühnenpixeln, gleichmäßig über die Breite verteilt
  function ridge(rand, spec) {
    const n = W > 760 ? 256 : 128;
    const fr = fractal(rand, n, spec.rough);
    const ys = new Float32Array(n + 1);
    const rise = spec.rise;
    for (let i = 0; i <= n; i++) {
      const u = i / n;
      let y = spec.base;
      // Gipfel halb rund, halb spitz: Berge statt Hügel
      for (const p of spec.peaks || []) {
        const q = (u - p[0]) / p[2];
        y -= p[1] * (0.55 * Math.exp(-q * q) + 0.45 * Math.exp(-1.6 * Math.abs(q)));
      }
      let amp = spec.amp;
      if (rise) {
        // Hang steigt zur Schulter an und fällt dahinter leicht ab; am Hang ist es felsiger
        const up = smooth(rise[0], rise[1], u);
        y -= rise[2] * (up - 0.18 * smooth(rise[1] + 0.04, 1, u));
        amp *= 1 + 2.2 * up * (1 - up) * 4;
        // kleine Felskante, auf der das Stativ steht
        y -= rise[2] * 0.06 * Math.exp(-Math.pow((u - spec.cam) / 0.025, 2));
      }
      ys[i] = (y - amp * fr[i]) * H;
    }
    return ys;
  }

  function ridgeAt(ys, x) {
    const n = ys.length - 1;
    const f = Math.max(0, Math.min(n, (x / W) * n));
    const i = Math.min(n - 1, Math.floor(f));
    return ys[i] + (ys[i + 1] - ys[i]) * (f - i);
  }

  function ridgePath(ys) {
    const n = ys.length - 1;
    let d = `M0 ${r1(H + 2)}`;
    for (let i = 0; i <= n; i++) d += `L${r1((i / n) * W)} ${r1(ys[i])}`;
    return d + `L${r1(W)} ${r1(H + 2)}Z`;
  }

  // Fichte: dünne Spitze, unregelmäßig hängende Astreihen, kurzer Stamm.
  // Beide Seiten bekommen eigene Zufallswerte, sonst wirkt der Baum gestanzt.
  function spruce(rand, x, base, h) {
    const tiers = Math.max(4, Math.min(30, Math.round(h / 6)));
    const half = h * (0.14 + rand() * 0.05);
    const crown = h * 0.94;
    const top = base - h;
    const step = crown / tiers;
    const left = [];
    let d = `M${r1(x)} ${r1(top)}`;
    for (let i = 1; i <= tiers; i++) {
      const t = (i - 0.35 + rand() * 0.5) / tiers;
      const y = top + crown * Math.min(1, t);
      const span = half * (0.06 + 0.94 * Math.pow(Math.min(1, t), 0.85));
      const sr = span * (0.68 + rand() * 0.5), sl = span * (0.68 + rand() * 0.5);
      const dr = step * (0.25 + rand() * 0.5), dl = step * (0.25 + rand() * 0.5);
      d += `L${r1(x + sr)} ${r1(y + dr)}L${r1(x + sr * 0.3)} ${r1(y + step * 0.1)}`;
      left.push(x - sl, y + dl, x - sl * 0.3, y + step * 0.1);
    }
    const trunk = Math.max(0.7, h * 0.018);
    d += `L${r1(x + trunk)} ${r1(base + 2)}L${r1(x - trunk)} ${r1(base + 2)}`;
    for (let i = left.length - 4; i >= 0; i -= 4) {
      d += `L${r1(left[i + 2])} ${r1(left[i + 3])}L${r1(left[i])} ${r1(left[i + 1])}`;
    }
    return d + "Z";
  }

  // Waldkante entlang eines Kamms: dichte Bestände mit Lichtungen dazwischen.
  // Eng stehende Bäume verschmelzen zu einer gezackten Kante statt zu Einzelstrichen.
  function treeline(rand, ys, density) {
    let d = "";
    const unit = H * (W > 760 ? 0.028 : 0.022);
    let x = -6;
    let patch = rand(), canopy = 0.7 + rand() * 0.5;
    while (x < W + 6) {
      if (rand() < 0.05) { patch = rand(); canopy = 0.7 + rand() * 0.5; }
      if (patch < density) {
        const h = unit * canopy * (0.7 + rand() * 0.5) * (rand() < 0.07 ? 1.45 : 1);
        d += spruce(rand, x, ridgeAt(ys, x) + h * 0.12, h);
        x += h * (0.13 + rand() * 0.16);
      } else {
        x += unit * (0.5 + rand());
      }
    }
    return d;
  }

  function setLayer(name, path, top, gradTop) {
    const svg = document.querySelector(`[data-land="${name}"]`);
    if (!svg) return null;
    const t = Math.floor(Math.max(0, top));
    svg.setAttribute("viewBox", `0 ${t} ${W} ${H - t}`);
    svg.style.height = `${H - t}px`;
    svg.querySelector("path").setAttribute("d", path);
    const grad = svg.querySelector("linearGradient");
    if (grad) {
      // Dunst sammelt sich unterhalb des Kamms
      grad.setAttribute("y1", r1(gradTop));
      grad.setAttribute("y2", r1(gradTop + H * 0.14));
    }
    return svg;
  }

  function minOf(ys) {
    let m = Infinity;
    for (let i = 0; i < ys.length; i++) m = Math.min(m, ys[i]);
    return m;
  }

  function buildLand(scene) {
    const rand = rng(1868);

    const far = ridge(rand, scene.far);
    setLayer("far", ridgePath(far), minOf(far) - 2, scene.far.base * H - H * 0.03);

    const mid = ridge(rand, scene.mid);
    setLayer("mid", ridgePath(mid), minOf(mid) - 2, scene.mid.base * H - H * 0.03);

    const near = ridge(rand, scene.near);
    const nearTop = minOf(near) - H * 0.06;
    setLayer("near", ridgePath(near) + treeline(rand, near, scene.near.trees), nearTop, scene.near.base * H - H * 0.04);

    // Vordergrund: Hangschulter mit der Kamera, ein paar hohe Fichten am Rand
    const f = scene.fore;
    const ground = ridge(rand, f);
    let d = ridgePath(ground);
    let top = minOf(ground);
    for (const [u, hh] of f.spruces) {
      const x = u * W, h = hh * H;
      d += spruce(rand, x, ridgeAt(ground, x) + h * 0.04, h);
      top = Math.min(top, ridgeAt(ground, x) - h);
    }
    const camTop = buildCamera(ground, f.cam * W);
    setLayer("fore", d, Math.min(top, camTop) - 4, 0);
  }

  // Stativ mit Kamera auf der Kuppe, das Objektiv zeigt zum Himmelspol
  function buildCamera(ground, cx) {
    const legs = document.querySelector("[data-cam-legs]");
    const body = document.querySelector("[data-cam-body]");
    const led = document.querySelector("[data-cam-led]");
    if (!legs || !body) return H;
    const s = Math.max(0.62, Math.min(1.1, Math.min(W, H) / 820));
    const gy = ridgeAt(ground, cx) + 1;
    const hx = cx, hy = gy - 31 * s;
    legs.setAttribute("d",
      `M${r1(hx)} ${r1(hy)}L${r1(hx - 14 * s)} ${r1(ridgeAt(ground, hx - 14 * s) + 1)}` +
      `M${r1(hx)} ${r1(hy)}L${r1(hx + 13 * s)} ${r1(ridgeAt(ground, hx + 13 * s) + 1)}` +
      `M${r1(hx)} ${r1(hy)}L${r1(hx + 2.5 * s)} ${r1(gy + 1.5)}` +
      `M${r1(hx)} ${r1(hy + 1)}L${r1(hx)} ${r1(hy - 3.5 * s)}`);
    legs.style.strokeWidth = `${r1(1.5 * s)}px`;

    // Neigung Richtung Pol, begrenzt, damit die Silhouette als Kamera lesbar bleibt.
    // Steht der Pol links der Kamera (schmale Bildschirme), wird sie gespiegelt.
    const dir = pole.x < hx ? -1 : 1;
    let ang = Math.atan2(pole.y - (hy - 8 * s), Math.abs(pole.x - hx));
    ang = Math.max(-1.0, Math.min(-0.45, ang));
    const cos = Math.cos(ang), sin = Math.sin(ang);
    const ox = hx, oy = hy - 4 * s;
    // lokale Punkte: x entlang des Objektivs, y nach unten; (0,0) = Stativkopf
    const P = (x, y) => `${r1(ox + dir * (x * cos - y * sin) * s)} ${r1(oy + (x * sin + y * cos) * s)}`;
    body.setAttribute("d",
      // Gehäuse mit Sucherbuckel und Griff
      `M${P(-9, -1)}L${P(-9, -11)}L${P(-6, -12.5)}L${P(-3.5, -12.5)}L${P(-2, -15.5)}L${P(3, -15.5)}` +
      `L${P(4.5, -12.5)}L${P(7, -12.5)}L${P(7, -1)}Z` +
      // Objektiv mit etwas breiterer Gegenlichtblende
      `M${P(7, -3)}L${P(7, -11)}L${P(17, -11.2)}L${P(18, -12.6)}L${P(21.5, -12.6)}L${P(21.5, -1.4)}L${P(18, -1.4)}L${P(17, -2.8)}Z` +
      // Kugelkopf
      `M${P(-2.5, 0)}L${P(-2.5, -1.5)}L${P(2.5, -1.5)}L${P(2.5, 0)}L${P(1.5, 4)}L${P(-1.5, 4)}Z`);
    if (led) {
      // Kontrollleuchte am Rücken: die Belichtung läuft
      const lx = ox + dir * (-7.5 * cos + 4 * sin) * s, ly = oy + (-7.5 * sin - 4 * cos) * s;
      led.setAttribute("cx", r1(lx));
      led.setAttribute("cy", r1(ly));
      led.setAttribute("r", r1(Math.max(0.9, 1.1 * s)));
    }
    return oy - 30 * s;
  }

  const LINE = [0.7, 1.15, 1.7];
  const ALPHA = [0.38, 0.7, 0.95];

  function draw() {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);

    ctx.globalCompositeOperation = "lighter";
    ctx.lineCap = "round";
    const exp = Math.max(sky.exposure, 0.0015);
    const spin = sky.spin;
    const px = pole.x, py = pole.y;

    for (let k = 0; k < buckets.length; k++) {
      const b = buckets[k];
      const stars = b.stars;
      if (!stars.length) continue;
      ctx.strokeStyle = b.color;
      ctx.globalAlpha = ALPHA[b.level];
      ctx.lineWidth = LINE[b.level];
      ctx.beginPath();
      for (let i = 0; i < stars.length; i++) {
        const s = stars[i];
        // Kopf = aktuelle Position, die Spur reicht zurück, wo der Stern vorher stand
        const a0 = s.a - spin;
        ctx.moveTo(px + s.r * Math.cos(a0), py + s.r * Math.sin(a0));
        ctx.arc(px, py, s.r, a0, a0 + exp);
      }
      ctx.stroke();
    }

    // helle Sterne bekommen einen kleinen Glanzpunkt am Kopf
    ctx.globalAlpha = 0.55;
    for (let i = 0; i < heads.length; i++) {
      const h = heads[i];
      const a0 = h.star.a - spin;
      const x = px + h.star.r * Math.cos(a0);
      const y = py + h.star.r * Math.sin(a0);
      const rad = h.big ? 7 : 4;
      ctx.drawImage(sprites[h.color], x - rad, y - rad, rad * 2, rad * 2);
    }

    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
  }

  let raf = 0;
  let last = performance.now();
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");

  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (!reduce.matches) sky.spin += dt * 0.006;
    draw();
    raf = sky.running ? requestAnimationFrame(loop) : 0;
  }

  function start() {
    if (reduce.matches) { draw(); return; }
    if (raf) return;
    sky.running = true;
    last = performance.now();
    raf = requestAnimationFrame(loop);
  }
  function stop() {
    sky.running = false;
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
  }

  // Nur zeichnen, solange der Hero sichtbar ist
  const io = new IntersectionObserver((entries) => {
    entries[0].isIntersecting ? start() : stop();
  });
  io.observe(canvas);

  // Bei Größenänderung neu aufbauen. Auf dem Handy ändert die Adressleiste nur
  // die Höhe ein wenig, das ignorieren wir.
  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      const w = canvas.clientWidth, h = canvas.clientHeight;
      if (w !== lastW || Math.abs(h - lastH) > 120) {
        build();
        draw();
      }
    }, 120);
  });

  build();
  draw();

  window.Sky = {
    state: sky,
    draw,
  };
})();
