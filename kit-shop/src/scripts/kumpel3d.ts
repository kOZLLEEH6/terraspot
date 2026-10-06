// Der Kumpel als echtes 3D-Modell (three.js). Maße in Millimetern.
// Teile sind so aufgebaut wie im echten Bausatz: Gehäuse vorne, OLED,
// ESP32-C3 Super Mini, Kumpel-Platine, Tastenkappen, Akku, Gehäuse hinten.
import {
  BoxGeometry,
  BufferGeometry,
  CanvasTexture,
  CylinderGeometry,
  DirectionalLight,
  ExtrudeGeometry,
  Group,
  LatheGeometry,
  LinearMipmapLinearFilter,
  Material,
  Mesh,
  MeshBasicMaterial,
  MeshPhysicalMaterial,
  MeshStandardMaterial,
  NeutralToneMapping,
  Object3D,
  Path,
  PerspectiveCamera,
  PlaneGeometry,
  PMREMGenerator,
  Raycaster,
  Scene,
  Shape,
  SRGBColorSpace,
  Texture,
  Vector2,
  Vector3,
  WebGLRenderer,
} from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { OledEyes } from './eyes';

export type PartId = 'front' | 'oled' | 'esp' | 'board' | 'caps' | 'battery' | 'back';

export const PART_ORDER: PartId[] = ['front', 'oled', 'esp', 'board', 'caps', 'battery', 'back'];

export type View = {
  fx: number; // Bildschirmposition des Modells, 0 bis 1
  fy: number;
  ppm: number; // Pixel pro Millimeter
  rx: number; // Neigung (Radiant)
  ry: number; // Drehung
  explode: number; // 0 = zusammengebaut, 1 = zerlegt
  hop: number; // kleiner Hüpfer in mm
};

type Part = {
  id: PartId;
  group: Group;
  base: Vector3;
  dir: Vector3;
  anchor: Vector3;
  mats: MeshStandardMaterial[];
  glow: number;
};

// Körpermaße
const W = 56;
const H = 44;
const R = 11;
const WALL = 2;
const FOV = 24;
const PINK = '#ff8db7';

export class Kumpel3D {
  readonly view: View = { fx: 0.5, fy: 0.5, ppm: 6, rx: 0, ry: 0, explode: 0, hop: 0 };
  readonly tilt = { x: 0, y: 0 };
  readonly eyes: OledEyes;
  highlight: PartId | null = null;
  spread = 1;

  private renderer: WebGLRenderer;
  private scene = new Scene();
  private camera = new PerspectiveCamera(FOV, 1, 1, 5000);
  private root = new Group();
  private model = new Group();
  private parts = new Map<PartId, Part>();
  private shadow!: Mesh;
  private eyesTex: CanvasTexture;
  private width = 1;
  private height = 1;
  private dirty = true;
  private raycaster = new Raycaster();

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    this.renderer.outputColorSpace = SRGBColorSpace;
    this.renderer.toneMapping = NeutralToneMapping;
    this.renderer.toneMappingExposure = 0.95;
    this.renderer.setClearColor(0x000000, 0);

    const pmrem = new PMREMGenerator(this.renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    this.scene.environmentIntensity = 0.75;
    pmrem.dispose();

    const key = new DirectionalLight(0xffffff, 1.5);
    key.position.set(-80, 140, 160);
    this.scene.add(key);
    const rim = new DirectionalLight(0xffe4ef, 0.6);
    rim.position.set(120, 40, -120);
    this.scene.add(rim);

    this.scene.add(this.root);
    this.root.add(this.model);

    const eyesCanvas = document.createElement('canvas');
    this.eyes = new OledEyes(eyesCanvas, { cell: 4, gap: 1 });
    this.eyesTex = new CanvasTexture(eyesCanvas);
    this.eyesTex.colorSpace = SRGBColorSpace;
    // Mipmaps glätten das Pixelraster, wenn das Display klein dargestellt wird
    this.eyesTex.generateMipmaps = true;
    this.eyesTex.minFilter = LinearMipmapLinearFilter;
    this.eyesTex.anisotropy = 4;
    this.eyes.onDraw = () => {
      this.eyesTex.needsUpdate = true;
      this.dirty = true;
    };

    this.build();
  }

  // ---------------------------------------------------------------------------
  // Aufbau

