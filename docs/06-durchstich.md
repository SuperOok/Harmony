# Phase 6 — Durchstich

Status: begonnen am 2026-09-20.

Die Kernfrage dieser Phase steht in `00-methodik.md`: **Funktioniert die
Kette von der Kartennotation bis zum Zugvorschlag?** Vor ihr lagen nur die
beiden Enden — 32 erfasste Karten vorne, ein ausgedachter Zug im Klickdummy
hinten. Dazwischen entsteht jetzt die Engine.

## Leitentscheidungen

| Frage | Entscheidung | Begründung |
| --- | --- | --- |
| Modulschnitt | Zweites Target `HarmonyEngine` im Paket `HarmonyRules` | Die Trennung erzwingt der Übersetzer, aber ein Testlauf genügt |
| Suchtiefe | Ein eigener Zug, darunter die Zufallsschicht | Wie in `04-architektur.md` gerechnet |
| Kartendaten | `animals.json` ist die Quelle, von Hand gepflegt | Ein Format statt zweier; siehe unten |
| App-Anbindung | Eigener Schritt danach | Der Durchstich endet beim Zugvorschlag, prüfbar ohne Simulator |

## Die Kartendaten sind umgezogen

`docs/tierkarten.md` ist entfallen. An seine Stelle tritt
`HarmonyRules/Sources/HarmonyRules/Resources/animals.json` — eingecheckt, von
Hand gepflegt, eine Zeile je Karte.

`04-architektur.md` sah die JSON-Datei ursprünglich als **Erzeugnis** des
Markdowns vor, mit einem Werkzeug dazwischen. Das ist umgedreht worden, weil
der Umweg nichts trug: Die Ablageform in `tierkarten.md` enthielt neben den
32 Blöcken vor allem Prosa, die beim Erfassen half und danach niemanden mehr
erreichte. Eine Zeile JSON je Karte ist ebenso lesbar und spart ein Format,
ein Werkzeug und die Gelegenheit, dass beide auseinanderlaufen.

Der Umzug lief über einen Gleichheitsabgleich: beide Formen eingelesen, auf
Übereinstimmung geprüft, erst dann gelöscht. Ohne ihn wäre das Löschen eine
Wette gewesen.

**Was das kostet.** `04-architektur.md` begründet die Doppelprüfung damit,
dass Python und Swift dieselben Bedingungen getrennt implementieren und so
unabhängig nachrechnen. Das gilt weiter — aber beide lesen jetzt **dieselbe
Datei**, während vorher die eine das Markdown und die andere das daraus
erzeugte JSON prüfte. Ein Tippfehler in der Quelle fällt damit nur auf, wenn
er eine der geprüften Bedingungen verletzt.

Die Gegenwehr ist die Formklassen-Zusicherung im nächsten Abschnitt: Sie ist
der einzige Sollwert auf den Kartendaten, der nicht aus ihnen selbst stammt.

## Fünf Formen, und was daraus folgt

Über alle 32 Karten treten nur **fünf** Musterformen auf. Der Befund stammt
aus der Erfassung, ist am Spielmaterial entstanden und wird hier als
Sollwert geführt:

| Zellen | Form | Anzahl | Karten |
| --- | --- | --- | --- |
| `11,12` | zwei benachbarte Zellen | 10 | Erdmännchen, Frosch, Marienkäfer, Koala, Ente, Lachs, Fledermaus, Schwein, Adler, Eichhörnchen |
| `11,12,13` | Dreierkette | 7 | Wüstenfuchs, Otter, Hase, Echse, Lama, Panther, Krokodil |
| `11,12,21` | Dreieck aus drei paarweise benachbarten Zellen | 7 | Rochen, Flamingo, Affe, Papagei, Bär, Wolf, Igel |
| `12,21,32` | Mitte mit zwei Nachbarn unten links und unten rechts | 6 | Pinguin, Eisfuchs, Pfau, Maus, Eisvogel, Rabe |
| `12,21,22,32` | Mitte mit drei Nachbarn darunter | 2 | Waschbär, Biene |

**Die Mustersuche muss nur fünf Formen kennen.** Die Vielfalt steckt in der
Füllung, nicht in der Geometrie. Da Musterinstanzen sich überlappen dürfen,
kann ein einzelner Spielstein gleichzeitig über mehrere Karten entscheiden —
die sechs Karten der Form `12,21,32` etwa unterscheiden sich nur in der
Füllung derselben drei Zellen.

**Die Lage des Zielsteins folgt der Form, aber sie folgt nicht aus ihr.**
Beim Umzug der Kartendaten ist der Satz nachgerechnet worden, und in seiner
ursprünglichen Fassung — „der Würfel liegt auf der Zelle, die alle anderen
berührt" — trägt er nicht:

| Form | Zellen, die alle anderen berühren | Würfel liegt auf |
| --- | --- | --- |
| `11,12` | beide | der zweiten |
| `11,12,13` | die Mitte | einem **Ende** |
| `11,12,21` | alle drei | einer davon |
| `12,21,32` | genau eine | ebendieser |
| `12,21,22,32` | zwei | einer der beiden |

Nur bei `12,21,32` bestimmt die Form die Zelle. Bei `11,12` und beim Dreieck
`11,12,21` sind die in Frage kommenden Zellen durch Drehung ineinander
überführbar, die Wahl ist also gegenstandslos. Bei der Dreierkette liegt der
Würfel ausnahmslos an einem **Ende**, nie in der Mitte — das Gegenteil der
ursprünglichen Fassung. Und bei `12,21,22,32` kommen zwei Zellen in Frage,
die **nicht** durch Drehung auseinander hervorgehen, sondern durch
Spiegelung; gespiegelte Lagen sind laut `kartennotation.md` nicht vorgesehen.
Dass beide Karten dieser Form denselben Platz wählen, ist eine Eigenschaft
der Daten und keine der Geometrie.

