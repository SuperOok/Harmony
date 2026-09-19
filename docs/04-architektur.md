# Phase 4 — Daten und Architektur

Status: abgeschlossen, Stand 2026-09-19

Welche Entitäten, welche Persistenz, welches Suchverfahren. Geschnitten
gegen den Funktionsumfang aus Phase 3 und die Prüfbarkeit aus
`pruefverfahren.md`.

## Leitentscheidungen

| Frage | Entscheidung | Begründung |
| --- | --- | --- |
| Suchverfahren | Expectimax über die Beutelzüge | Der Beutelinhalt ist bekannt, also lassen sich Nachfüllungen mit ihren Wahrscheinlichkeiten aufzählen statt schätzen |
| Zufall | **Keiner.** Die Engine ist deterministisch | Erledigt den offenen Punkt 1 aus Phase 1 |
| Persistenz | Ereignisprotokoll, Zustand durch Wiedergabe | Die Rücknahme aus Störfall A braucht das Protokoll ohnehin |
| Kartendaten | JSON-Ressource, erzeugt aus `tierkarten.md` | Eine Quelle der Wahrheit bleibt das Markdown |
| Modulschnitt | Eigenes Swift-Paket `HarmonyEngine` | Stockwerk 1 verlangt Tests ohne Bau der App |

## Entitäten

### Stein, Zelle, Stapel

Ein **Stein** ist eine Farbe, sechs Werte, mehr nicht — `W S H L F Z` wie in
`pruefverfahren.md`.

Eine **Zelle** ist ein Platz auf einer Spielplanseite. Nach außen heißt sie
`<Spalte><Zeile>`, intern trägt sie Würfelkoordinaten (siehe Geometrie).

Ein **Stapel** ist eine geordnete Liste von Steinen, von unten nach oben,
Länge 0 bis 3. Genau die Brettnotation, nur als Datenstruktur.

### Landschaft wird abgeleitet, nicht gespeichert

Ein Tableau hält **Stapel, keine Landschaften**. Ob `SS` ein Berg der Höhe 2
ist, entscheidet eine Funktion, kein Feld im Datensatz.

Das ist dieselbe Entscheidung wie bei der Brettnotation und aus demselben
Grund: Wer die Landschaft speichert, hat die Einordnung schon vorgenommen und
kann sie nicht mehr prüfen. Gespeichert wird, was auf dem Tisch liegt;
abgeleitet wird, was es bedeutet.

Praktisch heißt das auch: Ein Zug, der einen Stein auf einen Berg legt,
muss die Landschaft nicht umschreiben. Sie war nie geschrieben.

### Tableau

Zelle → Stapel, dazu die Zellen mit einem Tierwürfel. Der Würfel gehört zu
einer Karte, also wird beides geführt: **welche Zelle besetzt ist** (für die
Legalität weiterer Züge) und **wie viele Würfel je Karte gelegt sind** (für
die Wertung). Beides aus einem abzuleiten geht nicht — ein Würfel bleibt
liegen, auch wenn sein Muster zerstört wird.

### Tierkarte

Name, Muster als Zuordnung Musterzelle → Landschaft, Zielzelle des Würfels,
Punktleiste. Das Muster steht in **einer** kanonischen Lage; die sechs
Drehungen erzeugt die Engine, wie `kartennotation.md` festlegt.

Die Karte nennt **Landschaften**, nicht Steine — `Berg1` verlangt genau einen
grauen Stein, `Gebäude` einen roten auf beliebigem Unterbau. Hier ist die
Abstraktion richtig, weil das Muster genau auf dieser Ebene definiert ist.

### Auslagen

Die Steinauslage ist eine **Mehrfachmenge aus fünf Tripeln**, jedes Tripel
selbst ungeordnet. Kein Array mit Plätzen: Die Felder tragen keine
Beschriftung, liegen im Kreis, und zwei gleiche Felder sind austauschbar.
Die Kartenauslage ist aus denselben Gründen eine Menge von fünf Karten.

### Beutelwissen

Nicht der Beutel, sondern was Harmony über ihn weiß: eine Anzahl je Farbe.
Sie ergibt sich aus 23/23/21/19/19/15 abzüglich alles Gesehenen — und
gesehen wurde alles, weil jede Nachfüllung erfasst wird. Für Expectimax ist
genau diese Verteilung die Wahrscheinlichkeitsquelle.

