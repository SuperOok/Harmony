# Wie gut sind die Tierkarten?

Festgehalten am 2026-10-04, nachdem alle 32 Karten gegen die physischen Karten
geprüft waren (`kartennotation.md`, *Stand der Prüfung*). Die Frage: Sind die
Verhältnisse von Steinen, Würfeln, Landschaftspunkten im Muster und erreichbaren
Punkten bei allen Karten gleich, oder gibt es bessere und schlechtere?

**Antwort: Sie sind nicht gleich, aber weniger ungleich, als es zuerst aussah,
und welche Karte vorn liegt, hängt davon ab, was man als knapp ansieht.**

## Erster Anlauf: Punkte je Stein **eines** Habitats — zu grob

Die erste Rechnung teilte die Höchstpunktzahl durch die Steine **eines**
Habitats. Sie sah eine Spanne von 1,8 bis 8,5 Punkten je Stein und hielt
Marienkäfer, Frosch und Erdmännchen für die mit Abstand besten Karten. Das
war falsch gerechnet: Eine Karte braucht so viele Habitate wie Würfel, und
jedes Habitat braucht seine **eigene** Zelle für den Würfel. Fünf Würfel beim
Marienkäfer sind fünf Felder, nicht eines.

## Zweiter Anlauf: das Großhabitat aller Würfel

`HarmonyCardCost` (`swift run -c release HarmonyCardCost`, ein paar Sekunden)
sucht für jede Karte das **Großhabitat**: die geringste Zahl von Steinen, die
alle Habitate der Karte zusammen tragen, und zwar genau, nicht geschätzt. Aus
allen Lagen des Musters auf dem Spielplan (sechs Drehungen, jede Position; die
Lagen kommen aus `Habitat.all`) wird jede Auswahl so vieler Habitate geprüft,
wie die Karte Würfel hat, mit den Regeln:

- Jedes Habitat hat eine eigene Würfelzelle; zwei Würfel teilen sich keine.
- Zwei Habitate dürfen sich eine Zelle teilen, wenn sie dort dasselbe
  verlangen (gleiche Landschaft, gleiche Höhe).
- **Überbauen**: Ein Stapel darf zwischen zwei Habitaten wachsen, solange noch
  kein Würfel darauf liegt (`Berg1`, später `Berg2`, `Berg3` oder ein Gebäude
  darauf). Die Zelle eines Würfels wächst nie mehr, und die Reihenfolge der
  Habitate darf sich nicht im Kreis drehen.

Gezählt wird für das Großhabitat:

- **Steine gesamt:** das, was die Suche kleinstmöglich macht.
- **Felder:** die Zellen des Spielplans, die es besetzt; unter den Anordnungen
  mit den wenigsten Steinen die mit den wenigsten Feldern.
- **Würfelfelder:** Zellen mit Würfel. Auf jedem Stein liegt höchstens einer, und
  der Stapel darunter wächst nie mehr.
- **Eingefroren:** Würfelfelder auf `Berg1` oder `Berg2`, die zu etwas Wertvollerem
  hätten wachsen können (`Berg3` zählt 7 Landschaftspunkte, `Berg1` einen).
- **Landschaft:** was die Steine der Anordnung auf Seite A von allein einbringen
  (Bäume, Berge mit Nachbar, Feldgruppen, Gebäude, Fluss); von den billigsten
  Anordnungen die beste.
- **Auslastung:** der Mittelwert aus zwei Anteilen, den Steinen der Karte an den
  rund 30, die eine Partie legt, und ihren Feldern an den rund 21, die am Ende
  belegt sind (Harmony, Seite A, zu zweit: 29,8 Steine, 21,4 Felder). Beides
  sind Annahmen aus Partien, keine Regeln.

Die Tabelle ist die Ausgabe des Werkzeugs, nach Punkten je Stein sortiert,
beste zuerst:

| Karte | Würfel | Steine je Habitat | Steine gesamt | Felder | Würfelfelder | eingefroren | Höchstpunkte | Landschaft | Punkte je Stein | (Punkte + Landschaft) je Stein | (Punkte + Landschaft) je Feld | Auslastung | (Punkte + Landschaft) je 10 % Auslastung |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Marienkäfer | 5 | 2 | 6 | 6 | 5 | 0 | 17 | 6 | 2.83 | 3.83 | 3.83 | 24.29 % | 9.47 |
| Erdmännchen | 4 | 2 | 5 | 5 | 4 | 4 | 14 | 4 | 2.80 | 3.60 | 3.60 | 20.24 % | 8.89 |
| Flamingo | 3 | 3 | 6 | 6 | 3 | 0 | 16 | 7 | 2.67 | 3.83 | 3.83 | 24.29 % | 9.47 |
| Otter | 3 | 3 | 6 | 6 | 3 | 0 | 16 | 5 | 2.67 | 3.50 | 3.50 | 24.29 % | 8.65 |
| Pinguin | 3 | 3 | 6 | 6 | 3 | 3 | 16 | 3 | 2.67 | 3.17 | 3.17 | 24.29 % | 7.82 |
| Rochen | 3 | 3 | 6 | 6 | 3 | 0 | 16 | 5 | 2.67 | 3.50 | 3.50 | 24.29 % | 8.65 |
| Wüstenfuchs | 3 | 3 | 6 | 6 | 3 | 3 | 16 | 8 | 2.67 | 4.00 | 4.00 | 24.29 % | 9.88 |
| Frosch | 5 | 2 | 6 | 6 | 5 | 0 | 15 | 12 | 2.50 | 4.50 | 4.50 | 24.29 % | 11.12 |
| Fledermaus | 4 | 4 | 7 | 5 | 4 | 4 | 16 | 11 | 2.29 | 3.86 | 5.40 | 23.57 % | 11.45 |
| Lachs | 4 | 4 | 7 | 5 | 4 | 0 | 16 | 8 | 2.29 | 3.43 | 4.80 | 23.57 % | 10.18 |
| Biene | 2 | 5 | 8 | 6 | 2 | 0 | 18 | 11 | 2.25 | 3.62 | 4.83 | 27.62 % | 10.50 |
| Ente | 4 | 3 | 6 | 5 | 4 | 0 | 13 | 8 | 2.17 | 3.50 | 4.20 | 21.90 % | 9.59 |
| Hase | 3 | 4 | 8 | 6 | 3 | 0 | 17 | 4 | 2.12 | 2.62 | 3.50 | 27.62 % | 7.60 |
| Lama | 2 | 4 | 6 | 4 | 2 | 0 | 12 | 5 | 2.00 | 2.83 | 4.25 | 19.52 % | 8.71 |
| Waschbär | 2 | 4 | 6 | 6 | 2 | 0 | 12 | 8 | 2.00 | 3.33 | 3.33 | 24.29 % | 8.24 |
| Eisfuchs | 3 | 5 | 9 | 6 | 3 | 0 | 17 | 14 | 1.89 | 3.44 | 5.17 | 29.29 % | 10.59 |
| Maus | 3 | 4 | 9 | 6 | 3 | 0 | 17 | 0 | 1.89 | 1.89 | 2.83 | 29.29 % | 5.80 |
| Pfau | 3 | 4 | 9 | 6 | 3 | 0 | 17 | 0 | 1.89 | 1.89 | 2.83 | 29.29 % | 5.80 |
| Affe | 2 | 4 | 6 | 4 | 2 | 2 | 11 | 2 | 1.83 | 2.17 | 3.25 | 19.52 % | 6.66 |
| Bär | 2 | 5 | 6 | 4 | 2 | 0 | 11 | 8 | 1.83 | 3.17 | 4.75 | 19.52 % | 9.73 |
| Panther | 2 | 5 | 6 | 4 | 2 | 0 | 11 | 6 | 1.83 | 2.83 | 4.25 | 19.52 % | 8.71 |
| Echse | 3 | 4 | 9 | 6 | 3 | 0 | 16 | 5 | 1.78 | 2.33 | 3.50 | 29.29 % | 7.17 |
| Eichhörnchen | 3 | 5 | 9 | 4 | 3 | 0 | 15 | 7 | 1.67 | 2.44 | 5.50 | 24.52 % | 8.97 |
| Koala | 4 | 3 | 9 | 5 | 4 | 0 | 15 | 13 | 1.67 | 3.11 | 5.60 | 26.90 % | 10.41 |
| Krokodil | 3 | 5 | 9 | 7 | 3 | 0 | 15 | 18 | 1.67 | 3.67 | 4.71 | 31.67 % | 10.42 |
| Schwein | 3 | 4 | 8 | 4 | 3 | 0 | 13 | 9 | 1.62 | 2.75 | 5.50 | 22.86 % | 9.62 |
| Adler | 2 | 4 | 7 | 3 | 2 | 0 | 11 | 14 | 1.57 | 3.57 | 8.33 | 18.81 % | 13.29 |
| Papagei | 3 | 4 | 9 | 6 | 3 | 0 | 14 | 14 | 1.56 | 3.11 | 4.67 | 29.29 % | 9.56 |
| Eisvogel | 3 | 5 | 12 | 6 | 3 | 0 | 18 | 21 | 1.50 | 3.25 | 6.50 | 34.29 % | 11.38 |
| Igel | 2 | 6 | 8 | 4 | 2 | 0 | 12 | 6 | 1.50 | 2.25 | 4.50 | 22.86 % | 7.88 |
| Rabe | 2 | 5 | 6 | 4 | 2 | 0 | 9 | 5 | 1.50 | 2.33 | 3.50 | 19.52 % | 7.17 |
| Wolf | 3 | 5 | 12 | 6 | 3 | 0 | 16 | 26 | 1.33 | 3.50 | 7.00 | 34.29 % | 12.25 |

Punkte je Stein: 1.33 bis 2.83, Median 1.89. Mit Landschaft: 1.89 bis 4.50, Median 3.33. Je Feld, mit Landschaft: 2.83 bis 8.33, Median 4.25.
Seite A und B, fest und überbaut ergeben bei allen Karten dieselbe Steinzahl.

## Was die Tabelle zeigt

