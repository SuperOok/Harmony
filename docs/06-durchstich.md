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

**Die Lage des Zielsteins folgt aus der Form.** Bei den verzweigten Formen
`11,12,21`, `12,21,32` und `12,21,22,32` liegt der Tierwürfel ausnahmslos auf
der Zelle, die alle anderen berührt. Bei der Dreierkette `11,12,13` liegt er
ausnahmslos an einem **Ende**, nie in der Mitte. Keine Karte weicht davon ab.

**Als Prüfung:** Ein Test gruppiert alle 32 Karten nach ihrer kanonischen
Form — über die sechs Drehungen normalisiert — und sichert genau diese
Aufteilung zu. Der Sollwert stammt aus einem von Hand bestätigten Befund und
nicht aus einem Programmlauf, wie `00-methodik.md` es verlangt. Schlägt der
Test an, ist entweder die Geometrie falsch oder eine Karte falsch erfasst;
beides will man wissen.

## Verzweigung

*Wird eingetragen, sobald gemessen.* `04-architektur.md` schätzt 10⁴ bis 10⁵
eigene Züge je Stellung und hält ausdrücklich fest, dass der Durchstich das
nachzumessen hat.

## Offene Punkte

1. **Die Gewichtung der Bewertungsterme ist ungemessen.** Die vier Familien —
   Punkte jetzt, Aussicht aus Anwärtern, Aussicht aus Landschaften,
   Optionenvielfalt — greifen zu verschiedenen Zeiten der Partie. Womit sie
   gegeneinander zu verrechnen sind, gehört gemessen, sobald Selbstspiel
   läuft. Phase 3 nimmt v1 auf dem Durchlauf ab, nicht auf der Spielstärke;
   geraten wird deshalb vorerst.