Dieses Wissen ist **vollständig, nicht geschätzt**. Steine verlassen den
Beutel ausschließlich über Nachfüllungen; was ein Mitspieler auf sein
Tableau legt, lag vorher in der Auslage und ist längst verbucht. Eine
Eingabe darüber, welche Steine die anderen genommen haben, brächte deshalb
nichts — sie steckt ohnehin darin, dass ein geleertes Feld über seinen
Inhalt benannt wird. Unbekannt bleibt allein, **wohin** sie damit gehen,
und das ist die Eingabe, die Phase 3 verworfen hat.

### Kartenstapelwissen

Dasselbe gilt für die Karten, und es ist bisher übersehen worden. Alle 32
sind in `tierkarten.md` katalogisiert, und jede Karte, die je offen lag,
ist erfasst. Der **verbliebene Stapel ist damit exakt bekannt** — nicht
seine Reihenfolge, aber seine Zusammensetzung.

Zwei Folgen. Für die eigene Planung weiß Harmony, welche Karte noch
auftauchen kann und welche endgültig weg ist. Und für die Suche ist das
Nachrücken einer Karte eine **zweite Zufallsschicht**, die sich genauso
aufzählen lässt wie die Nachfüllung aus dem Beutel.

### Was Harmony nicht hält

Keine fremden Tableaus, keine fremden Tierwürfel. Nur, welche Karte wer
genommen hat, und ein Merker „jemand ist fast fertig". So entschieden in
Phase 3.

## Geometrie

Flat-top-Sechsecke in Spalten, gerade Spalten eine halbe Zelle tiefer.
Intern **Würfelkoordinaten**: Nachbarschaft ist dann eine Addition und eine
Drehung eine Rotation der drei Achsen. `tools/pruefe-tierkarten.py` rechnet
heute schon so, um Musterformen zu vergleichen.

Beide Spielplanseiten sind **Daten**, nicht Code: eine Liste von Zellen,
23 auf Seite A, 25 auf Seite B. Die Wasserwertung unterscheidet sich
(Fluss gegen Inseln) und hängt deshalb an der Seite, nicht an der Geometrie.

Die Nummerierung `<Spalte><Zeile>` ist eine **Anzeigeform**. Intern wird
gerechnet, nach außen übersetzt.

## Suche

### Ein Zug, dann der Zufall

Aufgezählt werden alle eigenen Züge vollständig: fünf Auslagenfelder, die
Platzierungen der drei Steine, das Nehmen einer Karte, das Setzen von
Tierwürfeln. Darunter hängt eine **Zufallsschicht**: die Nachfüllung des
geleerten Feldes, aufgezählt über die Farbverteilung des Beutels, jede
Möglichkeit mit ihrer Wahrscheinlichkeit gewichtet. Wurde eine Karte
genommen, rückt außerdem eine nach — ebenfalls aufzählbar, weil der
verbliebene Stapel bekannt ist.

### Der Zufall hat zwei Quellen, und nur eine ist bekannt

Der **Beutel** ist berechenbar — das ist der Grund für Expectimax statt
Stichproben.

Die **Mitspieler** sind es nicht. Zwischen zwei Harmony-Zügen ziehen zwei
Menschen, und welches Feld sie nehmen, folgt keiner Verteilung, die wir
kennen. Für v1 wird ihre Wahl als gleichverteilt angenommen. Das ist
erklärtermaßen eine Annahme und keine Messung; ob eine pessimistische
Annahme besser spielt, gehört gemessen, sobald Selbstspiel läuft.

### Was die Verzweigung erzwingt

Eine grobe Schätzung: fünf Felder, je drei Steine auf bis zu 25 Zellen,
dazu Kartennahme und Würfel — Größenordnung 10⁴ bis 10⁵ eigene Züge pro
Stellung. Mal einer Zufallsschicht über die möglichen Nachfüllungen, mal
zwei unbekannten fremden Zügen, mal dem nächsten eigenen Zug: Ein zweiter
eigener Zug ist damit **nicht bezahlbar**.

v1 sucht deshalb **einen eigenen Zug tief, mit einer Zufallsschicht
darunter**, und bewertet dann. Die Zahlen oben sind geschätzt; der
Durchstich muss sie messen. Ergibt die Messung Luft, ist die nächste Stufe
eine Zusammenfassung der Zufallsschicht — nicht jede mögliche Nachfüllung
einzeln, sondern die erwartete Verfügbarkeit je Farbe.

