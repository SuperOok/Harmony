# Phase 6 — Durchstich

Status: abgeschlossen am 2026-09-20. Die Kette trägt — und ist zu langsam.

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

Am 2026-09-20 zunächst nur für den Steinteil gezählt, dann mit dem fertigen
Generator über **ganze Züge** — Steine, Kartennahme und Würfel zusammen:

Seite A, 23 Felder:

| belegte Felder | Züge | davon mit Würfel | × Zufallsschicht | Sekunden |
| --- | --- | --- | --- | --- |
| 0 | 235.290 | 0 | 13.176.240 | 18,6 |
| 6 | 111.762 | 54 | 6.258.672 | 9,0 |
| 12 | 41.676 | 150 | 2.333.856 | 3,3 |
| 18 | 9.698 | 182 | 543.088 | 0,8 |

Seite B liegt durchweg etwa ein Drittel höher: 304.200 Züge auf dem leeren
Brett.

**Die Schätzung trägt.** 2 bis 3 · 10⁵ Züge je Stellung liegen am oberen Rand
des geschätzten Bandes von 10⁴ bis 10⁵. Der Steinteil allein macht 38.709
davon aus, die Kartenwahl multipliziert ihn mit sechs — fünf offene Karten
oder keine.

**Die Würfel verzweigen kaum.** Auf leerem Brett kein einziger Zug mit
Würfel, später einige hundert. Das war anders erwartet worden und hat einen
einfachen Grund: Ein Muster will zwei bis vier bestimmte Landschaften
nebeneinander, und das kommt selten in einem einzigen Zug zustande. Die
Aufzählung aller Würfelmengen, die als teuer veranschlagt war, kostet
praktisch nichts.

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

Was dabei verlorengeht, ist die Kopplung zwischen Brett und Auslage
innerhalb eines Blattes — ob genau der Stein nachrückt, den genau dieser
Anwärter braucht. Der Erwartungswert bleibt richtig, seine Streuung
verschwindet. Für v1 ist das vertretbar, und es gehört als Annahme benannt,
nicht als Tatsache.

### Das Erzeugen allein kostet schon 18,6 Sekunden

Die 235.290 Züge **aufzuzählen** kostet 18,6 Sekunden, rund 80 Mikrosekunden
je Zug. Als das gemessen wurde, gab es noch keine Bewertung, und der Schluss
lautete: Der Engpass sei der Generator.

**Dieser Schluss war falsch**, und der Abschnitt bleibt als Warnung stehen.
Er beruhte auf der Annahme, eine Bewertung koste zehn Mikrosekunden — eine
Zahl, die nirgends herkam. Gemessen sind es 2.400 bis 6.900. Die Aufzählung
ist damit der kleinere Posten, siehe *Die Suche, und was sie kostet*.

Was daran trägt, sind die beiden Ursachen und die Faktorisierung:

- **Jeder Zug wird als eigener Wert gebaut**, mit zwei Wörterbüchern darin,
  nur um bewertet und weggeworfen zu werden.
- **Das Brett ist ein Wörterbuch.** Für 23 bis 25 feste Felder täte ein Feld
  fester Länge dasselbe, ohne Streuwerte zu rechnen.
- **Die Kartenwahl vervielfacht den Raum mit sechs, berührt das Brett aber
  fast nie** — auf leerem Brett in keinem einzigen Zug. Brett und Karte
  lassen sich deshalb weitgehend getrennt bewerten, was aus 235.000 wieder
  rund 39.000 macht.

Zwei Verbesserungen wurden schon gemessen und sind drin: die Landschaftstabelle
wird einmal gerechnet statt millionenfach (26 s → 18,6 s je Stellung bei
gleichzeitig sechsfacher Zugzahl), und die Würfelsuche der Handkarten hängt
nicht mehr in der Schleife über die Kartenwahl (42,9 s → 18,6 s).

Nicht ausgenutzt wird die **Symmetrie des Spielplans**. Seite A ist waagerecht
wie senkrecht spiegelbar, was die Eröffnungszüge um etwa den Faktor vier
kürzen würde. Sobald ein Stein liegt, ist die Symmetrie gebrochen; der
Gewinn beschränkt sich auf den ersten Zug und lohnt den Sonderfall nicht.

## Verschachtelte Landschaften

Beim Bau der Mustersuche ist nachgerechnet worden, welche Landschaften
überhaupt ineinander übergehen können — welche also auf derselben Zelle
nacheinander zwei Karten bedienen. Die Bedingung ist, dass der eine Stapel
ein **Anfangsstück** des anderen ist, denn ein Stein kommt nie wieder
herunter. Es sind genau vier Paare:

