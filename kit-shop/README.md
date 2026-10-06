# kleinteil · Shop-Website für ESP32-Bausätze

Startseite mit 3D-Kumpel, Explosionsansicht beim Scrollen, Stückliste, Ablauf,
Code-Spielwiese, Produktkarten, Warenkorb und FAQ. Gebaut mit Astro, three.js,
GSAP und Lenis. Statisch, schnell, ohne Tracking.

> `kleinteil` ist ein Arbeitstitel. Name, Preise, Produkte und Texte sind
> Platzhalter und an einer Stelle änderbar (siehe unten).

## Schnellstart

Voraussetzung: Node.js 22.12 oder neuer.

```bash
cd kit-shop
npm install
npm run dev        # http://localhost:4321
npm run build      # fertige Seite in dist/
npm run preview    # gebaute Seite lokal ansehen
```

## Wo was steht

| Datei | Inhalt |
| --- | --- |
| `src/data/site.ts` | Name, E-Mail, Versandkosten, Checkout-Modus |
| `src/data/kits.ts` | Bausätze, Preise (in Cent, inkl. MwSt.), Stückliste |
| `src/styles/global.css` | Farben, Schriften, Abstände (alles als Variablen oben) |
| `src/components/KumpelStage.astro` | Hero + Explosionsansicht + Stückliste |
| `src/scripts/kumpel3d.ts` | Das 3D-Modell (Maße in mm) |
| `src/scripts/stage.ts` | Scroll-Sequenz, Kamerafahrt, Positionsnummern |
| `src/scripts/eyes.ts` | Die OLED-Augen (128 × 64, Launen) |
| `src/components/*.astro` | Die übrigen Abschnitte |
| `src/pages/*.astro` | Seiten (Start, Rechtliches, Danke, 404) |
| `netlify/functions/checkout.mts` | Stripe-Checkout |

Farbe ändern: In `global.css` die Variable `--pink` anpassen. Das Pink kommt von
den Antistatik-Tüten, in denen die Bauteile stecken. Das Grün ist Lötstopplack.

## Bezahlen mit Stripe

Der Warenkorb läuft komplett im Browser. Für die Kasse gibt es eine kleine
Serverfunktion, die eine Stripe-Checkout-Session erstellt. Die Preise kommen
dabei aus `kits.ts` auf dem Server, nicht aus dem Browser.

1. Stripe-Konto anlegen, im Dashboard die Zahlarten aktivieren (Karte, PayPal, Klarna …).
2. Seite bei Netlify anlegen, **Base directory: `kit-shop`**.
3. Unter *Site configuration → Environment variables* `STRIPE_SECRET_KEY` setzen
   (zum Testen `sk_test_…`).
4. In `src/data/site.ts` `checkout.mode` auf `'stripe'` stellen, committen.
5. Testkauf mit der Testkarte `4242 4242 4242 4242`.

Bis dahin zeigt "Zur Kasse" einen Hinweis, dass die Kasse noch nicht angeschlossen ist.

## Vor dem Livegang

Ehrlich gesagt der wichtigere Teil. Ein Shop für Elektronik hat in Deutschland
einige Pflichten:

- [ ] **Rechtstexte** (Impressum, Datenschutz, AGB, Widerruf) von einem Anbieter
      holen, zum Beispiel Händlerbund, IT-Recht Kanzlei oder eRecht24. Die Seiten
      unter `src/pages/` enthalten nur Checklisten.
- [ ] **ElektroG / WEEE**: Registrierung bei der stiftung ear prüfen. Bausätze, aus
      denen ein funktionierendes Gerät entsteht, fallen sehr wahrscheinlich darunter.
- [ ] **Batterien (BattDG)**: Der Kumpel hat einen LiPo-Akku, dafür gibt es eine
      eigene Registrierungspflicht.
- [ ] **Verpackungen (VerpackG)**: Registrierung im LUCID-Register und Lizenzierung
      bei einem dualen System.
- [ ] **CE und Funk**: Der ESP32 funkt (WLAN, Bluetooth). Klär, welche
      Konformitätserklärung du als Hersteller eines Bausatzes brauchst.
- [ ] **Kein Spielzeug**: Bausätze als Lernmaterial ab 14 kennzeichnen. Für
      Kinderspielzeug gelten deutlich strengere Regeln.
- [ ] **Widerrufsfunktion**: Seit 19.06.2026 für Online-Verträge in der EU Pflicht.
- [ ] **Kleinunternehmer?** Dann statt "inkl. MwSt." den Hinweis nach § 19 UStG.
- [ ] Domain in `astro.config.mjs` (`site`) und E-Mail in `site.ts` eintragen.
- [ ] Newsletter-Formular an einen Dienst anbinden (siehe TODO in `src/scripts/home.ts`)
      oder entfernen.
- [ ] Texte prüfen: Versprechen wie "Fehlt etwas, schicken wir es kostenlos nach"
      oder "Flashen im Browser" musst du auch einlösen.
- [ ] Echte Fotos vom Bausatz ergänzen. Das 3D-Modell ist schön, Fotos verkaufen.

## Technik

- **Astro 7**, statische Ausgabe, ein bisschen TypeScript im Browser
- **three.js** für den Kumpel. Das Modell ist komplett im Code gebaut, ohne 3D-Dateien.
  Fällt WebGL aus, zeigt die Seite eine SVG-Illustration.
- **GSAP** (ScrollTrigger, SplitText) und **Lenis** für Scroll-Animationen
- Schriften (Archivo, Martian Mono) liegen lokal im Build. Kein Abruf bei Google,
  das spart Ärger mit der DSGVO.
- Wer im Betriebssystem "Bewegung reduzieren" eingestellt hat, bekommt eine ruhige
  Version ohne Scroll-Sequenz.
- `npx astro check` prüft die Typen.