  private build() {
    const pla = () => new MeshStandardMaterial({ color: '#f1f1ec', roughness: 0.55, metalness: 0 });
    const plaSide = () => new MeshStandardMaterial({ color: '#ecece6', roughness: 0.66, metalness: 0 });

    // Pos. 1: Gehäuse vorne (Frontplatte mit Sichtfenster + Seitenwand)
    {
      const g = new Group();
      const cap = pla();
      const side = plaSide();
      const b = 1.5;
      const plate = roundedRectShape(W - 2 * b, H - 2 * b, R - b);
      plate.holes.push(roundedRectPath(33 + 2 * b, 19 + 2 * b, 3.2 + b, 0, 3));
      const plateGeo = new ExtrudeGeometry(plate, {
        depth: 0.6,
        bevelEnabled: true,
        bevelThickness: b,
        bevelSize: b,
        bevelSegments: 6,
        curveSegments: 40,
      });
      const plateMesh = new Mesh(plateGeo, [cap, side]);
      plateMesh.position.z = 18 - 0.6 - b;
      g.add(plateMesh);

      const ring = roundedRectShape(W - 0.2, H - 0.2, R - 0.1);
      ring.holes.push(roundedRectPath(W - 2 * WALL, H - 2 * WALL, R - WALL));
      const ringGeo = new ExtrudeGeometry(ring, { depth: 16.15, bevelEnabled: false, curveSegments: 40 });
      const ringMesh = new Mesh(ringGeo, [side, side]);
      ringMesh.position.z = 0.15;
      g.add(ringMesh);

      // Lautsprecher-Löcher für den Summer
      const holeGeo = new CylinderGeometry(0.55, 0.55, 0.3, 20);
      const holeMat = plastic('#4a514d', 0.9);
      for (const x of [-3.2, 0, 3.2]) {
        const hole = new Mesh(holeGeo, holeMat);
        hole.rotation.x = Math.PI / 2;
        hole.position.set(x, -15.6, 17.9);
        g.add(hole);
      }

      this.addPart('front', g, new Vector3(0, 0, 58), new Vector3(-W / 2 + 6, H / 2 - 4, 18));
    }

    // Dichtring als dunkle Fuge zwischen den Gehäusehälften (bleibt am Platz)
    {
      const ring = roundedRectShape(W - 0.5, H - 0.5, R - 0.25);
      ring.holes.push(roundedRectPath(W - 3, H - 3, R - 1.5));
      const geo = new ExtrudeGeometry(ring, { depth: 0.5, bevelEnabled: false, curveSegments: 32 });
      const mesh = new Mesh(geo, new MeshStandardMaterial({ color: '#2a302d', roughness: 0.9 }));
      mesh.position.z = -0.25;
      const g = new Group();
      g.add(mesh);
      this.model.add(g);
      this.gasket = g;
    }

    // Pos. 2: OLED-Modul 1,3"
    {
      const g = new Group();
      const pcbW = 36;
      const pcbH = 34;
      const tex = pcbTexture(pcbW, pcbH, 22, '#1f4fa2', (c) => drawOledPcb(c, pcbW, pcbH));
      const board = pcbMesh(pcbW, pcbH, 1.4, 1.2, tex, '#d9cf9b', [
        [-15.5, -14.5],
        [15.5, -14.5],
        [-15.5, 14.5],
        [15.5, 14.5],
      ]);
      board.position.z = 12.6;
      g.add(board);

      const glass = new Mesh(
        new RoundedBoxGeometry(35, 28, 1.3, 2, 0.35),
        new MeshPhysicalMaterial({ color: '#06080a', roughness: 0.12, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.06 }),
      );
      glass.position.set(0, 1, 12.6 + 0.65);
      g.add(glass);

      const screen = new Mesh(new PlaneGeometry(29.4, 14.7), new MeshBasicMaterial({ map: this.eyesTex, toneMapped: false }));
      screen.position.set(0, 3, 13.93);
      g.add(screen);

      const flex = new Mesh(new BoxGeometry(12, 2.6, 0.2), metal('#c9973e', 0.35));
      flex.position.set(0, -14.6, 12.72);
      g.add(flex);

      // Stiftleiste nach hinten zur Platine
      const spacer = new Mesh(new BoxGeometry(10.2, 2.5, 2.5), plastic('#151515'));
      spacer.position.set(0, 15.2, 11.2 - 1.25);
      g.add(spacer);
      for (let i = 0; i < 4; i++) {
        const pin = new Mesh(new BoxGeometry(0.64, 0.64, 7), metal('#d6af57', 0.3));
        pin.position.set(-3.81 + i * 2.54, 15.2, 11.2 - 2.4);
        g.add(pin);
      }
      this.addPart('oled', g, new Vector3(0, 0, 36), new Vector3(-17, 15.5, 12.6));
    }

    // Pos. 3: ESP32-C3 Super Mini
    {
      const g = new Group();
      const bw = 18;
      const bh = 22.5;
      const tex = pcbTexture(bw, bh, 30, '#141619', (c) => drawEspPcb(c, bw, bh));
      const board = pcbMesh(bw, bh, 1.0, 1.0, tex, '#2a2c2e', []);
      board.position.set(-8, -1, 6.8);
      g.add(board);
      const top = 6.8;

      const chip = new Mesh(new BoxGeometry(5, 5, 0.9), plastic('#2c2f33', 0.55));
      chip.position.set(-8, 0.5, top + 0.45);
      g.add(chip);
      const chipLabel = new Mesh(new PlaneGeometry(4.6, 4.6), new MeshStandardMaterial({ map: chipTexture(), transparent: true, roughness: 0.6 }));
      chipLabel.position.set(-8, 0.5, top + 0.91);
      g.add(chipLabel);

      const antenna = new Mesh(new RoundedBoxGeometry(3.2, 1.6, 1.1, 2, 0.15), plastic('#e9e3d2', 0.5));
      antenna.position.set(-8, 9.4, top + 0.55);
      g.add(antenna);

      const usb = new Mesh(new RoundedBoxGeometry(8.9, 7.3, 3.2, 3, 1.2), metal('#c4c8cd', 0.28));
      usb.position.set(-8, -10.4, top + 1.6);
      g.add(usb);
      const usbHole = new Mesh(new RoundedBoxGeometry(7.2, 0.4, 1.6, 2, 0.5), plastic('#0a0a0a'));
      usbHole.position.set(-8, -14.05, top + 1.6);
      g.add(usbHole);

      // BOOT- und RST-Taster zwischen Chip und USB-Buchse
      for (const x of [-11.2, -4.8]) {
        const btn = new Mesh(new RoundedBoxGeometry(2.6, 3, 1.4, 2, 0.3), metal('#d0d3d6', 0.35));
        btn.position.set(x, -4.4, top + 0.7);
        g.add(btn);
        const act = new Mesh(new CylinderGeometry(0.6, 0.6, 0.6, 16), plastic('#1a1a1a'));
        act.rotation.x = Math.PI / 2;
        act.position.set(x, -4.4, top + 1.6);
        g.add(act);
      }
      const led = new Mesh(new BoxGeometry(1.6, 0.8, 0.5), new MeshStandardMaterial({ color: '#ff4f6d', emissive: '#ff4f6d', emissiveIntensity: 0.6 }));
      led.position.set(-11.6, 3.2, top + 0.25);
      g.add(led);
      smd(g, -11.6, 5.8, top);
      smd(g, -4.4, 5.8, top);
      smd(g, -4.4, 3.2, top);

      // Stiftleisten auf der Rückseite
      for (const x of [-15.6, -0.4]) {
        const strip = new Mesh(new BoxGeometry(2.5, 20.3, 2.5), plastic('#121212'));
        strip.position.set(x, -1, 4.55);
        g.add(strip);
      }
      this.addPart('esp', g, new Vector3(0, 0, 18), new Vector3(-16.5, 9.8, 6.8));
    }

    // Pos. 4: Kumpel-Platine
    {
      const g = new Group();
      const bw = 50;
      const bh = 38;
      const tex = pcbTexture(bw, bh, 24, '#0c5638', (c) => drawKumpelPcb(c, bw, bh));
      const board = pcbMesh(bw, bh, 1.6, 2, tex, '#cfc58c', [
        [-21.5, -15.5],
        [21.5, -15.5],
        [-21.5, 15.5],
        [21.5, 15.5],
      ]);
      board.position.z = 3.3;
      g.add(board);
      const top = 3.3;

      // Rechtwinklige Taster an der Oberkante (unter den Kappen)
      for (const x of [-14, 14]) {
        const body = new Mesh(new BoxGeometry(6, 3.5, 3.6), plastic('#1a1b1d', 0.5));
        body.position.set(x, 17.4, top + 1.8);
        g.add(body);
        const act = new Mesh(new CylinderGeometry(1.1, 1.1, 1.6, 20), plastic('#2a2b2e'));
        act.position.set(x, 19.9, top + 1.8);
        g.add(act);
      }
      // Summer
      const buzzer = new Mesh(new RoundedBoxGeometry(8.5, 8.5, 3, 2, 0.4), plastic('#151617', 0.45));
      buzzer.position.set(12, -1, top + 1.5);
      g.add(buzzer);
      const buzzHole = new Mesh(new CylinderGeometry(1, 1, 0.2, 20), plastic('#000000'));
      buzzHole.rotation.x = Math.PI / 2;
      buzzHole.position.set(12, -1, top + 3.02);
      g.add(buzzHole);
      // Lade-IC
      const ic = new Mesh(new BoxGeometry(5, 4, 1.5), plastic('#222428', 0.6));
      ic.position.set(14, -11, top + 0.75);
      g.add(ic);
      for (let i = 0; i < 4; i++) {
        for (const s of [-1, 1]) {
          const leg = new Mesh(new BoxGeometry(0.9, 0.4, 0.3), metal('#cfd3d6', 0.3));
          leg.position.set(14 + s * 2.9, -11 - 1.9 + i * 1.27, top + 0.15);
          g.add(leg);
        }
      }
      // Akku-Stecker (JST)
      const jst = new Mesh(new BoxGeometry(6, 4.5, 4.2), plastic('#efe6d2', 0.55));
      jst.position.set(21, 9, top + 2.1);
      g.add(jst);
      // OLED-Buchse
      const sock = new Mesh(new BoxGeometry(10.2, 2.5, 4.4), plastic('#141414'));
      sock.position.set(0, 15.2, top + 2.2);
      g.add(sock);
      // Lade-LED (leuchtet pink)
      const led = new Mesh(new BoxGeometry(2, 1.25, 0.7), new MeshStandardMaterial({ color: PINK, emissive: PINK, emissiveIntensity: 1.4 }));
      led.position.set(21.5, -12, top + 0.35);
      g.add(led);
      for (const [x, y, rot] of [
        [5, -12, false],
        [5, -9, false],
        [5, -6, false],
        [21.5, -4, true],
        [21.5, 2, true],
        [6.5, 6.5, false],
        [-21, 6, true],
      ] as [number, number, boolean][]) {
        smd(g, x, y, top, rot);
      }
      this.addPart('board', g, new Vector3(0, 0, 0), new Vector3(-24, 18, 3.3));
    }

    // Pos. 5: Tastenkappen (die Ohren)
    {
      const g = new Group();
      const mat = new MeshStandardMaterial({ color: PINK, roughness: 0.48 });
      const profile = [
        new Vector2(0, 0),
        new Vector2(3.5, 0),
        new Vector2(3.5, 3.6),
        new Vector2(3.42, 4.05),
        new Vector2(3.18, 4.4),
        new Vector2(2.8, 4.65),
        new Vector2(2.2, 4.8),
        new Vector2(0, 4.85),
      ];
      const geo = new LatheGeometry(profile, 40);
      for (const x of [-14, 14]) {
        const cap = new Mesh(geo, mat);
        cap.position.set(x, H / 2 - 0.4, 5.1);
        g.add(cap);
      }
      this.addPart('caps', g, new Vector3(0, 30, 2), new Vector3(-14, H / 2 + 4.8, 5.1));
    }

    // Pos. 6: LiPo-Akku
    {
      const g = new Group();
      const cell = new Mesh(new RoundedBoxGeometry(36, 26, 5, 3, 1.1), metal('#c3c7cb', 0.38, 0.55));
      cell.position.set(0, -1.5, -5);
      g.add(cell);
      const label = new Mesh(new PlaneGeometry(31, 20.5), new MeshStandardMaterial({ map: batteryTexture(), roughness: 0.5, metalness: 0.15 }));
      label.position.set(0, -2.6, -2.48);
      g.add(label);
      const kapton = new Mesh(
        new BoxGeometry(36.4, 3.6, 5.5),
        new MeshPhysicalMaterial({ color: '#e0a128', roughness: 0.25, transmission: 0.2, transparent: true, opacity: 0.92 }),
      );
      kapton.position.set(0, 10.4, -5);
      g.add(kapton);
      for (const [x, c] of [
        [12.4, '#d23a3a'],
        [14.2, '#202020'],
      ] as [number, string][]) {
        const wire = new Mesh(new CylinderGeometry(0.55, 0.55, 5, 12), plastic(c, 0.45));
        wire.position.set(x, 14.6, -5);
        g.add(wire);
      }
      const plug = new Mesh(new BoxGeometry(6, 4.5, 4), plastic('#efe6d2', 0.55));
      plug.position.set(13.3, 18.6, -5);
      g.add(plug);
      this.addPart('battery', g, new Vector3(0, 0, -26), new Vector3(-17.5, 11, -2.5));
    }

    // Pos. 7: Gehäuse hinten (mit Schraubdomen und Gruß innen)
    {
      const g = new Group();
      const cap = pla();
      const side = plaSide();
      const b = 1.5;
      const plate = roundedRectShape(W - 2 * b, H - 2 * b, R - b);
      const plateGeo = new ExtrudeGeometry(plate, {
        depth: 0.6,
        bevelEnabled: true,
        bevelThickness: b,
        bevelSize: b,
        bevelSegments: 6,
        curveSegments: 40,
      });
      const plateMesh = new Mesh(plateGeo, [cap, side]);
      plateMesh.position.z = -18 + b;
      g.add(plateMesh);

      const ring = roundedRectShape(W - 0.2, H - 0.2, R - 0.1);
      ring.holes.push(roundedRectPath(W - 2 * WALL, H - 2 * WALL, R - WALL));
      const ringGeo = new ExtrudeGeometry(ring, { depth: 16.15, bevelEnabled: false, curveSegments: 40 });
      const ringMesh = new Mesh(ringGeo, [side, side]);
      ringMesh.position.z = -16.3;
      g.add(ringMesh);

      const bossGeo = new CylinderGeometry(2.6, 2.8, 10, 28);
      const holeGeo = new CylinderGeometry(1.05, 1.05, 0.2, 20);
      const holeMat = plastic('#3a3f3c', 0.8);
      for (const x of [-21, 21]) {
        for (const y of [-15, 15]) {
          const boss = new Mesh(bossGeo, side);
          boss.rotation.x = Math.PI / 2;
          boss.position.set(x, y, -14.4 + 5);
          g.add(boss);
          const hole = new Mesh(holeGeo, holeMat);
          hole.rotation.x = Math.PI / 2;
          hole.position.set(x, y, -14.4 + 10.02);
          g.add(hole);
        }
      }
      for (const x of [-19.6, 19.6]) {
        const rib = new Mesh(new BoxGeometry(1.2, 22, 6), side);
        rib.position.set(x, -1.5, -14.4 + 3);
        g.add(rib);
      }
      const note = new Mesh(new PlaneGeometry(30, 7.5), new MeshBasicMaterial({ map: noteTexture(), transparent: true }));
      note.position.set(0, -15.2, -14.37);
      g.add(note);
      this.addPart('back', g, new Vector3(0, 0, -52), new Vector3(-W / 2 + 4, H / 2 - 3, -0.5));
    }

    // Weicher Schatten auf dem Tisch
    const shadowTex = new CanvasTexture(radialShadow());
    const shadow = new Mesh(
      new PlaneGeometry(1, 1),
      new MeshBasicMaterial({ map: shadowTex, transparent: true, depthWrite: false, toneMapped: false }),
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = -H / 2 - 0.6;
    shadow.renderOrder = -1;
    this.root.add(shadow);
    this.shadow = shadow;
  }

  private gasket!: Group;

  private addPart(id: PartId, group: Group, dir: Vector3, anchor: Vector3) {
    this.model.add(group);
    // Materialien je Teil eigenständig, damit Hervorheben nur ein Teil trifft
    const own = new Map<Material, MeshStandardMaterial>();
    group.traverse((o) => {
      const mesh = o as Mesh;
      if (!mesh.isMesh) return;
      const swap = (m: Material) => {
        if (!(m as MeshStandardMaterial).isMeshStandardMaterial) return m;
        if (!own.has(m)) own.set(m, (m as MeshStandardMaterial).clone());
        return own.get(m)!;
      };
      mesh.material = Array.isArray(mesh.material) ? mesh.material.map(swap) : swap(mesh.material);
    });
    // Teile mit eigener Leuchtfarbe (LEDs) bleiben beim Hervorheben unverändert
    const mats = [...own.values()].filter((m) => m.emissive.getHex() === 0);
    this.parts.set(id, {
      id,
      group,
      base: group.position.clone(),
      dir,
      anchor,
      mats,
      glow: 0,
    });
  }

  // ---------------------------------------------------------------------------
  // Steuerung

  resize(width: number, height: number) {
    this.width = Math.max(1, width);
    this.height = Math.max(1, height);
    this.renderer.setSize(this.width, this.height, false);
    this.dirty = true;
  }

  invalidate() {
    this.dirty = true;
  }

  private applyView() {
    const { fx, fy, ppm, rx, ry, explode, hop } = this.view;
    const w = this.width;
    const h = this.height;
    const dist = h / (2 * Math.tan(((FOV / 2) * Math.PI) / 180) * ppm);
    this.camera.aspect = w / h;
    this.camera.near = Math.max(1, dist - 400);
    this.camera.far = dist + 400;
    this.camera.position.set(0, 0, dist);
    this.camera.setViewOffset(w, h, -(fx - 0.5) * w, -(fy - 0.5) * h, w, h);
    this.camera.updateProjectionMatrix();

    this.root.rotation.set(rx + this.tilt.x, ry + this.tilt.y, 0);
    this.root.position.y = hop;
    this.model.position.z = -explode * 2;

    for (const p of this.parts.values()) {
      p.group.position.copy(p.base).addScaledVector(p.dir, easeExplode(explode, p.id) * this.spread);
      // Hervorgehobenes Teil hebt sich ein Stück an
      p.group.position.y += p.glow * 6 * explode;
    }
    // Schatten wird mit dem Zerlegen länger und blasser
    const len = 46 + explode * 96;
    this.shadow.scale.set(W * 1.55, len * 1.2, 1);
    this.shadow.position.z = explode * 4;
    (this.shadow.material as MeshBasicMaterial).opacity = 0.9 - explode * 0.35;
    this.gasket.visible = explode < 0.02;
  }

  /** Bildschirmposition (px) des Ankerpunkts eines Teils */
  project(id: PartId): { x: number; y: number } {
    const p = this.parts.get(id)!;
    const v = p.group.localToWorld(p.anchor.clone()).project(this.camera);
    return { x: ((v.x + 1) / 2) * this.width, y: ((1 - v.y) / 2) * this.height };
  }

  /** Punkt im Modell-Koordinatensystem (mm) auf den Bildschirm (px) */
  projectLocal(x: number, y: number, z: number): { x: number; y: number } {
    const v = this.model.localToWorld(new Vector3(x, y, z)).project(this.camera);
    return { x: ((v.x + 1) / 2) * this.width, y: ((1 - v.y) / 2) * this.height };
  }

  /** Bildschirm-Rechteck des zusammengebauten Körpers (ohne Neigung) */
  bodyRect() {
    const { fx, fy, ppm } = this.view;
    const cx = fx * this.width;
    const cy = fy * this.height - this.view.hop * ppm;
    return { x: cx - (W / 2) * ppm, y: cy - (H / 2) * ppm, w: W * ppm, h: H * ppm, cx, cy };
  }

  /** Welches Teil liegt unter dem Zeiger? (Bildschirm-Koordinaten relativ zur Canvas) */
  pick(x: number, y: number): PartId | null {
    const ndc = new Vector2((x / this.width) * 2 - 1, -(y / this.height) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const hits = this.raycaster.intersectObject(this.model, true);
    for (const hit of hits) {
      let o: Object3D | null = hit.object;
      while (o && o.parent !== this.model) o = o.parent;
      for (const p of this.parts.values()) if (p.group === o) return p.id;
    }
    return null;
  }

  /** dt in Sekunden */
  tick(dt: number) {
    this.eyes.update(dt);

    let glowing = false;
    for (const p of this.parts.values()) {
      const target = this.highlight === p.id ? 1 : 0;
      const next = p.glow + (target - p.glow) * (1 - Math.exp(-dt * 12));
      if (Math.abs(next - p.glow) > 0.001) {
        p.glow = next;
        for (const m of p.mats) {
          m.emissive.set('#ffffff');
          m.emissiveIntensity = p.glow * 0.1;
        }
        glowing = true;
      }
    }
    if (glowing) this.dirty = true;
    if (!this.dirty) return;
    this.dirty = false;
    this.applyView();
    this.renderer.render(this.scene, this.camera);
  }
}

// -----------------------------------------------------------------------------
// Geometrie-Helfer

function roundedRectPath<T extends Path>(w: number, h: number, r: number, cx = 0, cy = 0, path?: T): T {
  const p = (path ?? new Path()) as T;
  const x0 = cx - w / 2;
  const x1 = cx + w / 2;
  const y0 = cy - h / 2;
  const y1 = cy + h / 2;
  p.moveTo(x0 + r, y0);
  p.lineTo(x1 - r, y0);
  p.absarc(x1 - r, y0 + r, r, -Math.PI / 2, 0, false);
  p.lineTo(x1, y1 - r);
  p.absarc(x1 - r, y1 - r, r, 0, Math.PI / 2, false);
  p.lineTo(x0 + r, y1);
  p.absarc(x0 + r, y1 - r, r, Math.PI / 2, Math.PI, false);
  p.lineTo(x0, y0 + r);
  p.absarc(x0 + r, y0 + r, r, Math.PI, Math.PI * 1.5, false);
  return p;
}

function roundedRectShape(w: number, h: number, r: number, cx = 0, cy = 0) {
  return roundedRectPath(w, h, r, cx, cy, new Shape());
}

function circlePath(r: number, cx: number, cy: number) {
  const p = new Path();
  p.absarc(cx, cy, r, 0, Math.PI * 2, true);
  return p;
}

function pcbMesh(w: number, h: number, t: number, r: number, map: Texture, edge: string, holes: [number, number][]) {
  const shape = roundedRectShape(w, h, r);
  for (const [x, y] of holes) shape.holes.push(circlePath(1.25, x, y));
  const geo = new ExtrudeGeometry(shape, { depth: t, bevelEnabled: false, curveSegments: 20 });
  map.repeat.set(1 / w, 1 / h);
  map.offset.set(0.5, 0.5);
  const face = new MeshStandardMaterial({ map, roughness: 0.42, metalness: 0.08 });
  const side = new MeshStandardMaterial({ color: edge, roughness: 0.7 });
  const mesh = new Mesh(geo, [face, side]);
  // Rückseite schlicht einfärben: Kappe hinten bekommt dieselbe Textur, das reicht.
  mesh.position.z = -t;
  const g = new Group();
  g.add(mesh);
  return g;
}

function plastic(color: string, roughness = 0.6) {
  return new MeshStandardMaterial({ color, roughness, metalness: 0 });
}

function metal(color: string, roughness = 0.3, metalness = 1) {
  return new MeshStandardMaterial({ color, roughness, metalness });
}

let smdGeo: BufferGeometry | null = null;
let smdEndGeo: BufferGeometry | null = null;
function smd(g: Group, x: number, y: number, top: number, rotated = false) {
  smdGeo ??= new BoxGeometry(1.2, 1.25, 0.5);
  smdEndGeo ??= new BoxGeometry(0.4, 1.27, 0.52);
  const grp = new Group();
  const body = new Mesh(smdGeo, plastic('#2b2622', 0.6));
  grp.add(body);
  for (const s of [-1, 1]) {
    const end = new Mesh(smdEndGeo, metal('#d4d7da', 0.3));
    end.position.x = s * 0.8;
    grp.add(end);
  }
  grp.position.set(x, y, top + 0.25);
  if (rotated) grp.rotation.z = Math.PI / 2;
  g.add(grp);
}

// Teile starten beim Zerlegen leicht versetzt, das wirkt mechanischer
function easeExplode(t: number, id: PartId) {
  const i = PART_ORDER.indexOf(id);
  const delay = (3 - Math.abs(i - 3)) * 0.05;
  const local = Math.min(1, Math.max(0, (t - delay) / (1 - 0.15)));
  return local < 0.5 ? 4 * local * local * local : 1 - Math.pow(-2 * local + 2, 3) / 2;
}

// -----------------------------------------------------------------------------
// Texturen (in mm gezeichnet, Ursprung Mitte, y nach oben)

type Ctx = CanvasRenderingContext2D;

function pcbTexture(w: number, h: number, ppmm: number, mask: string, draw: (c: Ctx) => void) {
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(w * ppmm);
  canvas.height = Math.round(h * ppmm);
  const c = canvas.getContext('2d')!;
  c.fillStyle = mask;
  c.fillRect(0, 0, canvas.width, canvas.height);
  c.translate(canvas.width / 2, canvas.height / 2);
  c.scale(ppmm, -ppmm);
  draw(c);
  const tex = new CanvasTexture(canvas);
  tex.colorSpace = SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
}

const SILK = '#f2f3ee';
const GOLD = '#dcb45c';
const TRACE = 'rgba(120, 220, 160, 0.22)';

function text(c: Ctx, str: string, x: number, y: number, size: number, opts: { align?: CanvasTextAlign; weight?: number; mono?: boolean; color?: string; rotate?: number } = {}) {
  c.save();
  c.translate(x, y);
  c.scale(1, -1);
  if (opts.rotate) c.rotate(opts.rotate);
  c.fillStyle = opts.color ?? SILK;
  c.textAlign = opts.align ?? 'center';
  c.textBaseline = 'middle';
  const family = opts.mono ? '"Martian Mono Variable", ui-monospace, monospace' : '"Archivo Variable", Arial, sans-serif';
  c.font = `${opts.weight ?? 700} ${size}px ${family}`;
  c.fillText(str, 0, 0);
  c.restore();
}

function pad(c: Ctx, x: number, y: number, r = 0.85, drill = 0.45) {
  c.fillStyle = GOLD;
  c.beginPath();
  c.arc(x, y, r, 0, Math.PI * 2);
  c.fill();
  c.fillStyle = '#1b1b18';
  c.beginPath();
  c.arc(x, y, drill, 0, Math.PI * 2);
  c.fill();
}

function smdPad(c: Ctx, x: number, y: number, w: number, h: number) {
  c.fillStyle = GOLD;
  c.fillRect(x - w / 2, y - h / 2, w, h);
}

function trace(c: Ctx, pts: [number, number][], width = 0.4) {
  c.strokeStyle = TRACE;
  c.lineWidth = width;
  c.lineJoin = 'round';
  c.lineCap = 'round';
  c.beginPath();
  pts.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y)));
  c.stroke();
}

