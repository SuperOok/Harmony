---
name: szenen
description: Arbeit an den Tierszenen und Animationen von Harmony (tools/szenen, docs/szenen.md): Landschaften, Eichhörnchen und weitere Tierfiguren, Kamera, Dunst, SVG-Animation, Szene je Tierkarte. Beim Gestalten, Ändern oder Erweitern der Szenen laden, nicht bei Engine, Regeln oder App-Logik.
---

# Tierszenen

Kleine Start- und Zwischenanimationen je Tierkarte, gezeichnet als SVG von
Python-Skripten. Noch nicht in der App. Die ausführliche Referenz ist
`docs/szenen.md`; dort stehen Grundsätze, jede Landschaft, die Animation und
was verworfen wurde. Erst dort nachlesen, dann ändern.

## Wo was liegt

- `tools/szenen/style.py`: alle Zahlen und Farben. Eine Zahl ändern → hier.
- `tools/szenen/landscapes.py`: eine Funktion je Landschaft. Eine Form ändern → hier.
- `tools/szenen/scene.py`: Plan, Tiefensortierung, Dunst, Himmel, Kamera.
- `tools/szenen/cards.py`: Szene einer Karte (Anordnung, Umgebung, drei Ausschnitte).
- `tools/szenen/figures.py`: Tierfiguren; `animate.py`: die Animation.
- `tools/szenen/stories.py` (mit `anim.py`, `figures_more.py`, `fig_bug.py`,
  `fig_bird.py`): Ente, Marienkäfer, Adler, Rabe als Animation, noch nicht
  in der App (`python3 tools/szenen/stories.py <Tier>`); Abschnitt *Vier
  weitere Tiere* in `docs/szenen.md`. SMIL zeigt `qlmanage` nicht: im
  Browser ansehen und mit `setCurrentTime` anspringen.

```bash
python3 tools/szenen/scene.py --feld korn      # Beispielszene
python3 tools/szenen/cards.py Eichhörnchen     # Szene einer Karte
python3 tools/szenen/animate.py                # Animation
```

Die Bilder landen in `tools/szenen/out/` (nicht eingecheckt).

## So wird gearbeitet

Hauke gestaltet über Bilder. Nach jeder Änderung neu erzeugen und das
Ergebnis verschicken: `SendUserFile` mit `display: render` zeigt ein SVG als
Vorschau, auch animiert. Standbilder entstehen mit `qlmanage -t -s 1000 -o
<Ordner> <datei>.svg`; das kann nur quadratisch und nur ohne SMIL. Ein
einzelner Wunsch pro Runde, dann zeigen, nicht mehrere Änderungen bündeln.

## Fallstricke

- **Keine SVG-Filter** (`feColorMatrix`, `feComposite`, …). WebKit zeichnet
  gefilterte Gruppen bei starkem Zoom nicht mehr oder sehr langsam; auf dem
  iPhone fehlten Teile und die Animation ruckelte. Dunst geht über
  Schleier in der Hintergrundfarbe zwischen den Reihen (`scene.py`).
- **Sechsecke mit flacher Oberseite**, wie auf dem Spielplan. Axiale
  Koordinaten (q, r); Tiefe einer Zelle ist `r + q/2` (`Board.depth`).
- **Die Szene entsteht aus dem Muster der Karte, nie aus der Kartengrafik.**
  Das Repo ist öffentlich; Bildaufbau, Posen und Perspektive der Karten
  dürfen nicht nachgestellt werden, Regeln und Motive schon.
- **Berg3 mindestens so hoch wie Baum3** (`MOUNTAIN_STONE_H`).
- **Nichts Hohes vor einem Tier.** Direkt vor den Würfelfeldern nur Wasser,
  Feld, Büsche.
- Die Animation endet auf dem Haus, der Landschaft des Würfels; die Kamera
  zoomt nur heraus, nie wieder herein.
- Iterativ schreibt sich schnell Zufall in die Umgebung: Startwert fest
  lassen (`seed`), sonst springt das Bild zwischen den Läufen.

## Offen

Animationen 2 und 3 je Karte (`cards.build(name, arrived=k)`), die übrigen
31 Tiere, Umgebung und Feldlesart je Tier, die Rechenzeit der Szene auf dem
Gerät. Stand und Reihenfolge stehen am Ende von `docs/szenen.md`.

## In der App

Die erste Animation läuft in der App (`MyApp/Szenen/`, vor „Über Harmony").
Die Szene geht als Anzeigeliste dorthin: nach **jeder** Änderung an Stil,
Landschaft oder Figur `python3 tools/szenen/export.py` laufen lassen, sonst
zeigt die App den alten Stand. Eine Änderung an `animate.py` ist in
`SquirrelTimeline.swift` nachzuziehen. Einzelheiten unter *In der App* in
`docs/szenen.md`.
