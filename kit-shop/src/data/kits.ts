// Produktdaten. Preise in Cent, inklusive MwSt.
// Der Checkout (netlify/functions/checkout.mjs) liest Preise ebenfalls von hier,
// damit niemand im Browser den Preis manipulieren kann.

export type Kit = {
  id: string;
  nr: string;
  name: string;
  short: string;
  price: number;
  status: 'available' | 'soon';
  solder: number;
  time: string;
  age: string;
  level: 1 | 2 | 3;
  learn: string[];
};

export type Addon = {
  id: string;
  name: string;
  short: string;
  price: number;
};

export const kits: Kit[] = [
  {
    id: 'grundkurs',
    nr: '00',
    name: 'Grundkurs',
    short:
      'Elektronik ohne Löten. 12 Experimente auf dem Steckbrett, vom ersten Blinken bis zum Abstandsmesser.',
    price: 3900,
    status: 'available',
    solder: 0,
    time: '12 × 30 Min.',
    age: 'ab 14',
    level: 1,
    learn: ['Strom & Spannung', 'LEDs & Widerstände', 'Taster', 'Sensoren', 'Servo'],
  },
  {
    id: 'kumpel',
    nr: '01',
    name: 'Kumpel',
    short:
      'Dein Schreibtisch-Kumpel mit OLED-Gesicht, Akku und WLAN. Schaut dich an, schläft ein und freut sich, wenn du ihn drückst.',
    price: 4900,
    status: 'available',
    solder: 24,
    time: 'ca. 3 Std.',
    age: 'ab 14',
    level: 2,
    learn: ['Löten', 'I²C & Displays', 'Akku & Laden', 'Animation', 'WLAN'],
  },
  {
    id: 'wetterfrosch',
    nr: '02',
    name: 'Wetterfrosch',
    short:
      'E-Paper-Wetterstation für Temperatur, Luftfeuchte und Vorhersage. Hält mit einer Akkuladung wochenlang durch.',
    price: 5900,
    status: 'available',
    solder: 16,
    time: 'ca. 4 Std.',
    age: 'ab 14',
    level: 3,
    learn: ['WLAN & APIs', 'JSON', 'Sensoren', 'E-Paper', 'Deep Sleep'],
  },
  {
    id: 'pixeluhr',
    nr: '03',
    name: 'Pixeluhr',
    short: '256 LEDs, eine Uhr und so viele Animationen, wie du programmierst.',
    price: 6900,
    status: 'soon',
    solder: 40,
    time: 'ca. 5 Std.',
    age: 'ab 14',
    level: 3,
    learn: ['LED-Matrix', 'NTP-Zeit', 'Webinterface'],
  },
];

export const addons: Addon[] = [
  {
    id: 'loetset',
    name: 'Lötset',
    short: 'Lötkolben 60 W mit Temperaturregler, Ablage, bleifreies Lötzinn, Entlötlitze.',
    price: 2400,
  },
];

// Stückliste des Kumpels. Pos. 1 bis 7 sind in der Explosionsansicht zu sehen.
export const kumpelBom = [
  { pos: 1, qty: 1, name: 'Gehäuse vorne', spec: 'PLA, 3D-gedruckt' },
  { pos: 2, qty: 1, name: 'OLED-Display', spec: '1,3″ · 128 × 64 px · I²C' },
  { pos: 3, qty: 1, name: 'ESP32-C3 Super Mini', spec: '160 MHz · WLAN · Bluetooth 5' },
  { pos: 4, qty: 1, name: 'Kumpel-Platine', spec: 'Ladeschaltung, Summer, 2 Taster' },
  { pos: 5, qty: 2, name: 'Tastenkappen', spec: 'sitzen oben, wie Ohren' },
  { pos: 6, qty: 1, name: 'LiPo-Akku', spec: '3,7 V · 400 mAh' },
  { pos: 7, qty: 1, name: 'Gehäuse hinten', spec: 'mit Öffnung für USB-C' },
  { pos: 8, qty: 6, name: 'Schrauben', spec: 'M2 × 6, zwei als Ersatz' },
  { pos: 9, qty: 1, name: 'Kleinkram-Tüte', spec: 'Stiftleisten, Kabel, Ersatzteile' },
];

export const allProducts = [
  ...kits.map((k) => ({ id: k.id, name: `Bausatz ${k.nr} · ${k.name}`, price: k.price, buyable: k.status === 'available' })),
  ...addons.map((a) => ({ id: a.id, name: a.name, price: a.price, buyable: true })),
];
