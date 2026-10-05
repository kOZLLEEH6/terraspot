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
    { id: "deep-sky", label: "Deep Sky" },
    { id: "sternspuren", label: "Sternspuren" },
    { id: "milchstrasse", label: "Milchstraße" },
    { id: "mond", label: "Mond & Planeten" },
  ],

  // Motive. orientation: "portrait" (hoch) oder "landscape" (quer).
  // light: wie lange das Licht unterwegs war, erscheint im Detailfenster.
  prints: [
    {
      id: "m42-orionnebel",
      title: "Orionnebel",
      catalog: "M42",
      category: "deep-sky",
      orientation: "landscape",
      coords: "RA 05h 35m 17s · Dec −05° 23′ 28″",
      light: "1.344 Jahre",
      text: "Die Sternentstehungsregion im Schwert des Orion. Im hellen Kern sitzt das Trapez, vier junge Sterne, die das Gas um sie herum zum Leuchten bringen.",
      data: [
        ["Entfernung", "1.344 Lichtjahre"],
        ["Belichtung", "6 h 20 min · 76 × 300 s"],
        ["Optik", "80/480 mm Refraktor"],
        ["Kamera", "Gekühlte Farbkamera"],
      ],
    },
    {
      id: "m31-andromeda",
      title: "Andromedagalaxie",
      catalog: "M31",
      category: "deep-sky",
      orientation: "landscape",
      coords: "RA 00h 42m 44s · Dec +41° 16′ 09″",
      light: "2,5 Millionen Jahre",
      text: "Unsere große Nachbargalaxie. Unter dunklem Himmel siehst du sie sogar mit bloßem Auge. Rechts unter dem Kern die Begleiterin M32, oben links M110.",
      data: [
        ["Entfernung", "2,5 Mio. Lichtjahre"],
        ["Belichtung", "9 h 40 min · 116 × 300 s"],
        ["Optik", "80/480 mm Refraktor"],
        ["Kamera", "Gekühlte Farbkamera"],
      ],
    },
    {
      id: "m45-plejaden",
      title: "Plejaden",
      catalog: "M45",
      category: "deep-sky",
      orientation: "landscape",
      coords: "RA 03h 47m 24s · Dec +24° 07′ 00″",
      light: "444 Jahre",
      text: "Das Siebengestirn im Stier. Der blaue Schleier ist Staub, durch den der Sternhaufen gerade zieht. Er reflektiert das Licht der heißen, jungen Sterne.",
      data: [
        ["Entfernung", "444 Lichtjahre"],
        ["Belichtung", "5 h 10 min · 62 × 300 s"],
        ["Optik", "80/480 mm Refraktor"],
        ["Kamera", "Gekühlte Farbkamera"],
      ],
    },
    {
      id: "ngc6960-cirrusnebel",
      title: "Cirrusnebel",
      catalog: "NGC 6960",
      category: "deep-sky",
      orientation: "portrait",
      coords: "RA 20h 45m 38s · Dec +30° 42′ 30″",
      light: "2.400 Jahre",
      text: "Der Überrest einer Supernova, die vor 10.000 bis 20.000 Jahren explodiert ist. Rot leuchtet Wasserstoff, türkis Sauerstoff. Der helle Stern mittendrin ist 52 Cygni.",
      data: [
        ["Entfernung", "2.400 Lichtjahre"],
        ["Belichtung", "8 h · Hα und OIII"],
        ["Optik", "80/480 mm Refraktor"],
        ["Filter", "Dualband 7 nm"],
      ],
    },
    {
      id: "ngc2237-rosette",
      title: "Rosettennebel",
      catalog: "NGC 2237",
      category: "deep-sky",
      orientation: "landscape",
      coords: "RA 06h 33m 45s · Dec +04° 59′ 54″",
      light: "5.200 Jahre",
      text: "Aufgenommen mit Schmalbandfiltern im Hubble-Farbschema: Schwefel und Wasserstoff erscheinen golden, Sauerstoff türkis. In der Mitte liegt der junge Sternhaufen NGC 2244.",
      data: [
        ["Entfernung", "5.200 Lichtjahre"],
        ["Belichtung", "12 h · SII, Hα, OIII"],
        ["Optik", "80/480 mm Refraktor"],
        ["Kamera", "Gekühlte Monokamera"],
      ],
    },
    {
      id: "m51-whirlpool",
      title: "Whirlpool-Galaxie",
      catalog: "M51",
      category: "deep-sky",
      orientation: "landscape",
      coords: "RA 13h 29m 52s · Dec +47° 11′ 43″",
      light: "23 Millionen Jahre",
      text: "Eine Spiralgalaxie unter der Deichsel des Großen Wagens. An ihrem äußeren Arm hängt die kleine Begleitgalaxie NGC 5195, die beiden ziehen aneinander.",
      data: [
        ["Entfernung", "23 Mio. Lichtjahre"],
        ["Belichtung", "11 h 30 min · 138 × 300 s"],
        ["Optik", "80/480 mm Refraktor"],
        ["Kamera", "Gekühlte Farbkamera"],
      ],
    },
    {
      id: "sternspuren-fichtenwald",
      title: "Kreise über dem Fichtenwald",
      catalog: "Polaris",
      category: "sternspuren",
      orientation: "portrait",
      coords: "Blick nach Norden · 78° Erddrehung",
      text: "Gut fünf Stunden Belichtung Richtung Norden. Fast in der Mitte steht der Polarstern, er hat sich in der ganzen Zeit kaum bewegt.",
      data: [
        ["Belichtung", "5 h 12 min · 312 × 60 s"],
        ["Erddrehung", "78°"],
        ["Objektiv", "14 mm · f/2.8"],
        ["Kamera", "Vollformat, ISO 800"],
      ],
    },
    {
      id: "sternspuren-bergkamm",
      title: "Bögen über dem Grat",
      catalog: "Nordhimmel",
      category: "sternspuren",
      orientation: "landscape",
      coords: "Blick nach Norden · 42° Erddrehung",
      text: "Der Polarstern steht knapp über dem Bildrand, die Sterne ziehen ihre Bögen um ihn herum über den Bergkamm.",
      data: [
        ["Belichtung", "2 h 48 min · 168 × 60 s"],
        ["Erddrehung", "42°"],
        ["Objektiv", "14 mm · f/2.8"],
        ["Kamera", "Vollformat, ISO 800"],
      ],
    },
    {
      id: "sternspuren-bergsee",
      title: "Spiegelung am Bergsee",
      catalog: "Osthimmel",
      category: "sternspuren",
      orientation: "landscape",
      coords: "Blick nach Osten · 11° Erddrehung",
      text: "Nach Osten fotografiert steigen die Sterne schräg über den Horizont. In der Nacht war kein Wind, deshalb spiegelt der See jede Spur.",
      data: [
        ["Belichtung", "44 min · 88 × 30 s"],
        ["Erddrehung", "11°"],
        ["Objektiv", "20 mm · f/1.8"],
        ["Kamera", "Vollformat, ISO 1600"],
      ],
    },
    {
      id: "milchstrasse-zentrum",
      title: "Zentrum der Milchstraße",
      catalog: "Sgr A*",
      category: "milchstrasse",
      orientation: "portrait",
      coords: "RA 17h 45m 40s · Dec −29° 00′ 28″",
      light: "26.000 Jahre",
      text: "Der hellste Teil unserer eigenen Galaxie steht im Sommer tief im Süden. Die dunklen Bänder sind Staubwolken, die das Licht der Sterne dahinter schlucken.",
      data: [
        ["Entfernung", "26.000 Lichtjahre"],
        ["Belichtung", "20 × 20 s, gestackt"],
        ["Objektiv", "24 mm · f/1.4"],
        ["Kamera", "Vollformat, ISO 3200"],
      ],
    },
    {
      id: "mond-zunehmend",
      title: "Zunehmender Mond",
      catalog: "Luna",
      category: "mond",
      orientation: "landscape",
      coords: "384.400 km · 79 % beleuchtet",
      light: "1,3 Sekunden",
      text: "Ein Mosaik aus vier Feldern. An der Schattengrenze stehen die Kraterwände im flachen Sonnenlicht, deshalb wirkt die Oberfläche dort so plastisch.",
      data: [
        ["Entfernung", "384.400 km"],
        ["Aufnahme", "Mosaik, 4 Felder"],
        ["Optik", "80/480 mm + 2× Barlow"],
        ["Kamera", "Planetenkamera, je 2.000 Frames"],
      ],
    },
    {
      id: "saturn-ringe",
      title: "Saturn",
      catalog: "Saturn",
      category: "mond",
      orientation: "landscape",
      coords: "1,3 Mrd. km · Ringöffnung 21°",
      light: "71 Minuten",
      text: "Aus Tausenden kurzen Videoframes wurden nur die schärfsten gestapelt. Gut zu sehen: die dunkle Cassini-Teilung im Ring und der Schatten, den der Planet auf die Ringe wirft. Rechts oben steht der Mond Titan.",
      data: [
        ["Entfernung", "1,3 Mrd. km"],
        ["Aufnahme", "Beste 15 % aus 12.000 Frames"],
        ["Optik", "80/480 mm + 3× Barlow"],
        ["Kamera", "Planetenkamera"],
      ],
    },
  ],
};
