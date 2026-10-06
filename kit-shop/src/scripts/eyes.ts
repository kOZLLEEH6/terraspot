// OLED-Augen wie auf einem echten 128 × 64 Display.
// Gezeichnet wird in 128 × 64 mit Kantenglättung, dann auf 1 Bit gerundet
// und als Pixelraster ausgegeben. So sieht es aus wie ein SSD1306/SH1106.

export type Mood = 'normal' | 'happy' | 'tired' | 'angry' | 'love' | 'sleep' | 'worried' | 'surprised';

const W = 128;
const H = 64;

type Shape = {
  w: number;
  h: number;
  r: number;
  tired: number;
  angry: number;
  happy: number;
  heart: number;
  closed: number;
};

const MOODS: Record<Mood, Shape> = {
  normal: { w: 40, h: 40, r: 10, tired: 0, angry: 0, happy: 0, heart: 0, closed: 0 },
  happy: { w: 40, h: 40, r: 10, tired: 0, angry: 0, happy: 1, heart: 0, closed: 0 },
  tired: { w: 40, h: 34, r: 9, tired: 1, angry: 0, happy: 0, heart: 0, closed: 0 },
  angry: { w: 40, h: 36, r: 9, tired: 0, angry: 1, happy: 0, heart: 0, closed: 0 },
  love: { w: 40, h: 40, r: 10, tired: 0, angry: 0, happy: 0, heart: 1, closed: 0 },
  sleep: { w: 40, h: 40, r: 10, tired: 0, angry: 0, happy: 0, heart: 0, closed: 1 },
  worried: { w: 30, h: 34, r: 9, tired: 0.55, angry: 0, happy: 0, heart: 0, closed: 0 },
  surprised: { w: 34, h: 46, r: 15, tired: 0, angry: 0, happy: 0, heart: 0, closed: 0 },
};

// 5 × 5 Pixel-"Z" für den Schlafmodus
const GLYPH_Z = ['11111', '00010', '00100', '01000', '11111'];

export type EyesOptions = {
  cell?: number;
  gap?: number;
  color?: string;
  background?: string;
  glow?: boolean;
};

export class OledEyes {
  readonly canvas: HTMLCanvasElement;
  mood: Mood = 'normal';
  onDraw?: () => void;

  private src: HTMLCanvasElement;
  private sctx: CanvasRenderingContext2D;
  private ctx: CanvasRenderingContext2D;
  private cell: number;
  private gap: number;
  private color: string;
  private background: string;
  private glow: boolean;

  private cur: Shape = { ...MOODS.normal };
  private look = { x: 0, y: 0 };
  private lookTarget = { x: 0, y: 0 };
  private lastExternalLook = -1e9;
  private nextIdleLook = 0;
  private blink = 1;
  private blinkPhase: 'open' | 'closing' | 'opening' = 'open';
  private nextBlink = 1.5;
  private doubleBlink = false;
  private time = 0;
  private boot = 0;
  private lastSignature = '';

  constructor(canvas: HTMLCanvasElement, opts: EyesOptions = {}) {
    this.canvas = canvas;
    this.cell = opts.cell ?? 4;
    this.gap = opts.gap ?? 1;
    this.color = opts.color ?? '#d4f6ff';
    this.background = opts.background ?? '#000000';
    this.glow = opts.glow ?? true;

    canvas.width = W * this.cell;
    canvas.height = H * this.cell;
    this.ctx = canvas.getContext('2d')!;

    this.src = document.createElement('canvas');
    this.src.width = W;
    this.src.height = H;
    this.sctx = this.src.getContext('2d', { willReadFrequently: true })!;
  }

  setMood(mood: Mood) {
    this.mood = mood;
  }

  /** Größe eines OLED-Pixels in Canvas-Pixeln ändern (für scharfe Darstellung) */
  setCell(cell: number, gap = cell >= 4 ? 1 : 0) {
    if (cell === this.cell && gap === this.gap) return;
    this.cell = cell;
    this.gap = gap;
    this.canvas.width = W * cell;
    this.canvas.height = H * cell;
    this.lastSignature = '';
  }