### Das Vorausrechnen fällt heraus

Phase 2 verlangt, dass Harmony rechnet, während der Vordermann überlegt.
Mit Expectimax ist das kein Zusatz, sondern dieselbe Rechnung: Vier der
fünf Felder überstehen den fremden Zug unverändert, ihre Teilbäume bleiben
gültig. Welches Feld der Mitspieler nimmt, ist die Zufallsschicht, die
ohnehin gerechnet wird — die Eingabe löst sie nur auf.

## Bewertung

Getrennt von der Suche, in eigenen Dateien. Das ist keine Ordnungsfrage:
Phase 3 nimmt v1 auf dem **Durchlauf** ab, nicht auf der Spielstärke, und
verlässt sich darauf, dass die Bewertung danach verbessert werden kann,
ohne etwas umzubauen.

Jeder Term trägt einen Namen und liefert eine Zahl. Was in die Begründung
kommt, sind die größten Beiträge — deshalb dürfen es keine namenlosen
Summanden sein.

Aus `ideen-vorgemerkt.md` gehören mindestens hinein:

- **Zuwachs des nächsten Tierwürfels**, nicht die Kartensumme. Karten sind
  über ihre Gesamtpunktzahl nicht vergleichbar.
- **Schwierigkeit eines Musters**, berechnet aus Steinzahl, Farbknappheit
  und Stapelzwang — nicht aus der Steinzahl allein.
- **Landschaftswertung**, die allein aber nicht reicht: Das Erdmännchen
  belohnt einen einzelnen Berg, der als Landschaft 0 zählt.
- **Restlaufzeit**, aus dem Zugzähler. Lachs und Frosch unterscheiden sich
  nur in der Geschwindigkeit; welcher besser ist, hängt daran.

Musterinstanzen werden **vorgehalten**, nicht bei jeder Bewertung neu
gesucht: Muster überlappen, ein Stein kann mehreren Karten dienen, und ein
einzelner Stein entscheidet manchmal, welche von zwei Karten bedient wird.

## Persistenz

Gespeichert wird eine **Folge von Ereignissen**, der Zustand entsteht durch
Nachspielen. Ereignisse sind: Aufbau, fremder Zug, Harmonys bestätigter Zug,
Korrektur am eigenen Tableau (Störfall B), Endemeldung.

Drei Anforderungen fallen damit zusammen:

- **Rücknahme** (Störfall A) ist das Weglassen des letzten Ereignisses und
  erneutes Abspielen.
- **Überleben des Hintergrundwechsels** ist das Schreiben nach jedem
  Ereignis. Mehr verlangt Phase 2 nicht; eine Partie über Tage ist
  ausdrücklich kein Szenario.
- **Testfälle** entstehen durch Ablegen derselben Datei, siehe
  `pruefverfahren.md`.

Eine Genauigkeit: Harmonys Zug steht **als Ereignis** im Protokoll, nicht
als Auftrag, ihn neu zu berechnen. Die Wiedergabe braucht die Engine also
nicht und bleibt auch dann gültig, wenn sich die Bewertung ändert.
Deterministisch muss die Engine trotzdem sein — das verlangen die
Momentaufnahmen, nicht die Wiedergabe.

## Kartendaten

`tierkarten.md` bleibt die **Quelle der Wahrheit**. Ein Werkzeug neben
`tools/pruefe-tierkarten.py` erzeugt daraus eine JSON-Datei, die
eingecheckt wird und als Ressource **im Paket** liegt — nicht im App-Bundle,
sonst kämen die Engine-Tests nicht ohne die App an sie heran.

Der bekannte Nachteil von JSON ist, dass Fehler erst zur Laufzeit auffallen.
Dagegen steht ein Test in Stockwerk 1, der die Datei lädt und prüft: 32
Karten, bekannte Landschaften, zusammenhängende Muster, Würfelzelle im
Muster, streng steigende Punktleisten, eindeutige Namen. Dieselben
Bedingungen prüft das Python-Werkzeug heute schon auf dem Markdown — die
beiden Prüfungen sind bewusst getrennt implementiert und damit eine
unabhängige Nachrechnung im Sinne des Prüfverfahrens.

Was **nicht** in die Daten gehört, hält Phase 1 fest: keine
Kartenillustrationen, keine wörtlichen Regeltexte. Muster, Punktleisten und
unsere eigenen Namen sind unbedenklich.