| von | nach | Stapel |
| --- | --- | --- |
| `Berg1` | `Berg2` | `S` → `SS` |
| `Berg1` | `Berg3` | `S` → `SSS` |
| `Berg2` | `Berg3` | `SS` → `SSS` |
| `Berg1` | `Gebäude` | `S` → `SZ` |

Die drei Bergpaare waren erwartet. **Der Übergang vom Berg der Höhe 1 ins
Gebäude war es nicht**: Ein Gebäude ist ein roter Stein auf Rot, Braun oder
Grau, und in der Grau-Variante steht darunter derselbe einzelne graue Stein,
den `Berg1` verlangt. Eine Zelle kann also als Berg ihren Würfel nehmen und
danach Gebäude für eine zweite Karte werden.

Bäume können das nicht: `Baum1` ist ein grüner Stein auf nichts, `Baum2`
verlangt einen braunen darunter, und der lässt sich nicht mehr unterschieben.
Auf Wasser und Feld wird ohnehin nie gestapelt.

Die Liste ist hergeleitet, nicht aufgeschrieben — sie fällt aus den vierzehn
zulässigen Stapeln und der Präfixeigenschaft. Ein Test sichert genau diese
vier Paare zu, damit eine spätere Änderung an der Stapelliste hier auffällt.

## Die Bewertung zerfällt in vier Familien

Gebaut am 2026-09-20. Jeder Term trägt einen Namen, weil die Begründung die
größten Beiträge nennt und ein namenloser Summand darin nicht auftauchen
könnte.

| Familie | trägt | Quelle |
| --- | --- | --- |
| Punkte jetzt | die Endwertung | `BoardScoring.breakdown()` und die Kartenleitern |
| Aussicht aus Anwärtern | die mittlere Partie | Anwärter × Wahrscheinlichkeit |
| Aussicht aus Landschaften | die **frühe** Partie | Fluss auf Seite A, Inseln auf Seite B |
| Optionenvielfalt | den ersten Zug | wie viele Anwärter den Zug überleben |

**Anwärter werden ausgewählt, nicht addiert.** Je Karte der beste Anwärter,
darüber die beste paarweise verträgliche Teilmenge — bei höchstens vier
Karten eine Aufzählung über sechzehn Fälle. Die Ersparnis geteilter Felder
geht anteilig an die Terme zurück, damit jeder weiterhin seine Karte nennt.

**Die Inselaussicht musste umgebaut werden.** Der erste Entwurf zählte
Felder, auf denen **ein** blauer Stein eine Insel abtrennt. Auf frühem Brett
gibt es die nicht: Ein einzelner Stein zerschneidet nichts, und Seite B stand
damit die ganze Eröffnung über ohne Landschaftsaussicht da — genau die Lücke,
die diese Familie schließen soll.

An ihre Stelle tritt die **billigste Insel**: ein Feld mit Wasser einkreisen.
Ihre Kosten sind die Zahl seiner noch nicht blauen Nachbarn — an einer Ecke
zwei oder drei, in der Mitte sechs. Das ist eine obere Schranke für den
billigsten Schnitt, in einem Durchgang über die Felder zu rechnen, und es
unterscheidet die Lagen von der ersten Runde an. Den wirklich billigsten
Schnitt zu suchen hieße, alle Feldmengen durchzuprobieren; das ist je
Bewertung nicht zu bezahlen.

**Die Wahrscheinlichkeit ist ein erstes Modell, keine Messung.** Jeder
fehlende Stein wird als unabhängig behandelt: Bei einem Anteil *p* seiner
Farbe am Beutel und drei Steinen je eigenem Zug ist die Aussicht, ihn in *t*
Zügen mindestens einmal zu sehen, `1 - (1 - p)^(3t)`. Das überschätzt, weil
die Steine zusammen gebraucht werden und die Auslage allen gehört. Richtig
ist daran die Richtung — knappere Farbe, weniger Zeit oder mehr fehlende
Steine senken den Wert —, und darauf ruht die Reihenfolge. Die Form gehört
gemessen, sobald Selbstspiel läuft.

## Die Suche, und was sie kostet

Expectimax wie in `04-architektur.md` entschieden: ein eigener Zug tief, die
Zufallsschicht darunter zusammengefasst. Ergebnis ist ein Vorschlag mit den
größten Beiträgen, den Punkten jetzt, dem Wert der Stellung und dem Abstand
zum zweitbesten Zug — was Störfall C verlangt.