function outline(c: Ctx, x: number, y: number, w: number, h: number, lw = 0.18) {
  c.strokeStyle = SILK;
  c.lineWidth = lw;
  c.strokeRect(x - w / 2, y - h / 2, w, h);
}

function drawKumpelPcb(c: Ctx, w: number, h: number) {
  // Kupferfläche unter dem Lack
  c.fillStyle = 'rgba(120, 220, 160, 0.06)';
  c.fillRect(-w / 2 + 1.5, -h / 2 + 1.5, w - 3, h - 3);

  // Leiterbahnen im 45°-Raster
  trace(c, [[-0.4, 5.36], [3, 8.76], [3, 13], [1.27, 14.7]]);
  trace(c, [[-0.4, 2.82], [5, 8.2], [5, 13.4], [3.81, 14.6]]);
  trace(c, [[-15.6, 7.9], [-19, 11.3], [-19, 15], [-17.4, 16.6]]);
  trace(c, [[-0.4, 0.28], [4, 0.28], [7, -2.7]]);
  trace(c, [[-0.4, -2.26], [3.5, -6.16], [3.5, -9], [5, -10.5]]);
  trace(c, [[17.3, -11], [19.5, -8.8], [19.5, 4], [21, 5.5]], 0.6);
  trace(c, [[-0.4, -7.34], [2, -9.74], [2, -14.5], [10.7, -14.5]]);
  trace(c, [[17.3, -12], [21.5, -12]]);
  trace(c, [[-15.6, -9.88], [-19, -13.28], [-21.4, -13.28]]);
  trace(c, [[10.6, 16.8], [7.6, 16.8], [6, 15.2], [3.81, 15.2]]);
  trace(c, [[-3.81, 15.2], [-6, 15.2], [-8, 17.2], [-10.6, 17.2]]);

  // Montagelöcher mit Ring
  for (const [x, y] of [[-21.5, -15.5], [21.5, -15.5], [-21.5, 15.5], [21.5, 15.5]] as [number, number][]) {
    c.fillStyle = GOLD;
    c.beginPath();
    c.arc(x, y, 2.3, 0, Math.PI * 2);
    c.fill();
  }

  // ESP32-Footprint: 2 × 8 Pads
  for (let i = 0; i < 8; i++) {
    pad(c, -15.6, 7.9 - i * 2.54);
    pad(c, -0.4, 7.9 - i * 2.54);
  }
  outline(c, -8, -1, 18.6, 23);
  text(c, 'U1  ESP32-C3', -8, -13.4, 1.0, { mono: true, weight: 500 });

  // OLED-Anschluss
  ['GND', 'VCC', 'SCL', 'SDA'].forEach((l, i) => {
    const x = -3.81 + i * 2.54;
    pad(c, x, 15.2);
    text(c, l, x, 12.9, 0.8, { mono: true, weight: 500 });
  });

  // Taster
  for (const x of [-14, 14]) {
    smdPad(c, x - 3.4, 16.8, 1.4, 1.6);
    smdPad(c, x + 3.4, 16.8, 1.4, 1.6);
    text(c, x < 0 ? 'SW1' : 'SW2', x, 14.4, 1.0, { mono: true, weight: 500 });
  }

  // Summer, Lade-IC, Stecker, LED
  c.strokeStyle = SILK;
  c.lineWidth = 0.18;
  c.beginPath();
  c.arc(12, -1, 5.2, 0, Math.PI * 2);
  c.stroke();
  text(c, 'BZ1', 12, 5.2, 1.0, { mono: true, weight: 500 });
  outline(c, 14, -11, 6.6, 5.6);
  text(c, 'U2', 9.3, -11, 1.0, { mono: true, weight: 500 });
  outline(c, 21, 9, 7, 5.4);
  text(c, 'BAT', 21, 12.6, 1.0, { mono: true, weight: 500 });
  text(c, '+', 19.2, 5.4, 1.2, { mono: true });
  text(c, '−', 22.8, 5.4, 1.2, { mono: true });
  text(c, 'CHG', 21.5, -9.9, 0.85, { mono: true, weight: 500 });

  // Übungs-Pads
  c.strokeStyle = SILK;
  c.lineWidth = 0.18;
  c.strokeRect(-22.4, -18.2, 19.4, 3.6);
  for (let i = 0; i < 5; i++) pad(c, -20.6 + i * 2.6, -16.4, 0.8, 0.4);
  text(c, 'ÜBEN', -5.9, -16.4, 1.15, { weight: 800 });

  // Titel und Gruß
  text(c, 'KUMPEL', 6, 12.2, 2.4, { weight: 800, align: 'left' });
  text(c, 'v1.0', 6.1, 9.7, 1.1, { mono: true, weight: 500, align: 'left' });
  text(c, 'kleinteil', 3.4, -16.9, 1.5, { weight: 800, align: 'left' });
  text(c, 'Hallo! Du hast mich gebaut.', 12.6, -17.4, 0.8, { weight: 600, align: 'left' });
}