## Modulschnitt

```
HarmonyEngine/            eigenes Swift-Paket
  Package.swift
  Sources/HarmonyEngine/  Regeln, Wertung, Suche, Kartendaten
  Tests/                  Stockwerk 1 und später 2
Harmony.xcodeproj         die App, bindet das Paket ein
MyApp/                    Ansichten
```

Das Paket kennt **kein SwiftUI**. Die Trennung wird damit vom Übersetzer
erzwungen und nicht von der Disziplin: Engine-Code, der auf eine Ansicht
zugreift, übersetzt nicht.

`swift test` im Paketordner prüft die Engine, ohne die App zu bauen — keine
Ansichten, keine Assets, keine Signierung. Genau das verlangt Stockwerk 1
vom Fundament.

## Nicht gewählt, weil

- **Monte-Carlo** — trägt bei tiefer Suche am weitesten, ist aber
  verrauscht. Der Abstand zum zweitbesten Zug aus Störfall C schwankte dann
  von Lauf zu Lauf, und die Momentaufnahmen aus dem Prüfverfahren wären
  wertlos. Der Beutel ist außerdem berechenbar — Stichproben zu ziehen, wo
  man abzählen kann, ist ein Rückschritt.
- **Zwei eigene Züge tief** — zwischen ihnen liegen eine Zufallsschicht und
  zwei unbekannte fremde Züge. Die Verzweigung trägt das nicht, und die
  Unsicherheit macht den zweiten Zug ohnehin wenig aussagekräftig.
- **Landschaften im Tableau speichern** — nimmt die Einordnung vorweg, die
  geprüft werden soll, und muss bei jedem Zug nachgeführt werden.
- **Ein Array für die Steinauslage** — erfindet eine Ordnung, die es am
  Tisch nicht gibt, und macht die Eingabe von der Reihenfolge abhängig.
- **Zustandsabbild statt Protokoll** — der Verlauf für die Rücknahme müsste
  trotzdem geführt werden; das Protokoll leistet beides.
- **Kartendaten von Hand in Swift** — zwei Stände, die auseinanderlaufen.
- **Engine im App-Target** — bindet jede Prüfung einer Wertungsfunktion an
  den Bau der ganzen App.

## Offene Punkte

1. **Wie wählen die Mitspieler?** Gleichverteilung ist eine Annahme und die
   schwächste Stelle der Suche. Zwei Verbesserungen kosten **keine**
   zusätzliche Eingabe: Harmony weiß bereits, welche Tierkarten jeder
   genommen hat (Phase 3) und welche Steine jeder je bekommen hat — ein
   geleertes Feld wird ja über seinen Inhalt benannt. Aus den Karten eines
   Mitspielers folgt eine Farbnachfrage — wer den Pinguin hält, braucht
   Blau und Grau —, und ein Feld mit diesen Farben reizt ihn mehr als eines
   ohne.

   Drei Grenzen gehören dazu: Harmony weiß nicht, wie viele Würfel schon
   auf einer fremden Karte liegen, kann also eine frische nicht von einer
   fast fertigen unterscheiden — die Nachfrage besteht allerdings fort,
   weil eine Karte ihr Muster einmal je Würfel verlangt, also zwei- bis
   fünfmal. Sie weiß nicht, ob die Farbe auf dem fremden Tableau überhaupt
   unterkommt. Und sie sieht die Landschaftswertung nicht, die ebenfalls
   Farben zieht.

   Deshalb mildes Gewicht, mit der Gleichverteilung gemischt: Ein
   selbstsicher falsches Gegnermodell ist schlechter als gar keins. Die
   Alternative bleibt eine pessimistische Annahme. Was stärker spielt,
   entscheidet das Selbstspiel, nicht dieses Dokument.
2. **Trägt die Verzweigung wirklich?** Die Schätzung 10⁴ bis 10⁵ ist nicht
   gemessen. Fällt sie höher aus, wird zuerst die Zufallsschicht
   zusammengefasst, bevor an der Bewertung gespart wird.
3. **Zeitbudget der Vorausrechnung.** Phase 2 will, dass in fremder Denkzeit
   gerechnet wird. Wie lange das dauern darf und woran die Suche abbricht,
   ist erst am laufenden Stand zu entscheiden.
4. **Wie viele Musterinstanzen lohnt es vorzuhalten?** Alle gefundenen, oder
   nur die fast fertigen? Eine Messfrage.