**Die Kette trägt.** Aus den Kartendaten, der Geometrie, den Lebensräumen,
dem Zustand, den Zügen und der Bewertung entsteht ein Zugvorschlag samt
Begründung. Das ist die Kernfrage dieser Phase, und sie ist beantwortet.

**Sie ist zu langsam.** Gemessen auf Seite A — **im Debug-Bau**, was lange
niemandem auffiel und weiter unten eine eigene Überschrift bekommt:

| belegte Felder | je Bewertung | Züge | Erzeugen | Suche gesamt |
| --- | --- | --- | --- | --- |
| 6 | 6.892 µs | 111.762 | 9,0 s | **779 s** |
| 12 | 4.312 µs | 41.676 | 3,4 s | 183 s |
| 18 | 2.351 µs | 9.698 | 0,8 s | 24 s |

Szenario 2 verlangt, dass Harmony rechnet, während die Vorderfrau überlegt —
also in der Größenordnung einer halben Minute. Auf gefülltem Brett ist das
erreicht, auf offenem fehlt der Faktor 30.

**Der Befund aus Schritt 6 hat sich umgedreht.** Dort sah das Erzeugen der
Züge wie der Engpass aus — aber nur, weil nichts sie bewertete. Eine
Bewertung kostet 2,4 bis 6,9 Millisekunden statt der zehn Mikrosekunden, mit
denen damals gerechnet wurde. Mit echter Bewertung überwiegt das Bewerten das
Erzeugen um **zwei Größenordnungen**. Die Bremse ist nicht, dass es zu viele
Züge gibt, sondern dass jeder einzelne zu teuer beurteilt wird.

### Auf dem Gerät gemessen: Faktor zwei

Am 2026-09-20 auf einem iPhone 15 Pro Max gemessen, gegen denselben
Gerätetyp im Simulator auf dem Mac, bei **identischer Stellung und
identischer Zugzahl**:

| | Züge | Zeit | je Zug |
| --- | --- | --- | --- |
| Simulator auf dem Mac | 12.270 | 55,6 s | 4,53 ms |
| iPhone 15 Pro Max | 12.270 | 110,2 s | 8,98 ms |

**Genau doppelt so lang.** Der Faktor ist sauber genug, um die Mac-Zahlen
umzurechnen, statt jede einzeln auf dem Gerät zu wiederholen: Was dort 24
Sekunden bis 13 Minuten braucht, braucht am Tisch 48 Sekunden bis 26
Minuten.

Die 12.270 Züge sind dabei ein **Sonderfall nach unten**, und das ist lehrreich:
Der Klickdummy hält vier unabgeschlossene Karten, also darf keine fünfte
genommen werden, und der Kartenzweig entfällt samt seinem Faktor sechs. Mit
freier Kartenhand wäre dieselbe Stellung rund 74.000 Züge groß und damit
**elf Minuten** auf dem Gerät.

Damit steht der Abstand zum Ziel fest. Szenario 2 gibt etwa eine halbe
Minute — solange die Vorderfrau überlegt. Gebraucht wird also:

| Stellung | Gerät, Debug | nötiger Faktor | Gerät, Release | dann noch nötig |
| --- | --- | --- | --- | --- |
| Brett fast voll | 48 s | 2 | **8 s** | erreicht |
| Brett zur Hälfte | 6 min | 12 | **1 min** | 2 |
| frühe Partie | 17 min | 35 | **2,8 min** | 6 |

Die beiden rechten Spalten sind am selben Tag dazugekommen und stehen hier,
weil sie die ganze Tabelle verschieben — siehe *Die Hälfte lag am Bau*. Der
verbleibende Faktor 6 für die frühe Partie ist der Rest, um den es in den
Abhilfen noch geht; die Hochrechnung dort kommt auf 3 mal 2 bis 2,5 und damit
darüber hinaus.

### Die Hälfte lag am Bau

**Gemessen am 2026-09-20.** Alle Zahlen oben stammen aus einem
**Debug**-Bau: `tools/messe-verzweigung.sh` rief `swift run` ohne
`-c release`, und die App auf dem Gerät war ein Debug-Bau desselben Schemas.
Swift ohne Optimierung heißt keine Spezialisierung, kein Inlining, volle
Retain/Release-Last. Bei einer Engine, die nichts tut als rechnen, ist das
kein Detail:

| belegte Felder | je Bewertung Debug | Release | Faktor | Suche gesamt |
| --- | --- | --- | --- | --- |
| 6 | 6.915 µs | **1.100 µs** | 6,3 | 782 s → **124 s** |
| 12 | 4.353 µs | **674 µs** | 6,5 | 185 s → **28 s** |
| 18 | 2.328 µs | **300 µs** | 7,8 | 23 s → **3 s** |

In der App gegengeprüft, im Simulator, dieselbe Stellung und dieselben 12.270
Züge: **55,4 s im Debug-Bau, 9,5 s im Release-Bau.** Beide schlagen denselben
Zug vor (`H33 Z33 L43`, Bewertung 83), die Zahl der geprüften Züge ist
identisch — der Bau ändert die Antwort nicht, nur die Wartezeit.

`tools/messe-verzweigung.sh` misst seither im Release-Bau. Die Debug-Tabelle
oben bleibt stehen, weil sonst nicht nachvollziehbar wäre, woher die Zahlen
kamen, die in diesem Dokument ursprünglich standen.

### Wohin die Zeit einer Bewertung geht

Eine Bewertung im Release-Bau, sechs belegte Felder, Seite A, zwei
Handkarten — 970 µs, aufgeschlüsselt:

| Teil | µs | Anteil |
| --- | --- | --- |
| Anwärter (`candidateTerms`) | 392 | 40 % |
| Vielfalt (`liveCandidateCount`) | 267 | 28 % |
| Landschaften — davon Fluss 215 | 220 | 23 % |
| Wertung (`BoardScoring.breakdown`) | 8 | 1 % |

Drei Befunde:

1. **`Habitat.all` wird zweimal je Bewertung gerechnet**, mit denselben
   Argumenten: einmal in `candidateTerms`, einmal in `liveCandidateCount`.
   272 µs für zwei Handkarten. Die Vielfalt ist damit fast vollständig
   doppelte Arbeit.
2. **Sechs Züge teilen sich eine Legung** — nachgezählt, exakt 6,0 bei jeder
   Stellungsgröße (5.237 Legungen / 31.422 Züge bei belegt 6; 1.922 / 11.532
   bei 12; 437 / 2.622 bei 18). Das sind die fünf offenen Karten plus „keine
   Karte". Alles Legungsabhängige wird deshalb sechsmal gerechnet statt
   einmal.
3. **Der Fluss kostet 215 µs für ein Gebiet von 18 Feldern.** `longestPath`
   startet eine Breitensuche **je Feld des Gebiets**, jede mit eigenem
   Wörterbuch. Das Verfahren ist ohnehin eine Näherung — Doppel-BFS auf einem
   Graphen mit Zyklen —, und mit zwei Startpunkten statt achtzehn wäre es
   rund neunmal billiger bei gleicher Art von Antwort.

Die Kopie eines Zustands je Zug (`state.applying`) kostet dagegen 0,5 bis
0,7 µs und ist damit kein Posten. Die Wörterbücher schaden, aber nicht dort,
wo man sie vermutet.

### Mehrere Kerne: Faktor 3,6 auf acht, etwa 2 auf dem Gerät

Die Suche läuft heute auf **einem** Kern. Der Versuch, die Legungen eines
Auslagefelds in gleich große Stücke zu schneiden und nebenläufig zu wiegen,
halbvolles Brett, 11.532 Züge, auf einem Mac mit vier schnellen und vier
sparsamen Kernen:

| Stücke | Zeit | Faktor |
| --- | --- | --- |
| seriell | 6,65 s | — |
| 2 | 3,69 s | 1,80 |
| 4 | 2,35 s | 2,83 |
| 8 | 1,86 s | **3,57** |
| 16 / 64 | 1,86 s | 3,57 |

Acht Kerne geben 3,6, nicht 8: Die sparsamen Kerne sind langsamer, und die
Bewertung legt so viel Speicher an, dass die Zuteilung selbst bremst. Feiner
als acht Stücke bringt nichts.

**Der Schnitt gehört über die Legungen**, nicht über die Auslagefelder: Davon
gibt es höchstens fünf, sie sind ungleich groß (1.922 / 495 / 1.510 / 1.980 /
1.014 Legungen bei belegt 12), und gleiche Felder werden zusammengefasst — im
schlimmsten Fall bleibt ein einziges übrig und damit keine Nebenläufigkeit.
Auch nicht über die Kartenwahl: Das ist die Ebene, auf der geteilt statt
getrennt werden soll, siehe Befund 2 oben. Legungen dagegen gibt es zu
Tausenden, sie sind gleich teuer und voneinander unabhängig.

