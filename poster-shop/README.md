# Lichtjahr: Poster-Shop für Astrofotos

Statische Website ohne Build-Schritt: HTML, CSS und ein bisschen JavaScript. Läuft auf jedem
Webspace, GitHub Pages, Netlify oder Cloudflare Pages.

> **Wichtig:** Die Bilder in `img/prints/` sind eigene Aufnahmen mit dem Seestar S30 Pro,
> zugeschnitten aus den Bildern, die die Seestar-App teilt (1080 × 1920 Pixel, ohne die Leiste
> unten). Für die Website reicht das, für Drucke nicht: Zum Drucken die Originale in voller
> Auflösung aus der App exportieren. Der Text unter „Über mich“ ist ein Vorschlag, den du in
> deine eigenen Worte bringen solltest.

## Lokal ansehen

```bash
cd poster-shop
npx serve .            # oder: python3 -m http.server 8000
```

Dann `http://localhost:3000` (bzw. `:8000`) öffnen.

## Was wo steht

| Datei | Inhalt |
| --- | --- |
| `js/config.js` | **Alles, was du anpasst:** Name, E-Mail, Preise, Versand, Formate, Materialien und die Motive |
| `index.html` | Seitenaufbau und feste Texte (Hero, „Über mich“, FAQ) |
| `css/style.css` | Gestaltung. Farben und Schriften stehen ganz oben als Variablen |
| `js/sky.js` | Die Sternspuren-Animation im Hero |
| `js/app.js` | Galerie, Filter, Detailansicht, Warenkorb, Bestellanfrage, Scroll-Animationen |
| `rechtliches.html` | Impressum, Datenschutz, Widerrufsbelehrung (Vorlage!) |
| `img/prints/` | Je Motiv ein großes Bild und eine Vorschau |
| `fonts/`, `vendor/` | Schriften und GSAP liegen lokal, damit keine Daten an Google & Co. gehen |

## Eigene Fotos einbauen

1. Pro Motiv zwei JPGs nach `img/prints/` legen:
   - `mein-motiv.jpg`, lange Kante ca. 2000 bis 2500 px (für die Detailansicht)
   - `mein-motiv-sm.jpg`, lange Kante 1000 px (für die Galerie)

   Mit ImageMagick zum Beispiel:
   ```bash
   magick original.tif -resize 2400x2400 -quality 84 -strip mein-motiv.jpg
   magick original.tif -resize 1000x1000 -quality 82 -strip mein-motiv-sm.jpg
   ```
   Lade **nicht** die volle Auflösung hoch. Die braucht die Seite nicht und sie lädt sonst jeder runter.

2. In `js/config.js` unter `prints` einen Eintrag anlegen (oder einen Platzhalter überschreiben).
   `id` muss genau dem Dateinamen ohne `.jpg` entsprechen.

3. **Seitenverhältnis:** Alle Formate sind 2:3 (20 × 30, 40 × 60, …). Das passt zu den meisten
   DSLRs und vielen Astrokameras. Hat deine Kamera ein anderes Format (z. B. quadratischer
   IMX533-Sensor oder 16:9), schneide die Bilder auf 2:3 zu oder sag Bescheid, dann baue ich
   Formate pro Seitenverhältnis ein.

Das Bild in der Scroll-Sequenz „Vom Okular an die Wand“ ist in `index.html` fest eingetragen
(`m45-plejaden.jpg`), dort einfach den Dateinamen tauschen.

## Wie Bestellungen gerade funktionieren

Ehrlich gesagt: Es gibt noch **keine Online-Zahlung**. Der Warenkorb endet in einer
Bestellanfrage.

- **Ohne weitere Einrichtung** öffnet sich beim Kunden das Mailprogramm mit einer fertig
  ausgefüllten Mail an deine Adresse. Klappt das nicht, kann der Kunde die Bestellung kopieren.