  /** Blickrichtung von außen, x und y jeweils -1 bis 1 */
  lookAt(x: number, y: number) {
    this.lookTarget.x = clamp(x, -1, 1);
    this.lookTarget.y = clamp(y, -1, 1);
    this.lastExternalLook = this.time;
  }

  triggerBlink() {
    if (this.blinkPhase === 'open') this.blinkPhase = 'closing';
  }

  /** Startet die Einschalt-Animation (Zeilen bauen sich von oben auf) */
  powerOn() {
    this.boot = 0.0001;
    this.blink = 0;
    this.blinkPhase = 'opening';
  }

  /** dt in Sekunden. Gibt true zurück, wenn neu gezeichnet wurde. */
  update(dt: number): boolean {
    dt = Math.min(dt, 0.05);
    this.time += dt;

    if (this.boot > 0 && this.boot < 1) this.boot = Math.min(1, this.boot + dt * 2.2);

    // Form weich zur Ziel-Stimmung ziehen
    const target = MOODS[this.mood];
    const k = 1 - Math.exp(-dt * 12);
    for (const key of Object.keys(target) as (keyof Shape)[]) {
      this.cur[key] += (target[key] - this.cur[key]) * k;
    }

    // Blickrichtung: ohne Eingabe von außen schaut er sich selbst um
    const idle = this.time - this.lastExternalLook > 2.2;
    if (idle && this.time > this.nextIdleLook) {
      const restless = this.mood === 'worried' ? 2.4 : 1;
      if (Math.random() < 0.35) {
        this.lookTarget.x = 0;
        this.lookTarget.y = 0;
      } else {
        this.lookTarget.x = rand(-0.9, 0.9);
        this.lookTarget.y = rand(-0.6, 0.6);
      }
      this.nextIdleLook = this.time + rand(1.1, 3.4) / restless;
    }
    const lk = 1 - Math.exp(-dt * 9);
    this.look.x += (this.lookTarget.x - this.look.x) * lk;
    this.look.y += (this.lookTarget.y - this.look.y) * lk;

    // Blinzeln
    this.nextBlink -= dt;
    if (this.blinkPhase === 'open' && this.nextBlink <= 0 && this.cur.closed < 0.5) {
      this.blinkPhase = 'closing';
    }
    if (this.blinkPhase === 'closing') {
      this.blink -= dt * 14;
      if (this.blink <= 0) {
        this.blink = 0;
        this.blinkPhase = 'opening';
      }
    } else if (this.blinkPhase === 'opening') {
      this.blink += dt * 9;
      if (this.blink >= 1) {
        this.blink = 1;
        this.blinkPhase = 'open';
        if (this.doubleBlink) {
          this.doubleBlink = false;
          this.nextBlink = 0.12;
        } else {
          this.doubleBlink = Math.random() < 0.18;
          this.nextBlink = rand(2.2, 5.8);
        }
      }
    }

    const animated = this.cur.heart > 0.02 || this.cur.closed > 0.5;
    const signature = [
      this.look.x.toFixed(3),
      this.look.y.toFixed(3),
      this.blink.toFixed(3),
      this.boot.toFixed(3),
      ...Object.values(this.cur).map((v) => v.toFixed(3)),
    ].join('|');
    if (!animated && signature === this.lastSignature) return false;
    this.lastSignature = signature;
    this.draw();
    return true;
  }