**Bedingung:** Das Verschmelzen der Teilergebnisse muss in fester Reihenfolge
geschehen, nach Stücknummer und nicht danach, wer zuerst fertig wurde. Sonst
entscheidet bei Gleichstand die Zuteilung, und dieselbe Stellung gibt zweimal
verschiedene Züge — was `SearchTests` zusichert und die Momentaufnahmen aus
`pruefverfahren.md` brauchen. Im Versuch ist es so gebaut, und bei 2, 4, 8, 16
und 64 Stücken kam derselbe Zug heraus.

Auf dem Gerät ist weniger zu erwarten: Der A17 Pro hat **zwei** schnelle und
vier sparsame Kerne, nicht vier und vier. Hochgerechnet bleiben **Faktor 2 bis
2,5**, dazu Drosselung bei minutenlanger Vollast und der Stromsparmodus, der
Kerne wegnimmt.

### Fünf Abhilfen, nach Wirkung geordnet

0. **Im Release bauen und messen.** ✅ **Gemessen, Faktor 5,8 bis 7,8.**
   Kostet nichts, ändert die Antwort nicht und verschiebt die Bewertung aller
   folgenden Punkte. Offen bleibt, dass das Xcode-Schema beim Laufenlassen
   weiter Debug baut — fürs Gerät gehört `-configuration Release` an den
   Installationsbefehl.
1. **Legungsabhängiges einmal je Legung rechnen.** Fluss, Landschaftswertung
   und `Habitat.all` hängen allein an der Legung, nicht daran, welche Karte
   genommen wurde; sechs Züge teilen sich eine. Dazu die Doppelrechnung von
   `Habitat.all` zwischen Anwärtern und Vielfalt. Hochgerechnet aus den
   gemessenen Teilen: **Faktor 3**, also rund 320 µs statt 1.100 µs je Zug.
2. **Inkrementell bewerten.** Ein Zug ändert höchstens drei Felder. Die
   Landschaftswertung, die Flussaussicht und die Anwärter ändern sich nur
   dort. `04-architektur.md` sieht das Vorhalten der Musterinstanzen ohnehin
   vor; hier ist der Beleg, dass es nötig ist. Größter Hebel der verbleibenden.
3. **Den längsten Fluss billiger suchen.** Zwei Startpunkte statt achtzehn,
   siehe *Wohin die Zeit einer Bewertung geht*. Rund ein Fünftel einer
   Bewertung, und die Näherung wird nicht schlechter begründet, als sie es
   heute schon ist.
4. **Über die Legungen auf mehrere Kerne verteilen.** Faktor 2 bis 2,5 auf dem
   Gerät. Bewusst hinter dem Sparen: Nebenläufigkeit verteilt dieselbe Arbeit
   und verbraucht denselben Strom in kürzerer Zeit — sechs Kerne, die
   überflüssige Arbeit tun, tun überflüssige Arbeit.
5. **Keine Wörterbücher für Spielplan und Zug.** 23 bis 25 feste Felder sind
   ein Feld fester Länge, kein Streuwertspeicher. Gemessen ist der Posten
   kleiner als gedacht — das Kopieren eines Zustands kostet 0,5 µs —, der
   Gewinn läge in den Streuwerten innerhalb der Bewertung, nicht im Kopieren.

Erledigt und gemessen sind bereits zwei kleinere: die Landschaftstabelle wird
einmal gerechnet statt millionenfach, und die Würfelsuche der Handkarten hängt
nicht mehr in der Schleife über die Kartenwahl. Zusammen 43 s → 18,6 s für das
Erzeugen.

## Was als Nächstes kommt

1. **Die Bewertung schneller machen**, nach der Liste oben — Punkt 0 ist
   gemessen und kostet nichts, Punkt 1 ist der nächste Umbau. Erst danach
   lohnt sich Feinschliff an den Gewichten: Eine Stellschraube, deren Wirkung
   man erst nach Minuten sieht, wird nicht gedreht.
