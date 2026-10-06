// Startseite: Bühne, Ablauf mit Leiterbahn, Code-Spielwiese, Einblendungen.
import { gsap, ScrollTrigger, reduceMotion } from './smooth';
import { SplitText } from 'gsap/SplitText';
import { initStage } from './stage';
import { OledEyes, type Mood } from './eyes';

gsap.registerPlugin(SplitText);

initStage();
initReveals();
initProcess();
initCodePlay();
initNewsletter();

// -----------------------------------------------------------------------------
// Überschriften und Karten blenden beim Scrollen ein

function initReveals() {
  if (reduceMotion) return;

  document.querySelectorAll<HTMLElement>('[data-reveal-title]').forEach((el) => {
    SplitText.create(el, {
      type: 'lines',
      mask: 'lines',
      linesClass: 'line',
      autoSplit: true,
      onSplit: (self) =>
        gsap.from(self.lines, {
          yPercent: 105,
          duration: 1.1,
          ease: 'expo.out',
          stagger: 0.08,
          scrollTrigger: { trigger: el, start: 'top 88%', once: true },
        }),
    });
  });

  const cards = gsap.utils.toArray<HTMLElement>('[data-kit]');
  if (cards.length) {
    gsap.from(cards, {
      y: 56,
      opacity: 0,
      duration: 1,
      ease: 'power3.out',
      stagger: 0.09,
      scrollTrigger: { trigger: '[data-kit-grid]', start: 'top 82%', once: true },
    });
  }

  gsap.utils.toArray<HTMLElement>('[data-parallax]').forEach((el) => {
    gsap.fromTo(
      el,
      { yPercent: -5 },
      {
        yPercent: 5,
        ease: 'none',
        scrollTrigger: { trigger: el.parentElement, start: 'top bottom', end: 'bottom top', scrub: true },
      },
    );
  });

  // Riesiger Schriftzug im Footer steigt Buchstabe für Buchstabe auf
  const word = document.querySelector<HTMLElement>('[data-wordmark]');
  if (word) {
    const split = SplitText.create(word, { type: 'chars', mask: 'chars' });
    gsap.from(split.chars, {
      yPercent: 100,
      duration: 1.2,
      ease: 'expo.out',
      stagger: 0.045,
      scrollTrigger: { trigger: word, start: 'top 98%', once: true },
    });
  }
}

// -----------------------------------------------------------------------------
// Ablauf: Leiterbahn zeichnet sich bis zum aktuellen Schritt