function drawOledPcb(c: Ctx, _w: number, _h: number) {
  ['GND', 'VCC', 'SCL', 'SDA'].forEach((l, i) => {
    const x = -3.81 + i * 2.54;
    pad(c, x, 15.2);
    text(c, l, x, 12.8, 0.9, { mono: true, weight: 500 });
  });
  for (const [x, y] of [[-15.5, -14.5], [15.5, -14.5], [-15.5, 14.5], [15.5, 14.5]] as [number, number][]) {
    c.fillStyle = GOLD;
    c.beginPath();
    c.arc(x, y, 2.1, 0, Math.PI * 2);
    c.fill();
  }
  text(c, '1.3" OLED', -10, 15.4, 1.1, { mono: true, weight: 500 });
  text(c, 'SH1106', 10.5, 15.4, 1.1, { mono: true, weight: 500 });
  smdPad(c, -12, -13.8, 1.2, 1.6);
  smdPad(c, -9.5, -13.8, 1.2, 1.6);
  smdPad(c, 9.5, -13.8, 1.2, 1.6);
  smdPad(c, 12, -13.8, 1.2, 1.6);
}

function drawEspPcb(c: Ctx, w: number, h: number) {
  const left = ['5V', 'G', '3V3', '4', '3', '2', '1', '0'];
  const right = ['5', '6', '7', '8', '9', '10', '20', '21'];
  for (let i = 0; i < 8; i++) {
    const y = 8.89 - i * 2.54;
    pad(c, -7.62, y, 0.85, 0.42);
    pad(c, 7.62, y, 0.85, 0.42);
    text(c, left[i], -5.6, y, 0.72, { mono: true, weight: 500 });
    text(c, right[i], 5.6, y, 0.72, { mono: true, weight: 500 });
  }
  text(c, 'C3 SuperMini', 0, 5.6, 0.95, { weight: 700 });
  void w;
  void h;
}

function chipTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const c = canvas.getContext('2d')!;
  c.fillStyle = 'rgba(255,255,255,0.0)';
  c.fillRect(0, 0, 128, 128);
  c.fillStyle = 'rgba(210, 214, 220, 0.55)';
  c.font = '600 15px "Martian Mono Variable", monospace';
  c.textAlign = 'center';
  c.fillText('ESP32-C3', 64, 56);
  c.font = '500 13px "Martian Mono Variable", monospace';
  c.fillText('FH4  2541', 64, 78);
  c.beginPath();
  c.arc(22, 22, 5, 0, Math.PI * 2);
  c.fill();
  const tex = new CanvasTexture(canvas);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function batteryTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 620;
  canvas.height = 410;
  const c = canvas.getContext('2d')!;
  c.fillStyle = '#d7dadd';
  c.fillRect(0, 0, 620, 410);
  c.fillStyle = '#23272b';
  c.font = '800 96px "Archivo Variable", Arial, sans-serif';
  c.fillText('LiPo', 34, 130);
  c.font = '500 38px "Martian Mono Variable", monospace';
  c.fillText('3,7 V   400 mAh', 38, 200);
  c.fillText('402535   1,48 Wh', 38, 252);
  c.fillStyle = '#9aa0a6';
  for (let i = 0; i < 4; i++) c.fillRect(38, 298 + i * 22, 300 + ((i * 83) % 160), 9);
  c.strokeStyle = '#23272b';
  c.lineWidth = 6;
  c.beginPath();
  c.arc(500, 120, 52, 0, Math.PI * 2);
  c.stroke();
  c.font = '800 44px "Archivo Variable", Arial, sans-serif';
  c.textAlign = 'center';
  c.fillText('+', 500, 136);
  const tex = new CanvasTexture(canvas);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function noteTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 900;
  canvas.height = 225;
  const c = canvas.getContext('2d')!;
  c.fillStyle = 'rgba(80, 92, 86, 0.55)';
  c.textAlign = 'center';
  c.font = '800 54px "Archivo Variable", Arial, sans-serif';
  c.fillText('kleinteil · KUMPEL v1', 450, 95);
  c.font = '500 34px "Martian Mono Variable", monospace';
  c.fillText('Danke, dass du mich gebaut hast.', 450, 160);
  const tex = new CanvasTexture(canvas);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function radialShadow() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const c = canvas.getContext('2d')!;
  const g = c.createRadialGradient(128, 128, 0, 128, 128, 128);
  g.addColorStop(0, 'rgba(20, 30, 25, 0.42)');
  g.addColorStop(0.45, 'rgba(20, 30, 25, 0.2)');
  g.addColorStop(1, 'rgba(20, 30, 25, 0)');
  c.fillStyle = g;
  c.fillRect(0, 0, 256, 256);
  return canvas;
}

export function webglAvailable() {
  try {
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch {
    return false;
  }
}