- **Besser:** Kostenloses Formular bei [Formspree](https://formspree.io) anlegen und die URL in
  `config.js` bei `orderEndpoint` eintragen. Dann kommt die Anfrage direkt bei dir an, ohne dass
  der Kunde selbst eine Mail abschicken muss. (Formspree dann in der Datenschutzerklärung nennen.)

Du antwortest mit PayPal- oder Bankdaten, druckst bzw. bestellst den Print und verschickst ihn.
Für den Anfang reicht das völlig. Wenn es mehr wird, sind die nächsten Schritte:

- **Stripe Checkout** über eine kleine Serverless-Funktion (z. B. Netlify Functions): echte
  Kartenzahlung, Apple Pay, PayPal; der Warenkorb bleibt wie er ist.
- **Print on Demand** (z. B. Prodigi, Gelato, WhiteWall): Druck und Versand laufen automatisch,
  du siehst die Bestellung nur noch.

## Online stellen

- **Am schnellsten:** [Netlify Drop](https://app.netlify.com/drop), den Ordner `poster-shop`
  reinziehen, fertig. Eigene Domain kannst du danach verbinden.
- **GitHub Pages:** Den Inhalt von `poster-shop/` in ein eigenes Repo legen und Pages aktivieren.
  Der Shop hat mit der TerraSpot-App nichts zu tun, ein eigenes Repo ist deshalb sauberer.

## Bevor du live gehst

Das ist kein Rechtsrat, aber diese Punkte solltest du geklärt haben:

- **Impressum, Datenschutz, Widerruf:** `rechtliches.html` ist eine Vorlage mit Platzhaltern.
  Ausfüllen und prüfen lassen (Anwalt oder Generator wie e-recht24 / IT-Recht Kanzlei).
- **Anmeldung beim Finanzamt:** Wer regelmäßig Prints verkauft, ist unternehmerisch tätig.
  Kläre, ob das als künstlerische oder gewerbliche Tätigkeit läuft und ob du die
  Kleinunternehmerregelung nutzt. Der Hinweis „§ 19 UStG“ steht in `config.js` (`taxNote`) und
  muss raus, falls du Umsatzsteuer ausweist.
- **Widerrufsbutton:** Seit Juni 2026 gelten EU-weit neue Regeln für eine Widerrufsfunktion bei
  online geschlossenen Verträgen. Lass prüfen, ob und wie das bei deinem Ablauf
  (Anfrage → Rechnung per Mail) greift.
- **Preise und Versand:** Die Preise in `config.js` sind Beispielwerte. Rechne sie mit deinen
  echten Druck- und Versandkosten nach (Alu und Acryl sind im Versand deutlich teurer als eine
  Papierrolle, der Shop rechnet aktuell pauschal).

## Technik

- Keine Abhängigkeiten zur Laufzeit außer [GSAP 3.13](https://gsap.com) (lokal in `vendor/`,
  kostenlose Lizenz) für Scroll-Animationen und den Filter-Übergang.
- Schriften: Jost, Instrument Sans, IBM Plex Mono (SIL Open Font License), selbst gehostet.
- Wer im Betriebssystem „Bewegung reduzieren“ eingestellt hat, bekommt eine ruhige Version
  ohne Scroll-Effekte.
- Der Warenkorb liegt im `localStorage` des Browsers, es gibt keine Cookies.
- Jeder geöffnete Print hat einen eigenen Link (z. B. `index.html#print-m45-plejaden`), den man
  teilen kann. Die Zurück-Taste am Handy schließt die Detailansicht.
- In der Detailansicht blättert man mit Pfeiltasten, Wischen oder den Pfeilen unten rechts.
  Ein Klick aufs Bild zoomt in die volle Auflösung (Maus bewegen bzw. Finger ziehen zum Verschieben).
- `og:image` in `index.html` braucht für Vorschaubilder in WhatsApp & Co. die volle Adresse,
  sobald du eine Domain hast.