function initProcess() {
  const list = document.querySelector<HTMLElement>('[data-steps]');
  if (!list) return;
  const steps = [...list.querySelectorAll<HTMLElement>('[data-step]')];
  const base = list.querySelector<SVGPathElement>('[data-trace-base]')!;
  const live = list.querySelector<SVGPathElement>('[data-trace-live]')!;
  const tip = list.querySelector<SVGCircleElement>('[data-trace-tip]')!;
  let length = 1;
  let viaAt: number[] = [];

  const build = () => {
    const box = list.getBoundingClientRect();
    const vias = steps.map((s) => {
      const r = s.querySelector('[data-via]')!.getBoundingClientRect();
      return { x: r.left - box.left + r.width / 2, y: r.top - box.top + r.height / 2 };
    });
    const x = vias[0].x;
    const jog = 14;
    let d = `M ${x} ${vias[0].y - 40}`;
    for (let i = 0; i < vias.length; i++) {
      const v = vias[i];
      d += ` L ${x} ${v.y}`;
      const next = vias[i + 1];
      if (next) {
        // Kleiner Versatz im 45°-Winkel, wie eine geroutete Leiterbahn
        const mid = (v.y + next.y) / 2;
        d += ` L ${x} ${mid - jog * 2} L ${x + jog} ${mid - jog} L ${x + jog} ${mid + jog} L ${x} ${mid + jog * 2}`;
      }
    }
    const last = vias[vias.length - 1];
    d += ` L ${x} ${last.y + 60}`;
    base.setAttribute('d', d);
    live.setAttribute('d', d);
    length = live.getTotalLength();
    live.style.strokeDasharray = `${length}`;
    // Weglänge bis zu jedem Via ermitteln
    viaAt = vias.map((v) => {
      let lo = 0;
      let hi = length;
      for (let n = 0; n < 24; n++) {
        const mid = (lo + hi) / 2;
        if (live.getPointAtLength(mid).y < v.y) lo = mid;
        else hi = mid;
      }
      return lo;
    });
  };

  const update = (progress: number) => {
    const drawn = length * progress;
    live.style.strokeDashoffset = `${length - drawn}`;
    const pt = live.getPointAtLength(Math.max(0.01, drawn));
    tip.setAttribute('cx', String(pt.x));
    tip.setAttribute('cy', String(pt.y));
    tip.style.opacity = progress > 0.002 && progress < 0.998 ? '1' : '0';
    steps.forEach((s, i) => s.classList.toggle('is-on', drawn >= viaAt[i] - 2));
  };

  build();
  if (reduceMotion) {
    update(1);
    return;
  }
  const st = ScrollTrigger.create({
    trigger: list,
    start: 'top 70%',
    end: 'bottom 75%',
    scrub: 0.4,
    onUpdate: (self) => update(self.progress),
    onRefresh: (self) => {
      build();
      update(self.progress);
    },
  });
  update(st.progress);

  // Terminal tippt los, sobald es zu sehen ist
  const term = document.querySelector<HTMLElement>('[data-terminal]');
  if (term) {
    const lines = [...term.querySelectorAll<HTMLElement>('.term-line')];
    const progressLine = term.querySelector<HTMLElement>('[data-term-progress]')!;
    lines.forEach((l) => l.classList.add('is-pending'));
    const cursor = document.createElement('span');
    cursor.className = 'term-cursor';
    ScrollTrigger.create({
      trigger: term,
      start: 'top 78%',
      once: true,
      onEnter: () => {
        const tl = gsap.timeline();
        lines.forEach((line, i) => {
          tl.call(() => {
            line.classList.remove('is-pending');
            line.append(cursor);
          }, [], i === 0 ? 0 : '+=0.28');
          if (line === progressLine) {
            const counter = { v: 0 };
            tl.to(counter, {
              v: 100,
              duration: 1.4,
              ease: 'power1.inOut',
              onUpdate: () => {
                const pct = Math.round(counter.v);
                const addr = (0x10000 + Math.round((0xf4000 - 0x10000) * (pct / 100))).toString(16).padStart(8, '0');
                progressLine.textContent = `Writing at 0x${addr}... (${String(pct).padStart(3, ' ')} %)`;
                progressLine.append(cursor);
              },
            });
          }
        });
      },
    });
  }
}

// -----------------------------------------------------------------------------
// Code-Spielwiese: Laune wählen, Code tippt sich um, Upload, OLED reagiert