2. **Den Dummy-Zustand ablösen.** Eine **Brücke** steht seit dem 2026-09-20
   (`MyApp/Dummy/EngineBridge.swift`): Sie übersetzt den Zustand des
   Klickdummys in einen `EngineState` und den Vorschlag zurück in einen
   `HarmonyMove`. Damit läuft die Engine auf dem Gerät. Die Ablösung selbst
   — `EngineState` als der **eine** Zustand statt zweier, die eine Brücke
   auseinanderhält — steht weiter aus.

   Was dabei schon erledigt ist: Eine Partie beginnt leer und füllt sich,
   Harmony nimmt Karten, ihr Zug leert und füllt ein Auslagenfeld, der
   doppelte `AnimalCard` ist weg, und der Verlauf überdauert das Weglegen
   (`MyApp/Dummy/GameStore.swift`). Dazu zwei Dinge, die bleiben sollten:
   Die Suche ist ein **Anytime-Verfahren** geworden — bei Abbruch gibt sie
   den besten bis dahin gefundenen Zug und sagt über `complete`, dass es
   nicht der beste ist. Und an der Stelle des Vorschlags steht **nichts**,
   solange gerechnet wird; ein Beispielzug dort würde am Tisch gespielt.
   Was stattdessen dasteht, sagt der Abschnitt *Was die Suche über sich
   sagt* weiter unten.

3. **Stockwerk 2**, sobald eine Partie durchläuft.

### Was die Suche über sich sagt

**Angelegt am 2026-09-20**, nachdem sich beim Spielen auf dem Gerät zeigte,
dass nach dem letzten gegnerischen Zug scheinbar nichts geschieht. Geschehen
ist durchaus etwas — die Suche lief —, nur stand die Zeile, die das sagte,
unter einem Spielplan, der höher ist als der Bildschirm. Bei 110 Sekunden
Rechenzeit ist das derselbe Anblick wie ein hängendes Gerät.

Drei Änderungen, zusammen eine:

1. `Search.best` meldet unterwegs (`SearchProgress`): geprüfte Züge, wie
   viele Auslagefelder fertig sind und von wie vielen, und der beste Zug
   bisher samt Bewertung. Einmal gemeldet wird vor dem ersten gewogenen Zug,
   damit in der ersten Sekunde etwas dasteht. **Weiter geht die Auskunft
   nicht:** Innerhalb eines Auslagefelds gibt es keinen Nenner, ohne alle
   Züge vorher aufzuzählen — genau das, was die Suche vermeidet. Ein Balken
   über Felder ist deshalb das Ehrlichste, was zu haben ist.
2. `ThinkingView` zeigt das, öffnet sich von selbst, wenn eine Suche
   beginnt, schließt sich, wenn sie fertig ist, und trägt den Knopf
   **Abkürzen**. Was er verspricht — den besten bisher gefundenen Zug —,
   steht auf demselben Schirm darüber, und ein Prüffall hält beides
   aneinander (`SearchTests`, „Eine abgebrochene Suche meldet den Zug, den
   sie herausgibt").
3. Die Statuszeile ist **über** den Spielplan gewandert.

Der Melder zwischen Suche und Schirm (`SearchMonitor` in `EngineBridge.swift`)
hält je einen Stand unter einem Schloss; der Schirm fragt viermal in der
Sekunde. Die Suche wartet damit nie auf die Oberfläche — Zusehen darf nichts
kosten.

**Was es nicht ist:** eine Abhilfe gegen die Rechenzeit. Die drei Hebel oben
bleiben, was sie sind. Sichtbar ist jetzt nur, was dauert.

## Offene Punkte

1. **Das Wahrscheinlichkeitsmodell ist geraten.** Jeder fehlende Stein wird
   als unabhängig behandelt. Es überschätzt, und wie sehr, weiß niemand.
   Richtig ist die Richtung, und darauf ruht die Reihenfolge der Züge — mehr
   wird auch nicht zugesichert.
2. **Die Zufallsschicht ist zusammengefasst, nicht gerechnet.** Die Kopplung
   zwischen Brett und Auslage innerhalb eines Blattes geht dabei verloren: ob
   genau der Stein nachrückt, den genau dieser Anwärter braucht. Der
   Erwartungswert bleibt richtig, seine Streuung verschwindet.
3. **Die Gewichtung der Bewertungsterme ist ungemessen.** Die vier Familien —
   Punkte jetzt, Aussicht aus Anwärtern, Aussicht aus Landschaften,
   Optionenvielfalt — greifen zu verschiedenen Zeiten der Partie. Womit sie
   gegeneinander zu verrechnen sind, gehört gemessen, sobald Selbstspiel
   läuft. Phase 3 nimmt v1 auf dem Durchlauf ab, nicht auf der Spielstärke;
   geraten wird deshalb vorerst.
