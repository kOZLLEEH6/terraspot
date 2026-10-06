/*
 * Hero-Himmel mit Parallax-Tiefe: Sterne rücken näher beim Scrollen.
 * Unterschiedliche Tiefenschichten bewegen sich mit verschiedenen Geschwindigkeiten.
 * app.js steuert depth (0-1) über die Scrollposition.
 */
(function () {
  const canvas = document.querySelector("[data-sky]");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  const COLORS = ["#ffc79a", "#ffe2c2", "#fff6ec", "#e9efff", "#c9d7ff", "#aec3ff"];
  const sky = {
    depth: 0,         /* scroll-basiert: 0 = Anfang, 1 = Max Tiefe */
    spin: 0,          /* kontinuierliche Rotation für Bewegung */
    running: true,
  };

  let W = 0, H = 0, DPR = 1;
  let pole = { x: 0, y: 0 };
  let depthLayers = [];  /* Stars nach Tiefe organisiert */
  let heads = [];
  let ridge = null;
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

  function build() {
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    W = canvas.clientWidth;
    H = canvas.clientHeight;
    canvas.width = Math.round(W * DPR);
    canvas.height = Math.round(H * DPR);
    lastW = W; lastH = H;

    const wide = W > 760;
    pole = wide ? { x: W * 0.7, y: H * 0.3 } : { x: W * 0.62, y: H * 0.3 };
    const rMax = Math.hypot(Math.max(pole.x, W - pole.x), Math.max(pole.y, H - pole.y));
    const count = Math.round(Math.min(1500, Math.max(380, (W * H) / 850)));
    const rand = rng(20261005);

    /* Sterne in 4 Tiefenschichten organisieren */
    depthLayers = [[], [], [], []];
    heads = [];
    for (let i = 0; i < count; i++) {
      const r = Math.sqrt(rand()) * rMax;
      const a = rand() * Math.PI * 2;
      const depthVal = rand();  /* 0-1 Tiefe pro Stern */
      const m = rand();
      const level = m > 0.97 ? 2 : m > 0.8 ? 1 : 0;
      const tempIdx = Math.min(COLORS.length - 1, Math.floor(Math.pow(rand(), 0.8) * COLORS.length));
      const star = { r, a, depth: depthVal, colorIdx: tempIdx, level };
      const depthLayer = Math.floor(depthVal * 4);
      depthLayers[depthLayer].push(star);
      if (level === 2) heads.push({ star, color: COLORS[tempIdx] });
    }

    /* Polaris: nah, hell */
    const polaris = { r: Math.min(W, H) * 0.012, a: 0.6, depth: 0.05, colorIdx: 2, level: 2 };
    depthLayers[0].push(polaris);
    heads.push({ star: polaris, color: COLORS[2], big: true });

    ridge = makeRidge(rand);
  }

  // Bergkamm-Silhouette am unteren Rand
  function makeRidge(rand) {
    const pts = [];
    const base = H * (W > 760 ? 0.86 : 0.88);
    const phases = [rand() * 6, rand() * 6, rand() * 6, rand() * 6];
    for (let x = 0; x <= W + 8; x += 8) {
      const u = x / W;
      const y =
        base -
        H * 0.05 * Math.sin(u * 2.3 + phases[0]) -
        H * 0.025 * Math.sin(u * 6.1 + phases[1]) -
        H * 0.012 * Math.sin(u * 13.7 + phases[2]) -
        H * 0.006 * Math.sin(u * 31 + phases[3]) -
        H * 0.06 * Math.exp(-Math.pow((u - 0.24) / 0.09, 2));
      pts.push([x, y]);
    }
    return pts;
  }

  const LINE = [0.7, 1.15, 1.7];
  const ALPHA = [0.38, 0.7, 0.95];

  function draw() {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.globalCompositeOperation = "source-over";

    /* Himmelsfarbe: Je tiefer, desto heller/wärmer */
    const skyBright = 0.04 + sky.depth * 0.08;
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, `rgba(4, 6, 12, ${1 - sky.depth * 0.3})`);
    g.addColorStop(0.62, `rgba(8, 16, 32, ${1 - sky.depth * 0.2})`);
    g.addColorStop(0.9, `rgba(15, 26, 46, ${1 - sky.depth * 0.15})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    /* Glow am Horizont: intensiver bei Tiefe */
    const glowOpacity = 0.22 + sky.depth * 0.38;
    const glow = ctx.createRadialGradient(W * 0.18, H * 0.92, 0, W * 0.18, H * 0.92, Math.max(W, H) * 0.55);
    glow.addColorStop(0, `rgba(120, 82, 54, ${glowOpacity})`);
    glow.addColorStop(1, "rgba(120, 82, 54, 0)");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);

    ctx.globalCompositeOperation = "lighter";
    ctx.lineCap = "round";
    const spin = sky.spin;

    /* Sterne pro Tiefenschicht rendern: ferner zuerst, näher zuletzt */
    for (let layerIdx = 0; layerIdx < depthLayers.length; layerIdx++) {
      const layer = depthLayers[layerIdx];
      if (!layer.length) continue;

      /* Tiefe-Interpolation: Wie nah ist dieser Layer basierend auf Scrollprogress? */
      const layerDepth = (layerIdx / 4 + 0.125) * 0.8;  /* 0.1 bis 0.8 */
      const depthMix = Math.max(0, sky.depth - layerDepth) * 1.5;  /* 0 = sichtbar, 1+ = kommt näher */

      /* Skalierung: ferne Sterne sind klein, nahe groß */
      const scale = 1 + depthMix * 2.5;
      /* Opazität: ferne Sterne fadden aus, nahe sind sichtbar */
      const opacityMult = Math.min(1, 0.3 + depthMix * 1.2);

      /* Gruppierung nach Farbe+Level für Rendering-Effizienz */
      const starsByGroup = new Map();
      for (const star of layer) {
        const key = `${star.colorIdx}-${star.level}`;
        if (!starsByGroup.has(key)) starsByGroup.set(key, []);
        starsByGroup.get(key).push(star);
      }

      for (const [key, stars] of starsByGroup) {
        const [colorIdx, level] = key.split('-');
        ctx.strokeStyle = COLORS[parseInt(colorIdx)];
        ctx.globalAlpha = ALPHA[parseInt(level)] * opacityMult;
        ctx.lineWidth = LINE[parseInt(level)] * scale;

        /* Kleine Trails für ferne Sterne, große für nahe */
        const trailExp = 0.008 + sky.depth * 0.06;

        ctx.beginPath();
        for (const s of stars) {
          const a0 = s.a - spin * (1 - s.depth);  /* ferne Sterne drehen langsamer */
          ctx.moveTo(pole.x + s.r * Math.cos(a0), pole.y + s.r * Math.sin(a0));
          ctx.arc(pole.x, pole.y, s.r, a0, a0 + trailExp);
        }
        ctx.stroke();
      }
    }

    /* helle Sterne bekommen einen kleinen Glanzpunkt am Kopf */
    ctx.globalAlpha = 0.55 + sky.depth * 0.3;
    for (const h of heads) {
      const starDepth = h.star.depth;
      const depthMix = Math.max(0, sky.depth - (starDepth * 0.8)) * 1.5;
      const scale = 1 + depthMix * 2.5;
      const a0 = h.star.a - spin * (1 - starDepth);
      const x = pole.x + h.star.r * Math.cos(a0);
      const y = pole.y + h.star.r * Math.sin(a0);
      const rad = (h.big ? 7 : 4) * scale;
      ctx.drawImage(sprites[h.color], x - rad, y - rad, rad * 2, rad * 2);
    }

    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
    if (ridge) {
      ctx.beginPath();
      ctx.moveTo(0, H);
      for (const [x, y] of ridge) ctx.lineTo(x, y);
      ctx.lineTo(W, H);
      ctx.closePath();
      ctx.fillStyle = "#05070d";
      ctx.fill();
    }
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
