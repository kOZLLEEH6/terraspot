# Schriftlabor

Wandelt getippten Text in die eigene Handschrift um und liefert das Ergebnis als Bild,
das sich in OneNote einfügen lässt.

Eine einzelne HTML-Datei ohne Abhängigkeiten, ohne Server, ohne Installation.
Doppelklick auf `index.html` genügt. Nichts verlässt den Rechner: die erfasste
Handschrift liegt im `localStorage` des Browsers und in der Profildatei, die man
selbst sichert.

Hat mit der TerraSpot-App nichts zu tun, liegt hier nur mit im Repo.

## Handschrift erfassen

Zwei Wege, beide führen zum selben Datenmodell:

**Direkt schreiben** — jedes Zeichen einmal auf die Fläche malen, mit Stift, Finger
oder Maus. Vier Hilfslinien (Ober-, Mittel-, Grund-, Unterlinie) geben die Metrik vor.
Bei einem Stift mit Druckerkennung wird der Druck mitgespeichert, sonst leitet das
Tool die Strichstärke aus der Schreibgeschwindigkeit ab. Enter übernimmt und springt
zum nächsten fehlenden Zeichen, Backspace nimmt den letzten Strich zurück.

**Blatt scannen** — die Vorlage drucken (A4, ohne Skalierung), mit dem echten Stift
ausfüllen, abfotografieren, hochladen. Die vier Punkte auf die schwarzen Eckquadrate
ziehen, den Rest erledigt die perspektivische Entzerrung. Ergebnis wirkt echter als
gemalte Zeichen, weil es echte Tinte auf echtem Papier ist.

Mehrere Varianten pro Zeichen lohnen sich: das Rendering würfelt bei jedem Vorkommen
eine aus, was den Stempel-Effekt vermeidet. Zwei bis drei reichen.

## Was drin steckt

| Teil | Kern |
|---|---|
| Metrik | 1 em = Grundlinie bis Oberlinie, y wächst nach unten, Grundlinie bei y=0. Alle Glyphen sind auflösungsunabhängig in em gespeichert. |
| Strichzüge | Punktfolgen mit Druckwert, Chaikin-geglättet, segmentweise mit variabler Breite gezeichnet. |
| Scan | Homographie aus vier Punktpaaren (Gauß mit Pivotierung), bilineare Abtastung, adaptiver Schwellwert pro Zelle, Zusammenhangsanalyse gegen Sprenkel. |
| Rendering | Pro Glyphe ein zwischengespeichertes Offscreen-Canvas, platziert mit Versatz, Drehung, Skalierung und Grundlinien-Drift aus einem gesäten Zufallsgenerator. |
| Variation | Deterministisch über einen Seed, damit das Bild beim Reglerziehen ruhig bleibt und sich nur auf Knopfdruck neu würfelt. |

## Grenzen

* Das Ergebnis ist ein **Bild**. Handschrift ist nun mal Pixel, kein Text. In OneNote
  nicht durchsuchbar und nicht editierbar.
* Transparente PNGs überleben den Weg über die Windows-Zwischenablage oft nicht
  (Alphakanal geht verloren, Hintergrund wird schwarz). Deshalb ist Weiß voreingestellt.
  Für echte Transparenz die Datei herunterladen und in OneNote ziehen.
* Kopieren als Bild braucht Chrome oder Edge. Firefox kann die Clipboard-API nur
  eingeschränkt, dort funktioniert der Download.
* Wer in OneNote wirklich *tippen* statt Bilder einfügen will, braucht eine echte
  Schriftdatei. Calligraphr baut so eine TTF, dafür sieht dann jeder Buchstabe jedes
  Mal identisch aus.

## Profil sichern

Die Handschrift lebt im Browserspeicher. Aufgeräumte Websitedaten, anderer Browser oder
neuer Rechner heißt: weg. „Profil sichern“ legt eine JSON-Datei ab, die sich überall
wieder laden lässt.