  private draw() {
    const s = this.sctx;
    const c = this.cur;
    s.fillStyle = '#000';
    s.fillRect(0, 0, W, H);
    s.fillStyle = '#fff';

    const space = 12;
    const dx = this.look.x * 14;
    const dy = this.look.y * 8;
    const open = Math.max(0.06, this.blink) * (1 - c.closed * 0.94);

    for (const side of [-1, 1] as const) {
      // Das Auge auf der Blickseite wird minimal größer, wirkt räumlicher
      const persp = 1 + side * this.look.x * 0.08;
      const w = c.w * persp;
      const h = c.h * persp * open;
      const cx = W / 2 + side * (space / 2 + c.w / 2) + dx;
      const cy = H / 2 + dy + c.closed * 8;
      const x = cx - w / 2;
      const y = cy - h / 2;

      if (c.heart > 0.5) {
        this.drawHeart(cx, H / 2 + dy * 0.6, 1 + Math.sin(this.time * 7) * 0.07);
        continue;
      }

      s.fillStyle = '#fff';
      roundRect(s, x, y, w, Math.max(h, 1.5), Math.min(c.r, h / 2, w / 2));

      s.fillStyle = '#000';
      const hh = c.h * persp;
      // Müde: Lid hängt nach außen
      if (c.tired > 0.01) {
        const drop = (hh / 2) * c.tired;
        s.beginPath();
        if (side < 0) {
          s.moveTo(x - 1, y - 1);
          s.lineTo(x + w + 1, y - 1);
          s.lineTo(x - 1, y + drop);
        } else {
          s.moveTo(x - 1, y - 1);
          s.lineTo(x + w + 1, y - 1);
          s.lineTo(x + w + 1, y + drop);
        }
        s.closePath();
        s.fill();
      }
      // Sauer: Lid hängt nach innen
      if (c.angry > 0.01) {
        const drop = (hh / 2) * c.angry;
        s.beginPath();
        if (side < 0) {
          s.moveTo(x - 1, y - 1);
          s.lineTo(x + w + 1, y - 1);
          s.lineTo(x + w + 1, y + drop);
        } else {
          s.moveTo(x - 1, y - 1);
          s.lineTo(x + w + 1, y - 1);
          s.lineTo(x - 1, y + drop);
        }
        s.closePath();
        s.fill();
      }
      // Froh: unteres Lid schiebt sich rund nach oben
      if (c.happy > 0.01) {
        const off = (hh / 2) * c.happy;
        roundRect(s, x - 2, y + h - off + 1, w + 4, hh, c.r + 2);
      }
    }

    if (c.closed > 0.6) this.drawSleepZ();

    // Auf 1 Bit runden und als Pixelraster ausgeben
    const data = s.getImageData(0, 0, W, H).data;
    const ctx = this.ctx;
    const cell = this.cell;
    const size = cell - this.gap;
    ctx.save();
    ctx.fillStyle = this.background;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    const rows = this.boot > 0 && this.boot < 1 ? Math.floor(this.boot * H) : H;
    const full = new Path2D();
    const inner = new Path2D();
    for (let py = 0; py < rows; py++) {
      for (let px = 0; px < W; px++) {
        if (data[(py * W + px) * 4] > 120) {
          full.rect(px * cell, py * cell, cell, cell);
          inner.rect(px * cell, py * cell, size, size);
        }
      }
    }
    // Erst ein weicher Schein, dann die Pixel mit feinem Raster
    if (this.glow) {
      ctx.shadowColor = this.color;
      ctx.shadowBlur = cell * 2.4;
    }
    ctx.globalAlpha = 0.45;
    ctx.fillStyle = this.color;
    ctx.fill(full);
    ctx.shadowBlur = 0;
    ctx.globalAlpha = 1;
    ctx.fill(inner);
    ctx.restore();
    this.onDraw?.();
  }

  private drawHeart(cx: number, cy: number, scale: number) {
    const s = this.sctx;
    const r = 8 * scale;
    s.fillStyle = '#fff';
    s.beginPath();
    s.arc(cx - r * 0.95, cy - r * 0.45, r, Math.PI, 0);
    s.arc(cx + r * 0.95, cy - r * 0.45, r, Math.PI, 0);
    s.lineTo(cx, cy + r * 1.9);
    s.closePath();
    s.fill();
  }

  private drawSleepZ() {
    const s = this.sctx;
    s.fillStyle = '#fff';
    const t = this.time;
    for (let i = 0; i < 3; i++) {
      const phase = (t * 0.45 + i / 3) % 1;
      const size = i === 0 ? 2 : 1;
      const x = 98 + phase * 18 + i * 2;
      const y = 26 - phase * 22;
      if (phase > 0.9) continue;
      GLYPH_Z.forEach((row, ry) => {
        [...row].forEach((bit, rx) => {
          if (bit === '1') s.fillRect(Math.round(x + rx * size), Math.round(y + ry * size), size, size);
        });
      });
    }
  }
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  r = Math.max(0, Math.min(r, w / 2, h / 2));
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
  ctx.fill();
}

const rand = (a: number, b: number) => a + Math.random() * (b - a);
const clamp = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v));
