// Steuerung der Kumpel-Bühne: Kamerafahrt beim Scrollen, Zerlegen,
// Positionsnummern, Stückliste und die Laune des Kumpels.
import { gsap, ScrollTrigger, reduceMotion, scrollToY } from './smooth';
import { Kumpel3D, PART_ORDER, webglAvailable, type PartId, type View } from './kumpel3d';
import type { Mood } from './eyes';
import { SplitText } from 'gsap/SplitText';

gsap.registerPlugin(SplitText);

type Preset = Omit<View, 'hop'>;

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
const range = (p: number, a: number, b: number) => clamp01((p - a) / (b - a));
const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const mix = (a: number, b: number, t: number) => a + (b - a) * t;
const mixPreset = (a: Preset, b: Preset, t: number): Preset => ({
  fx: mix(a.fx, b.fx, t),
  fy: mix(a.fy, b.fy, t),
  ppm: mix(a.ppm, b.ppm, t),
  rx: mix(a.rx, b.rx, t),
  ry: mix(a.ry, b.ry, t),
  explode: mix(a.explode, b.explode, t),
});

function introText(heroCopy: HTMLElement) {
  const title = heroCopy.querySelector<HTMLElement>('[data-split]');
  if (title) {
    SplitText.create(title, {
      type: 'lines',
      mask: 'lines',
      linesClass: 'line',
      autoSplit: true,
      onSplit: (self) =>
        gsap.from(self.lines, { yPercent: 105, duration: 1.1, ease: 'expo.out', stagger: 0.09, delay: 0.1 }),
    });
  }
  gsap.from(heroCopy.querySelectorAll('.eyebrow, .lead, .cta-row, .facts'), {
    y: 18,
    opacity: 0,
    duration: 0.9,
    ease: 'power3.out',
    stagger: 0.07,
    delay: 0.35,
    clearProps: 'transform,opacity',
  });
}

const STATUS: Record<string, string> = {
  normal: 'schaut dich an',
  sleep: 'schläft, klick ihn an',
  worried: 'wird gerade zerlegt',
  happy: 'freut sich',
  love: 'freut sich riesig',
  surprised: 'ist wieder wach',
};