- **Die Spanne ist kleiner:** 1,33 bis 2,83 Punkte je Stein statt 1,8 bis 8,5.
  Die Billig-Karten verlieren am meisten: Marienkäfer fällt von 8,5 auf 2,8,
  Frosch von 7,5 auf 2,5, Erdmännchen von 7,0 auf 2,8.
- **Seite A und B machen keinen Unterschied**, und **Überbauen spart bei keiner
  Karte einen Stein**: Eine Zelle kann nur dann erst niedrig und später höher
  gebraucht werden, wenn ein Muster `Berg1` und zugleich `Berg2`, `Berg3` oder
  ein Gebäude enthält; keine Karte tut das. Zwischen verschiedenen Karten wäre
  das anders; das ist nicht gerechnet.

## Fläche und blockierte Felder: gleicht das den Marienkäfer aus?

Der Einwand: Marienkäfer und Biene tragen fast gleich viele Punkte (17 und 18),
der Marienkäfer braucht weniger Steine (6 statt 8), besetzt aber ebenfalls sechs
Felder, davon fünf mit Würfel statt zwei, und trägt weniger Landschaftspunkte.

Das stimmt, und es gleicht den Vorsprung weitgehend aus:

| | Marienkäfer | Biene |
| --- | --- | --- |
| Steine / Felder | 6 / 6 | 8 / 6 |
| Würfelfelder | 5 von 6 | 2 von 6 |
| Landschaft im Gebilde | 6 | 11 |
| (Punkte + Landschaft) je Stein | 3,83 | 3,62 |
| (Punkte + Landschaft) je Feld | 3,83 | 4,83 |
| (Punkte + Landschaft) je 10 % Auslastung | 9,5 | 10,5 |

- **Je Stein** bleibt der Marienkäfer um 6 % vorn, **je Feld** liegt die Biene um
  26 % vorn, **je Auslastung** die Biene um 11 %.
- **Die Rangfolge hängt am Maßstab.** Der Marienkäfer ist beim Punkten je Stein
  (ohne Landschaft) die Nummer 1, mit Landschaft die Nummer 4, je Feld die Nummer
  20 von 32, nach Auslastung die Nummer 16. Die Biene liegt dort auf 11, 7, 9 und 7.
- **Nach Auslastung (Steine und Felder zusammen) vorn:** Adler (13,3), Wolf (12,3),
  Fledermaus (11,5), Eisvogel (11,4), Frosch (11,1). **Hinten:** Maus und Pfau (je
  5,8, null Landschaft), Affe (6,7), Rabe und Echse (je 7,2). Der Marienkäfer
  steht bei 9,5, mitten im Feld.
- **Eingefroren** sind die Würfelfelder auf Bergen: Erdmännchen 4, Fledermaus 4,
  Pinguin 3, Wüstenfuchs 3, Affe 2. Dort kostet der Würfel Wachstum.

**Wie viel „blockiert" wirklich kostet,** zeigt diese Rechnung nur grob: Ein Würfel
auf Feld, Baum, Wasser oder Gebäude friert nichts ein, weil diese Stapel ohnehin
nicht weiterwachsen; er sperrt nur, dass dort ein zweiter Würfel liegt. Eine
Partie legt im Standard rund neun Würfel auf rund 21 belegte Felder, Würfelplätze
sind im Mittel also nicht knapp. Knapp werden sie bei Farben, die mehrere Karten
als Würfelziel brauchen (Feld bei Eisfuchs, Lama, Marienkäfer, Panther, Rabe und
Waschbär). Das zu
bewerten, braucht Spieldaten, nicht diese Rechnung; dafür gibt es die
Karten-Statistik in `HarmonyMatch`.

## Wo die Rechnung zu grob bleibt

- **Sie zählt Steine, nicht Züge.** Pro Zug kommen drei Steine; ob sie dorthin
  passen, wo das Gebilde wächst, hängt vom Beutel ab.
- **Sie sieht eine Karte allein.** Mehrere Karten teilen sich Steine und Felder
  (Baum3 für Wolf, Eichhörnchen und Eisvogel zugleich); das drückt den Preis der
  zweiten und dritten Karte unter den hier genannten.
- **Das Mischungsverhältnis der Auslastung (30 Steine, 21 Felder) ist
  angenommen.** Wer Steine für knapper hält als Felder, gewichtet anders.
- **Farbknappheit** (Rot hat nur 15 Steine, Gelb und Grün je 19) und die
  Bedingung der Gebäude (drei Farben ringsum) sind nicht eingerechnet.
- **Die Landschaftspunkte der Anordnung** hängen an Seite A; auf Seite B
  zählen Inseln statt Fluss.

## Offen

Die Engine kennt einen einheitlichen Preis für freie Kartenplätze
(`[10, 6, 2,5, 0]`), keinen nach Güte der Karte. Ob sie gute Karten bevorzugt
und schlechte meidet, misst der Block *Karten* in `HarmonyMatch`: je Karte,
wie oft sie auslag, genommen und fertig wurde und was sie eingebracht hat.
Ergebnisse stehen in `docs/ideen-vorgemerkt.md`.