function initCodePlay() {
  const root = document.querySelector<HTMLElement>('[data-codeplay]');
  if (!root) return;
  const canvas = root.querySelector<HTMLCanvasElement>('[data-oled]')!;
  const token = root.querySelector<HTMLElement>('[data-token]')!;
  const pad = root.querySelector<HTMLElement>('[data-pad]')!;
  const bar = root.querySelector<HTMLElement>('[data-upload-bar]')!;
  const barText = root.querySelector<HTMLElement>('[data-upload-text]')!;
  const buttons = [...root.querySelectorAll<HTMLButtonElement>('[data-mood]')];

  const eyes = new OledEyes(canvas, { cell: 6, gap: 1 });
  eyes.setMood('happy');

  // Canvas so groß machen, dass jedes OLED-Pixel genau auf ganze Bildschirmpixel fällt
  const glass = canvas.parentElement!;
  const fit = () => {
    const dpr = window.devicePixelRatio || 1;
    const style = getComputedStyle(glass);
    const avail = glass.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
    const cell = Math.max(2, Math.floor((avail * dpr) / 128));
    eyes.setCell(cell);
    canvas.style.width = `${(128 * cell) / dpr}px`;
    canvas.style.height = `${(64 * cell) / dpr}px`;
    eyes.update(0.016);
  };
  new ResizeObserver(fit).observe(glass);
  fit();
  let visible = false;
  new IntersectionObserver(([e]) => (visible = e.isIntersecting)).observe(canvas);
  gsap.ticker.add((_t, dt) => {
    if (visible) eyes.update(dt / 1000);
  });
  eyes.update(0.016);

  root.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    const r = canvas.getBoundingClientRect();
    eyes.lookAt((e.clientX - (r.left + r.width / 2)) / (r.width * 0.9), (e.clientY - (r.top + r.height / 2)) / (r.height * 1.6));
  });

  let busy: gsap.core.Timeline | null = null;
  const select = (btn: HTMLButtonElement) => {
    if (btn.getAttribute('aria-checked') === 'true') return;
    buttons.forEach((b) => {
      const on = b === btn;
      b.setAttribute('aria-checked', String(on));
      b.tabIndex = on ? 0 : -1;
    });
    const mood = btn.dataset.mood as Mood;
    const next = btn.dataset.tokenName!;
    busy?.kill();
    const tl = gsap.timeline();
    busy = tl;
    const typeSpeed = reduceMotion ? 0 : 0.045;
    token.classList.add('is-typing');
    const current = token.textContent ?? '';
    for (let i = current.length - 1; i >= 0; i--) {
      tl.call(() => (token.textContent = current.slice(0, i)), [], `+=${typeSpeed}`);
    }
    for (let i = 1; i <= next.length; i++) {
      tl.call(() => (token.textContent = next.slice(0, i)), [], `+=${typeSpeed * 1.4}`);
    }
    tl.call(() => {
      token.classList.remove('is-typing');
      pad.textContent = ' '.repeat(Math.max(1, 5 + (5 - next.length)));
      barText.textContent = 'Hochladen …';
    });
    tl.fromTo(bar, { scaleX: 0 }, { scaleX: 1, duration: reduceMotion ? 0 : 0.7, ease: 'power2.inOut' });
    tl.call(() => {
      eyes.setMood(mood);
      eyes.triggerBlink();
      barText.textContent = `Läuft · Laune ${next}`;
    });
  };

  buttons.forEach((b, i) => {
    b.tabIndex = b.getAttribute('aria-checked') === 'true' ? 0 : -1;
    b.addEventListener('click', () => select(b));
    b.addEventListener('keydown', (e) => {
      const dir = e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : e.key === 'ArrowLeft' || e.key === 'ArrowUp' ? -1 : 0;
      if (!dir) return;
      e.preventDefault();
      const next = buttons[(i + dir + buttons.length) % buttons.length];
      next.focus();
      select(next);
    });
  });
}

// -----------------------------------------------------------------------------
// Newsletter: noch ohne Anbindung (siehe README)

function initNewsletter() {
  const form = document.querySelector<HTMLFormElement>('[data-newsletter]');
  if (!form) return;
  const input = form.querySelector<HTMLInputElement>('input[type="email"]')!;
  const msg = form.querySelector<HTMLElement>('[data-nl-msg]')!;
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    msg.hidden = false;
    if (!input.checkValidity() || !input.value) {
      msg.textContent = 'Bitte gib eine gültige E-Mail-Adresse ein, zum Beispiel name@beispiel.de.';
      input.focus();
      return;
    }
    // TODO: Newsletter-Dienst anbinden (z. B. Brevo oder Buttondown) und Double-Opt-in nutzen.
    msg.textContent = 'Vorschau: Die Anmeldung ist noch nicht an einen Newsletter-Dienst angeschlossen.';
  });
}