export async function initStage() {
  const section = document.querySelector<HTMLElement>('[data-stage-section]');
  if (!section) return;
  const html = document.documentElement;

  if (reduceMotion || !webglAvailable()) {
    html.classList.remove('js-stage', 'js-gl');
    return;
  }
  html.classList.add('js-stage', 'js-gl');
  const heroCopyEl = section.querySelector<HTMLElement>('[data-hero-copy]')!;
  introText(heroCopyEl);

  // Platinen-Texturen brauchen die Schriften. Höchstens kurz darauf warten.
  await Promise.race([
    Promise.all([
      document.fonts.load('800 20px "Archivo Variable"'),
      document.fonts.load('500 20px "Martian Mono Variable"'),
    ]),
    new Promise((r) => setTimeout(r, 1200)),
  ]).catch(() => {});

  const stage = section.querySelector<HTMLElement>('[data-stage]')!;
  const canvas = section.querySelector<HTMLCanvasElement>('[data-gl]')!;
  const heroCopy = heroCopyEl;
  const bom = section.querySelector<HTMLElement>('[data-bom]')!;
  const endCopy = section.querySelector<HTMLElement>('[data-end-copy]')!;
  const statusText = section.querySelector<HTMLElement>('[data-status-text]')!;
  const status = section.querySelector<HTMLElement>('[data-status]')!;
  const dims = section.querySelector<SVGGElement>('[data-dims]')!;
  const dimLabels = section.querySelectorAll<HTMLElement>('[data-dim-label]');
  const balloons = [...section.querySelectorAll<HTMLElement>('[data-balloon]')];
  const leaders = [...section.querySelectorAll<SVGGElement>('[data-leader]')];
  const rows = [...bom.querySelectorAll<HTMLTableRowElement>('tr[data-part]')];

  let k: Kumpel3D;
  try {
    k = new Kumpel3D(canvas);
  } catch (err) {
    console.warn('WebGL nicht verfügbar, zeige Illustration', err);
    html.classList.remove('js-stage', 'js-gl');
    return;
  }

  // ---------------------------------------------------------------------------
  // Layout: Positionen für Hero, Explosion und Abschluss je nach Bildschirm

  let W = 1;
  let H = 1;
  let mobile = false;
  let hero!: Preset;
  let exploded!: Preset;
  let end!: Preset;

  function layout() {
    W = stage.clientWidth;
    H = stage.clientHeight;
    mobile = W <= 860;
    k.resize(W, H);
    const headerH = 68;
    const gutter = Math.min(48, Math.max(16, W * 0.04));
    const wrapLeft = Math.max(gutter, (W - 1320) / 2);

    if (!mobile) {
      const copyRight = wrapLeft + Math.min(600, heroCopy.offsetWidth);
      const free = W - wrapLeft - copyRight;
      const heroPpm = Math.min((free * 0.66) / 56, (H * 0.42) / 44, 9);
      hero = { fx: (copyRight + free / 2 + 10) / W, fy: 0.55, ppm: heroPpm, rx: 0.14, ry: -0.2, explode: 0 };

      const bomW = Math.min(400, W * 0.36);
      const availW = W - wrapLeft * 2 - bomW - 56;
      const availH = H - headerH - 64;
      const exPpm = Math.min(availW / 170, availH / 160);
      exploded = { fx: (wrapLeft + availW / 2 + 12) / W, fy: (headerH + 24 + availH / 2) / H, ppm: exPpm, rx: 0.6, ry: -0.55, explode: 1 };

      end = { fx: 0.5, fy: 0.43, ppm: Math.min(heroPpm * 0.92, (H * 0.36) / 44), rx: 0.16, ry: 0, explode: 0 };
    } else {
      const copyBottom = heroCopy.offsetTop + heroCopy.offsetHeight;
      const space = Math.max(160, H - copyBottom);
      const heroPpm = Math.min((W * 0.56) / 56, (space - 56) / 52);
      hero = { fx: 0.5, fy: (copyBottom + space / 2 + 8) / H, ppm: heroPpm, rx: 0.16, ry: -0.12, explode: 0 };

      const bomTop = H - bom.offsetHeight - 16;
      const availH = Math.max(160, bomTop - headerH - 24);
      const exPpm = Math.min((W - 24) / 148, availH / 150);
      exploded = { fx: 0.52, fy: (headerH + 12 + availH / 2) / H, ppm: exPpm, rx: 0.6, ry: -0.55, explode: 1 };

      end = { fx: 0.5, fy: 0.6, ppm: Math.min((W * 0.6) / 56, (H * 0.34) / 44), rx: 0.16, ry: 0, explode: 0 };
    }
    k.invalidate();
    needsFrame = true;
  }

  // ---------------------------------------------------------------------------
  // Zustand

  let p = 0;
  let needsFrame = true;
  let active = true;
  let hoverPart: PartId | null = null;
  let pointer = { x: 0, y: 0, has: false };
  const tilt = { x: 0, y: 0 };
  const hop = { v: 0 };
  const intro = { scale: 0.86, t: 0 };
  let lastInput = performance.now();
  let override: { mood: Mood; until: number } | null = null;
  let hoverMood: Mood | null = null;
  let lastMood = '';

  const st = ScrollTrigger.create({
    trigger: section,
    start: 'top top',
    end: 'bottom bottom',
    onUpdate: (self) => {
      p = self.progress;
      needsFrame = true;
    },
    onRefresh: (self) => {
      p = self.progress;
      needsFrame = true;
    },
  });

  new IntersectionObserver(([entry]) => {
    active = entry.isIntersecting;
    if (active) needsFrame = true;
  }).observe(section);

  const ro = new ResizeObserver(() => layout());
  ro.observe(stage);
  layout();

  // ---------------------------------------------------------------------------
  // Eingaben

  const fineHover = window.matchMedia('(hover: hover) and (pointer: fine)').matches;

  window.addEventListener(
    'pointermove',
    (e) => {
      const rect = stage.getBoundingClientRect();
      pointer = { x: e.clientX - rect.left, y: e.clientY - rect.top, has: e.pointerType === 'mouse' };
      wake();
      needsFrame = true;
      if (bomVisible() && e.pointerType === 'mouse') {
        const over = (e.target as HTMLElement).closest('[data-bom], [data-balloon]');
        if (!over) setHover(k.pick(pointer.x, pointer.y));
      }
    },
    { passive: true },
  );
  window.addEventListener('scroll', wake, { passive: true });
  window.addEventListener('keydown', wake);

  function wake() {
    const now = performance.now();
    if (k.eyes.mood === 'sleep') override = { mood: 'surprised', until: now + 900 };
    lastInput = now;
  }

  // Den Kumpel anklicken: freut sich und hüpft
  stage.addEventListener('click', (e) => {
    if ((e.target as HTMLElement).closest('a, button, table')) return;
    if (p > 0.08 && p < 0.86) return;
    const rect = stage.getBoundingClientRect();
    const r = k.bodyRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    if (x < r.x || x > r.x + r.w || y < r.y - 30 || y > r.y + r.h) return;
    override = { mood: 'happy', until: performance.now() + 1800 };
    gsap.timeline()
      .to(hop, { v: 7, duration: 0.18, ease: 'power2.out' })
      .to(hop, { v: 0, duration: 0.5, ease: 'bounce.out' });
  });

  section.querySelectorAll<HTMLElement>('[data-mood-hover]').forEach((el) => {
    el.addEventListener('mouseenter', () => (hoverMood = el.dataset.moodHover as Mood));
    el.addEventListener('mouseleave', () => (hoverMood = null));
  });

  window.addEventListener('cart:add', () => {
    override = { mood: 'love', until: performance.now() + 2400 };
  });

  rows.forEach((row) => {
    row.addEventListener('mouseenter', () => setHover(row.dataset.part as PartId));
    row.addEventListener('mouseleave', () => setHover(null));
  });
  balloons.forEach((b) => {
    b.addEventListener('mouseenter', () => setHover(b.dataset.part as PartId));
    b.addEventListener('mouseleave', () => setHover(null));
  });

  function setHover(part: PartId | null) {
    if (part === hoverPart) return;
    hoverPart = part;
    needsFrame = true;
  }

  // "Was drin ist": zur Stückliste fahren
  section.querySelectorAll<HTMLElement>('[data-scroll-to="explode"]').forEach((a) =>
    a.addEventListener('click', (e) => {
      e.preventDefault();
      const top = section.getBoundingClientRect().top + window.scrollY;
      scrollToY(top + 0.4 * (section.offsetHeight - window.innerHeight), 2.2);
    }),
  );

  const bomVisible = () => p > 0.24 && p < 0.7;

  // ---------------------------------------------------------------------------
  // Intro: Kumpel springt rein, Display geht an

  gsap.to(intro, {
    scale: 1,
    duration: 1.4,
    ease: 'elastic.out(1, 0.75)',
    delay: 0.25,
    onStart: () => {
      canvas.classList.add('is-ready');
      k.eyes.powerOn();
    },
    onUpdate: () => {
      needsFrame = true;
    },
  });

  // ---------------------------------------------------------------------------
  // Pro Frame

  gsap.ticker.add((_time, deltaMs) => {
    if (!active) return;
    const dt = deltaMs / 1000;
    const now = performance.now();

    // Kamera aus dem Scroll-Fortschritt
    const toExplode = ease(range(p, 0.04, 0.22));
    const toEnd = ease(range(p, 0.64, 0.84));
    const cam = mixPreset(mixPreset(hero, exploded, toExplode), end, toEnd);
    cam.explode = ease(range(p, 0.1, 0.3)) * (1 - ease(range(p, 0.62, 0.8)));
    cam.ry += 0.14 * range(p, 0.3, 0.64) * (1 - toEnd);
    cam.ppm *= intro.scale;

    // Neigung zum Mauszeiger (nur vorne und am Ende)
    const tiltWeight = (1 - toExplode) + toEnd;
    const r = k.bodyRect();
    let tx = 0;
    let ty = 0;
    if (pointer.has && fineHover) {
      const dx = (pointer.x - r.cx) / (W * 0.5);
      const dy = (pointer.y - r.cy) / (H * 0.5);
      tx = Math.max(-1, Math.min(1, dx));
      ty = Math.max(-1, Math.min(1, dy));
    }
    const kk = 1 - Math.exp(-dt * 5);
    tilt.y += (tx * 0.32 * tiltWeight - tilt.y) * kk;
    tilt.x += (ty * 0.16 * tiltWeight - tilt.x) * kk;
    k.tilt.x = tilt.x;
    k.tilt.y = tilt.y;

    const changed =
      needsFrame ||
      Math.abs(k.view.fx - cam.fx) > 1e-5 ||
      Math.abs(k.tilt.y - tilt.y) > 1e-5 ||
      hop.v !== k.view.hop;
    Object.assign(k.view, cam, { hop: hop.v });
    if (changed) k.invalidate();

    // Augen
    if (pointer.has && fineHover && tiltWeight > 0.5) {
      k.eyes.lookAt(((pointer.x - r.cx) / (W * 0.32)) * 1.1, ((pointer.y - r.cy) / (H * 0.32)) * 1.1);
    }

    // Laune
    if (override && now > override.until) override = null;
    let base: Mood = 'normal';
    if (p >= 0.1 && p < 0.8) base = 'worried';
    else if (p >= 0.8) base = 'happy';
    else if (now - lastInput > 25000) base = 'sleep';
    const mood: Mood = override?.mood ?? hoverMood ?? base;
    if (mood !== lastMood) {
      k.eyes.setMood(mood);
      lastMood = mood;
      statusText.textContent = p >= 0.8 && mood === 'happy' && !override ? 'ist wieder ganz' : STATUS[mood] ?? '';
    }

    // Hervorheben: Maus geht vor, sonst läuft die Markierung beim Scrollen durch
    let hl: PartId | null = hoverPart;
    if (!hl && p > 0.33 && p < 0.61) {
      hl = PART_ORDER[Math.min(PART_ORDER.length - 1, Math.floor(((p - 0.33) / 0.28) * PART_ORDER.length))];
    }
    if (!bomVisible()) hl = null;
    k.highlight = hl;

    k.tick(dt);
    needsFrame = false;

    // DOM-Overlay
    const heroOut = ease(range(p, 0.01, 0.09));
    setLayer(heroCopy, 1 - heroOut, -40 * heroOut);
    const bomIn = ease(range(p, 0.2, 0.3)) * (1 - ease(range(p, 0.64, 0.72)));
    setLayer(bom, bomIn, mobile ? 24 * (1 - bomIn) : 0, mobile ? 0 : 40 * (1 - bomIn));
    const endIn = ease(range(p, 0.84, 0.92));
    setLayer(endCopy, endIn, 24 * (1 - endIn));
    status.style.opacity = String(1 - Math.min(1, heroOut * 2) + endIn);

    rows.forEach((row) => row.classList.toggle('is-active', row.dataset.part === hl));

    // Positionsnummern mit Führungslinien
    const front = k.project('front');
    const back = k.project('back');
    let nx = -(back.y - front.y);
    let ny = back.x - front.x;
    const len = Math.hypot(nx, ny) || 1;
    nx /= len;
    ny /= len;
    if (ny > 0) {
      nx = -nx;
      ny = -ny;
    }
    // Ballons stehen in einer Reihe parallel zur Explosionsachse, mit Mindestabstand
    const dist = mobile ? 30 : 54;
    const ux = ny * -1;
    const uy = nx;
    const anchors = PART_ORDER.map((id) => k.project(id));
    const spots = anchors.map((a) => ({ x: a.x + nx * dist, y: a.y + ny * dist }));
    const order = spots.map((_, i) => i).sort((i, j) => spots[i].x * ux + spots[i].y * uy - (spots[j].x * ux + spots[j].y * uy));
    const gap = mobile ? 34 : 44;
    for (let n = 1; n < order.length; n++) {
      const prev = spots[order[n - 1]];
      const cur = spots[order[n]];
      const along = (cur.x - prev.x) * ux + (cur.y - prev.y) * uy;
      if (along < gap) {
        cur.x += ux * (gap - along);
        cur.y += uy * (gap - along);
      }
    }
    PART_ORDER.forEach((id, i) => {
      const a = anchors[i];
      const op = ease(range(p, 0.22 + i * 0.012, 0.28 + i * 0.012)) * (1 - ease(range(p, 0.6, 0.66)));
      const bx = spots[i].x;
      const by = spots[i].y;
      const balloon = balloons[i];
      balloon.style.opacity = String(op);
      balloon.style.transform = `translate3d(${bx}px, ${by}px, 0)`;
      balloon.classList.toggle('is-active', hl === id);
      const g = leaders[i];
      g.style.opacity = String(op);
      g.classList.toggle('is-active', hl === id);
      const line = g.querySelector('line')!;
      const circle = g.querySelector('circle')!;
      line.setAttribute('x1', String(a.x));
      line.setAttribute('y1', String(a.y));
      const lx = bx - a.x;
      const ly = by - a.y;
      const ll = Math.hypot(lx, ly) || 1;
      line.setAttribute('x2', String(bx - (lx / ll) * 15));
      line.setAttribute('y2', String(by - (ly / ll) * 15));
      circle.setAttribute('cx', String(a.x));
      circle.setAttribute('cy', String(a.y));
    });

    // Bemaßung im Ruhezustand
    const dimOp = mobile ? 0 : (1 - ease(range(p, 0, 0.04))) * clamp01((intro.scale - 0.97) / 0.03);
    dims.style.opacity = String(dimOp * 0.9);
    if (dimOp > 0.01) drawDims(dimOp);
    else dimLabels.forEach((l) => (l.style.opacity = '0'));
  });

  function setLayer(el: HTMLElement, opacity: number, y = 0, x = 0) {
    el.style.opacity = String(opacity);
    el.style.visibility = opacity < 0.02 ? 'hidden' : 'visible';
    const base = el === heroCopy && !mobile ? 'translateY(-50%) ' : el === bom && !mobile ? 'translateY(-50%) ' : '';
    el.style.transform = `${base}translate3d(${x}px, ${y}px, 0)`;
  }

  const dimLines = Object.fromEntries(
    [...dims.querySelectorAll<SVGLineElement>('[data-dim]')].map((l) => [l.dataset.dim!, l]),
  );
  function drawDims(op: number) {
    // Breite: Unterkante vorne, Höhe: rechte Kante hinten (die sieht man bei der Drehung)
    const bl = k.projectLocal(-28, -22, 18);
    const br = k.projectLocal(28, -22, 18);
    const rt = k.projectLocal(28, 22, -18);
    const rb = k.projectLocal(28, -22, -18);
    const off = 40;
    const y = Math.max(bl.y, br.y) + off;
    const x = Math.max(rt.x, rb.x) + 30;
    setLine(dimLines['w'], bl.x, y, br.x, y);
    setLine(dimLines['w-a'], bl.x, bl.y + 12, bl.x, y + 6);
    setLine(dimLines['w-b'], br.x, br.y + 12, br.x, y + 6);
    setLine(dimLines['h'], x, rt.y, x, rb.y);
    setLine(dimLines['h-a'], rt.x + 10, rt.y, x + 6, rt.y);
    setLine(dimLines['h-b'], rb.x + 10, rb.y, x + 6, rb.y);
    const [wl, hl] = dimLabels;
    wl.style.opacity = String(op);
    wl.style.transform = `translate3d(${(bl.x + br.x) / 2}px, ${y}px, 0) translate(-50%, -50%)`;
    hl.style.opacity = String(op);
    hl.style.transform = `translate3d(${x}px, ${(rt.y + rb.y) / 2}px, 0) translate(-50%, -50%)`;
  }
  function setLine(l: SVGLineElement, x1: number, y1: number, x2: number, y2: number) {
    l.setAttribute('x1', x1.toFixed(1));
    l.setAttribute('y1', y1.toFixed(1));
    l.setAttribute('x2', x2.toFixed(1));
    l.setAttribute('y2', y2.toFixed(1));
  }

  // Nach dem Laden einmal sauber messen (Schriften, Bilder)
  document.fonts?.ready.then(() => {
    layout();
    ScrollTrigger.refresh();
  });
  void st;
}