Für die Engine heißt das: **Die Würfelzelle wird gelesen, nicht hergeleitet.**
Zugesichert wird nur, was trägt — bei der Kette das Ende, sonst eine Zelle,
die jede andere des Musters berührt.

**Als Prüfung:** Ein Test gruppiert alle 32 Karten nach ihrer kanonischen
Form — über die sechs Drehungen normalisiert — und sichert genau diese
Aufteilung zu. Der Sollwert stammt aus einem von Hand bestätigten Befund und
nicht aus einem Programmlauf, wie `00-methodik.md` es verlangt. Schlägt der
Test an, ist entweder die Geometrie falsch oder eine Karte falsch erfasst;
beides will man wissen.

## Verzweigung

`04-architektur.md` schätzt 10⁴ bis 10⁵ eigene Züge je Stellung und hält
fest, dass der Durchstich das nachzumessen hat. Die Messung ist am
2026-09-20 **vorgezogen** worden, vor Bewertung und Suche: Fällt die Zahl
anders aus als geschätzt, ändert das den Zuschnitt beider, und das ist vor
dem Bauen billiger zu erfahren als danach. Gezählt wird mit
`tools/messe-verzweigung.sh`.

Gezählt werden **verschiedene Endstellungen, nicht Reihenfolgen**: Grau vor
Braun auf zwei Felder ergibt denselben Tisch wie Braun vor Grau, und zwei
Züge daraus zu machen wäre gelogen.

Seite A, 23 Felder:

| belegte Felder | Steinzüge | × Kartenwahl | × Zufallsschicht |
| --- | --- | --- | --- |
| 0 | 38.709 | 232.254 | 13.006.224 |
| 6 | 18.329 | 109.974 | 6.158.544 |
| 12 | 6.789 | 40.734 | 2.281.104 |
| 18 | 1.551 | 9.306 | 521.136 |

Seite B liegt durchweg etwa ein Drittel höher, sie hat zwei Felder mehr:
50.100 Steinzüge auf dem leeren Brett, 16,8 Millionen mit Zufallsschicht.

**Die Schätzung trägt, aber nur für den Steinteil.** 38.000 bis 50.000 eigene
Steinzüge liegen im geschätzten Band. Die Kartenwahl multipliziert das mit
sechs — fünf offene Karten oder keine —, und damit steht der Zugraum bei
2 bis 3 · 10⁵, also am oberen Rand der Schätzung. Das Setzen der Tierwürfel
und das Nachrücken einer Karte fehlen darin noch.

**Die Zufallsschicht ist so nicht bezahlbar.** 56 mögliche Nachfüllungen je
Zug bringen den leeren Spielplan auf 13 Millionen Blätter. Selbst bei
10 Mikrosekunden je Bewertung wären das gut zwei Minuten — und eine
Bewertung, die Anwärter samt ihrer Verträglichkeit prüft, ist teurer als
das. Szenario 2 verlangt aber, dass Harmony rechnet, während die Vorderfrau
überlegt, nicht über zwei Minuten hinweg.

**Folge für den Bau.** Die Zusammenfassung der Zufallsschicht, die
`04-architektur.md` als *nächste Stufe für den Fall der Fälle* nennt, ist
keine Rückfallposition mehr, sondern der Entwurf. Der Grund ist strukturell:
Die Nachfüllung hängt allein davon ab, **welches Feld genommen wurde**, nicht
davon, wohin die Steine gelegt wurden. Es gibt also nur fünf verschiedene
Zufallsschichten je Stellung, nicht eine je Zug. Aus ihnen wird je Feld eine
erwartete Verfügbarkeit je Farbe gebildet — 5 × 56 = 280 Rechnungen — und
jeder Zug dann **einmal** dagegen bewertet.

Das senkt den Aufwand von 13 Millionen auf rund 39.000 Bewertungen, ein
Faktor von etwa 330, ohne die Wahrscheinlichkeiten preiszugeben: Sie gehen
in die Verfügbarkeit ein, statt aufgezählt zu werden.

Was dabei verlorengeht, ist die Kopplung zwischen Brett und Auslage
innerhalb eines Blattes — ob genau der Stein nachrückt, den genau dieser
Anwärter braucht. Der Erwartungswert bleibt richtig, seine Streuung
verschwindet. Für v1 ist das vertretbar, und es gehört als Annahme benannt,
nicht als Tatsache.

Nicht ausgenutzt wird die **Symmetrie des Spielplans**. Seite A ist waagerecht
wie senkrecht spiegelbar, was die Eröffnungszüge um etwa den Faktor vier
kürzen würde. Sobald ein Stein liegt, ist die Symmetrie gebrochen; der
Gewinn beschränkt sich auf den ersten Zug und lohnt den Sonderfall nicht.

## Offene Punkte

1. **Die Gewichtung der Bewertungsterme ist ungemessen.** Die vier Familien —
   Punkte jetzt, Aussicht aus Anwärtern, Aussicht aus Landschaften,
   Optionenvielfalt — greifen zu verschiedenen Zeiten der Partie. Womit sie
   gegeneinander zu verrechnen sind, gehört gemessen, sobald Selbstspiel
   läuft. Phase 3 nimmt v1 auf dem Durchlauf ab, nicht auf der Spielstärke;
   geraten wird deshalb vorerst.
