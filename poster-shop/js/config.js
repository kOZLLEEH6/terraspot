/*
 * Alles, was du im Shop anpassen willst, steht in dieser Datei:
 * Name, Kontakt, Preise, Versand und die Motive selbst.
 * Bilder liegen in img/prints/ (jeweils groß + "-sm" als Vorschau).
 */
window.SHOP = {
  brand: "Lichtjahr",
  tagline: "Astrofotografie",
  email: "bestellung@example.com",
  instagram: "https://www.instagram.com/",

  // Wohin die Bestellanfrage geht. Leer lassen = es öffnet sich eine
  // fertige E-Mail an `email`. Mit einem Formspree-Endpunkt
  // (https://formspree.io/f/xxxx) wird die Anfrage direkt verschickt.
  orderEndpoint: "",

  currency: "EUR",
  taxNote: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.",
  taxNoteShort: "Keine USt. nach § 19 UStG",
  shipping: { flat: 6.9, freeFrom: 120 },

  // Formate: kurze × lange Seite in cm. Seitenverhältnis 2:3, wie aus der Kamera.
  sizes: [
    { id: "20x30", short: 20, long: 30, hint: "Regal, Schreibtisch" },
    { id: "40x60", short: 40, long: 60, hint: "Flur, kleinere Wand" },
    { id: "60x90", short: 60, long: 90, hint: "Über Sofa oder Bett" },
    { id: "80x120", short: 80, long: 120, hint: "Große, freie Wand" },
  ],

  materials: [
    { id: "papier", label: "Fine-Art-Papier", note: "Matt, mit 2 cm weißem Rand. Ideal für einen eigenen Rahmen." },
    { id: "alu", label: "Alu-Dibond", note: "3 mm, randlos, mit Aufhängung auf der Rückseite." },
    { id: "acryl", label: "Acrylglas", note: "Glänzend, die Schwärzen wirken besonders tief." },
  ],

  // Preis je Format und Material in Euro
  prices: {
    "20x30": { papier: 29, alu: 69, acryl: 89 },
    "40x60": { papier: 49, alu: 119, acryl: 149 },
    "60x90": { papier: 79, alu: 189, acryl: 239 },
    "80x120": { papier: 119, alu: 279, acryl: 349 },
  },

  categories: [
    { id: "nebel", label: "Nebel" },
    { id: "galaxien", label: "Galaxien" },
    { id: "sternhaufen", label: "Sternhaufen" },
  ],

  // Motive. orientation: "portrait" (hoch) oder "landscape" (quer).
  // light: wie lange das Licht unterwegs war, erscheint im Detailfenster.
  prints: [
    {
      id: "m45-plejaden",
      title: "Plejaden",
      catalog: "M45",
      category: "sternhaufen",
      orientation: "portrait",
      coords: "RA 03h 47m 24s · Dec +24° 07′ 00″",
      light: "444 Jahre",
      text: "Das Siebengestirn im Stier. Der blaue Schleier ist Staub, durch den der Sternhaufen gerade zieht. Er reflektiert das Licht der heißen, jungen Sterne.",
      data: [
        ["Entfernung", "444 Lichtjahre"],
        ["Teleskop", "Seestar S30 Pro"],
      ],
    },
    {
      id: "ngc1499-kaliforniennebel",
      title: "Kaliforniennebel",
      catalog: "NGC 1499",
      category: "nebel",
      orientation: "portrait",
      coords: "RA 04h 03m 18s · Dec +36° 25′ 18″",
      light: "1.000 Jahre",
      text: "Eine Wolke aus Wasserstoff im Sternbild Perseus. Der heiße Stern Xi Persei regt das Gas zum Leuchten an, und die lang gezogene Form erinnert an den Umriss Kaliforniens.",
      data: [
        ["Entfernung", "1.000 Lichtjahre"],
        ["Belichtung", "19 min"],
        ["Teleskop", "Seestar S30 Pro"],
        ["Aufgenommen", "6. April 2026"],
      ],
    },
    {
      id: "m13-herkuleshaufen",
      title: "Herkuleshaufen",
      catalog: "M13",
      category: "sternhaufen",
      orientation: "portrait",
      coords: "RA 16h 41m 41s · Dec +36° 27′ 36″",
      light: "22.200 Jahre",
      text: "Ein Kugelsternhaufen im Herkules: mehrere Hunderttausend Sterne auf engem Raum, die meisten über elf Milliarden Jahre alt. Links daneben liegt die kleine Galaxie NGC 6207, weit hinter dem Haufen.",
      data: [
        ["Entfernung", "22.200 Lichtjahre"],
        ["Belichtung", "24 min"],
        ["Teleskop", "Seestar S30 Pro"],
        ["Aufgenommen", "25. Mai 2026"],
      ],
    },
    {
      id: "m108-m97",
      title: "Surfbrett und Eule",
      catalog: "M108 · M97",
      category: "galaxien",
      orientation: "portrait",
      coords: "RA 11h 11m 31s · Dec +55° 40′ 27″",
      light: "46 Millionen Jahre",
      text: "Zwei sehr verschiedene Dinge in einem Bild. In der Mitte die Galaxie M108, die wir fast von der Kante sehen. Darunter der runde Eulennebel M97, die Gashülle eines sterbenden Sterns in unserer eigenen Milchstraße. Sein Licht war rund 2.000 Jahre unterwegs, das der Galaxie 46 Millionen.",
      data: [
        ["Entfernung M108", "46 Mio. Lichtjahre"],
        ["Entfernung M97", "2.000 Lichtjahre"],
        ["Belichtung", "14 min"],
        ["Teleskop", "Seestar S30 Pro"],
        ["Aufgenommen", "7. April 2026"],
      ],
    },
  ],
};
