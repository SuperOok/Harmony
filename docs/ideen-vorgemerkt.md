# Vorgemerkte Ideen

Beobachtungen, die beim Arbeiten an einer Phase anfielen, aber in eine spätere
gehören. Hier geparkt, damit sie weder verlorengehen noch die laufende Phase
entgleisen lassen.

Nichts hiervon ist entschieden.

## Für Phase 3 — Funktionsumfang ✅ erledigt

Beide hier geparkten Punkte sind in `03-funktionsumfang.md` entschieden:

- **Wie viel weiß Harmony über die Mitspieler?** → geteilte Auslagen,
  Kartenzuordnung und eine manuelle Endemeldung; keine fremden Tableaus.
- **Mitzählen, was im Beutel liegt.** → in v1 enthalten, ohne zusätzliche
  Eingabe, weil die Szenarien jede Nachfüllung ohnehin erfassen.

## Für Phase 4 — Daten und Architektur ✅ eingearbeitet

Die Punkte dieses Abschnitts stehen in `04-architektur.md` — der
Identifikator, die Bewertungsterme, das Vorhalten der Musterinstanzen. Sie
bleiben hier stehen, weil die Begründungen ausführlicher sind als das, was
dort hineinpasst, und weil die beiden widerlegten Thesen am Ende niemand
erneut aufstellen soll.

**Karten brauchen einen stabilen Identifikator.** ✅ Entschieden: Es bleibt
bei den Namen. Sie sind erfunden, aber eindeutig — `tools/pruefe-tierkarten.py`
erzwingt das — und am Tisch vorlesbar, was eine Nummer nicht ist. Siehe
`pruefverfahren.md`, Zugnotation.

**Karten sind nicht über ihre Gesamtpunktzahl vergleichbar.** Die Biene bringt
mit zwei Würfeln 8 und 18, das Erdmännchen mit vieren 2/5/9/14. Maßgeblich ist
der **Zuwachs pro gelegtem Würfel** im Verhältnis zur Schwierigkeit des
Musters, nicht die Summe.

Lachs und Frosch belegen das sauber. Beide haben dieselbe Form und denselben
Zielstein, nur die zweite Zelle unterscheidet sich:

| | zweite Zelle | Steine dafür | Würfel | Punkte |
| --- | --- | --- | --- | --- |
| Lachs | `Berg3` | 3 | 4 | 3 / 6 / 10 / 16 |
| Frosch | `Baum1` | 1 | 5 | 2 / 4 / 6 / 10 / 15 |

Das leichtere Muster bekommt mehr Würfel bei flacheren Schritten, das schwerere
weniger bei steileren. Der Endwert ist fast gleich; der Unterschied liegt in
der **Geschwindigkeit**. Welche Karte besser ist, hängt damit an der
Restlaufzeit der Partie — die Harmony kostenlos aus dem Zugzähler kennt.

**Gleiche Punktleiste heißt nicht gleicher Wert.** Affe und Panther tragen
beide zwei Tierwürfel und dieselbe Leiste 5 / 11. Der Affe kostet vier Steine
(Berg2 und zwei Wasser), der Panther fünf (zwei Baum2 und ein Feld). Gleicher
Ertrag, höherer Preis — die Schwierigkeit einer Karte steht nirgends auf ihr
und muss aus dem Muster berechnet werden.

Die Steinzahl allein misst sie aber auch nicht. Affe und Papagei haben
dieselbe Form und kosten dieselben vier Steine; die Mitte ist einmal `Berg2`
(zwei graue), einmal `Baum2` (ein brauner, ein grüner). Der Papagei bekommt
drei Würfel statt zwei. Naheliegende Erklärung: Ein Berg2 ist aus **einer**
Farbe zu bauen, und Grau ist mit 23 Steinen die häufigste; ein Baum2 braucht
zwei verschiedene Farben, gezogen wird aber in festen Dreiergruppen. In eine
Schwierigkeitsschätzung gehören also Farbknappheit und Stapelzwang, nicht nur
die Anzahl der Steine.

**Die Würfelzahl ist die Stellschraube, nicht die Gesamtsumme.** Innerhalb
einer Formklasse liegen Karten mit drei Tierwürfeln bei 16 bis 18
Höchstpunkten, solche mit zweien bei 11 bis 12. Der **erste** Würfelwert
dagegen wächst mit der Größe des Musters: 4 bis 5 bei drei Zellen, 6 beim
Waschbären und 8 bei der Biene mit vieren. Das entspricht der Mechanik — die
Würfelzahl sagt, wie oft das Muster gebaut werden muss, der erste Wert, was
eine einzelne Fertigstellung einbringt. Eine Bewertungsfunktion sollte daher
am Zuwachs des **nächsten** Würfels rechnen, nicht an der Kartensumme.

**Punktleisten sind aus einem kleinen Vorrat gezogen.** Auf 32 Karten kommen
nur 19 verschiedene Leisten vor; sieben davon sind mehrfach belegt, `5/10/17`
und `4/10/16` und `5/11` je viermal — teils über Formklassen hinweg. Eine
Engine kann Leisten also als Aufzählung führen. Berechenbar aus Steinzahl und
Würfelzahl sind sie aber nicht: Frosch und Marienkäfer haben beide zwei
Steine und fünf Würfel, aber `2/4/6/10/15` gegen `2/5/8/12/17`.

*Zwei widerlegte Thesen, damit sie niemand erneut aufstellt:*

„**Höchstpunktzahl = Steinzahl + 13.**" Passt auf Pinguin, Pfau, Eisvogel,
Hase und Wüstenfuchs, scheitert an Papagei (4 Steine, 14 Punkte), Eisfuchs
(3 Steine, 17), Echse, Lama und Panther. Sie stammte aus drei Datenpunkten
einer einzigen Formklasse und war schon durch den damals bereits erfassten
Papagei widerlegt.

„**Die Tierkarte zahlt, was die Landschaft nicht zahlt.**" Naheliegend beim
Raben, dessen zwei Gebäude bis zu 10 Landschaftspunkte tragen und der nur
`4/9` zahlt, und beim Igel mit sechs Steinen und `5/12`. Flamingo und Wolf
widerlegen sie: gleiche Form, gleiche Leiste `4/10/16`, aber der Wolf trägt
mit `Baum3` sieben Landschaftspunkte mehr im Muster.

Beide Male stand die These auf den zuletzt erfassten Karten. Hypothesen über
Kartenwerte gehören gegen den **gesamten** Bestand geprüft —
`tools/pruefe-tierkarten.py` gibt die Tabelle dafür aus.

**Muster erfüllen manchmal nebenbei eine Landschaftswertung.** Die beiden
Felder des Lamas bilden zugleich eine Feldgruppe, die beiden Berge des
Wüstenfuchses erfüllen einander die Nachbarschaftsbedingung. Andere Muster
tun das ausdrücklich nicht, siehe Erdmännchen unten. Der Tierwürfel und die
Landschaftswertung sind also weder deckungsgleich noch unabhängig.

**Landschaftswertung allein reicht nicht.** Das Erdmännchen belohnt einen
einzelnen Berg der Höhe 1 — als Landschaft 0 Punkte wert, solange er an keinen
anderen Berg grenzt. Eine Bewertungsfunktion, die nur Landschaften zählt,
würde solche Züge nie finden.

**Muster teilen sich Zellen.** Eisvogel und Pinguin sind formgleich und
unterscheiden sich nur in der Mitte. Ein einzelner Stein kann also entscheiden,
welche von zwei Karten bedient wird. Musterinstanzen überlappen; das
Vorhalten aller gefundenen Instanzen dürfte sich lohnen.

**Tierwürfel bleiben liegen.** Ein Muster darf nach dem Setzen des Würfels
zerstört werden. Das erlaubt Züge, die ein naiver Bewerter nie erwägt:
erfüllen, setzen, überbauen.

## Für Phase 5 — Oberfläche

**Klickdummy früh, vor der Engine.** Hauke möchte die Oberfläche iterativ
ausprobieren, bevor Funktion dahintersteckt. Das spricht dafür, Phase 5
vorzuziehen — Eingabeeffizienz ist das erste Qualitätskriterium aus Phase 1
und lässt sich nicht aufschreiben, nur antippen. Offen ist nur, ob vor oder
nach Phase 4; die Entscheidung steht aus. Die Methodik müsste dafür
präzisiert werden: Ansichtscode über Attrappendaten ist etwas anderes als
der Engine-Code, den „ab Phase 6 wird Code geschrieben" verhindern sollte.
Messbar wird der Dummy über die Antippzahl, siehe `pruefverfahren.md`.

**Die Kartenauswahl ist der Engpass, nicht die Steine.** Am ersten Dummy
gemessen: Ein fremder Zug **ohne** Kartennahme kostet 5 Antipper — Feld,
drei Farben, eintragen. **Mit** Kartennahme sind es 8, und schlimmer als die
Zahl ist der letzte Schritt: Die nachgerückte Karte wird aus einer Liste von
27 Namen gewählt, die gescrollt werden muss. Der Betreuer hat die Karte in
der Hand und müsste **unseren** erfundenen Namen dafür kennen.

Die Liste ist inzwischen ein **Raster aus zwei Spalten**, alphabetisch
sortiert: Alle 27 passen auf einen Bildschirm, das Scrollen entfällt. Die
Antippzahl bleibt bei 8, aber die teure Sucherei ist weg — sie war das
eigentliche Problem, nicht die Taps.

Die Sorge, der Betreuer müsse **unseren** Namen für die Karte in seiner Hand
kennen, hat sich am Gerät nicht bestätigt und ist am 2026-09-20 **verworfen**:
Alle Karten passen in das Raster, und die Namen sind eindeutig genug, um eine
Karte wiederzufinden. Damit entfallen die beiden Auswege, die dagegen gedacht
waren — der **Farbstreifen** als Filter und die Piktogramme weiter unten.

Für den Farbstreifen wurde vorher geprüft, ob die Daten ihn hergäben: Sie tun
es. Er wird laut `kartennotation.md` nicht erfasst, weil er redundant ist —
seine Farbe ist die des Zielsteins, und die steht als Landschaft der
Würfelzelle in jeder Karte. Über alle 32 Karten verteilte er sich auf fünf
Farben (Baum 8, Wasser 7, Berg 6, Feld 6, Gebäude 5). Gebraucht wird er
trotzdem nicht.

**Die Tierwürfel sind durchscheinend orange.** Für keine Regel erheblich —
die Engine braucht die Farbe nicht —, aber die Oberfläche sollte sie
trotzdem treffen, damit man am Tisch wiedererkennt, was auf dem Schirm
steht. Steht hier und nicht in `regeln-basisspiel.md`, weil es keine Regel
ist.

**Stand des Klickdummys, 2026-09-20.** Abgedeckt sind aus der Funktionsliste
von Phase 3: Punkt 1 (Aufbau erfassen, 21 Antipper), Punkt 2 und 3 (fremde
Züge erfassen, 5 Antipper ohne Kartennahme, 8 mit), Punkt 4 (Harmonys Zug als Handlungsanweisung im
Zielzustand, mit Bestätigung), Punkt 5 (Verlauf und Rücknahme) sowie die
Punkte 16 bis 18 (Begründung mit Aussichten, Wahrscheinlichkeiten und
zweitbestem Zug). Der Zustand liegt als Ereignisprotokoll vor und wird
nachgespielt, wie Phase 4 es vorsieht.

Dazu Punkt 7 (Spielende) mit beiden Auslösern und der
ausgespielten letzten Runde.

Inzwischen ebenso Punkt 8 (Endwertung, für beide Planseiten) und Punkt 6
(Korrekturweg für Harmonys Tableau) samt dem Merker „jemand ist fast
fertig". Damit ist die Funktionsliste von Phase 3 im Dummy vollständig
abgedeckt, soweit sie Oberfläche ist; `05-ui.md` ist geschrieben und führt,
was offen blieb.

**Bildsymbole statt Namen.** ❌ Verworfen am 2026-09-20, zusammen mit dem
Farbstreifen und aus demselben Grund: Die Namen tragen. Die Überlegung war,
dass ein kleines Tierbild schneller und sicherer trifft als ein Name, den sich
niemand merkt — und dass selbstgezeichnete Silhouetten das ohne die
geschützten Originalillustrationen leisten. Beides bleibt richtig; es löst nur
kein Problem, das am Tisch auftritt.

## Für Phase 6 — Durchstich und Geschwindigkeit

**„Legung" statt „Brett", `Laying` statt `Placement`/`boards`.** ✅
Entschieden am 2026-09-20, **umgesetzt noch am selben Abend** — zusammen mit
dem Umbau der Bewertung, wie vorgesehen: Der Umbau fasste dieselben Stellen
an, und die Erklärung, was dort einmal je Legung gerechnet wird, ließ sich
über eine Ebene namens „Brett" nicht aufschreiben.

Gemeint ist eine von vielen Möglichkeiten, die drei Steine eines
Auslagefelds zu legen — bei halbvollem Spielplan rund 1900 je Feld. Heute
heißt das Ding im Code `Moves.Placement` und die Funktion darüber
`Moves.boards(placing:on:)`, im deutschen Text hieß es bisher „Brett". Beides
ist schief: Ein Spielbrett gibt es genau eines, und `Placement` ist doppelt
belegt — im Dummy meint es **einen** Stein auf **einem** Feld
(`Placement(stone:cell:)`, 34 Fundstellen). Dazu trägt der Parametername
`board:` zwei Bedeutungen, die Geometrie des Spielplans in
`Habitat.all(…, board:)` und eine Legung in `Moves.turns(space:board:)`.

Künftig:

| heute | künftig |
| --- | --- |
| `Moves.Placement` | `Moves.Laying` |
| `Moves.boards(placing:on:)` | `Moves.layings(of:on:)` |
| `Moves.turns(space:board:…)` | `Moves.turns(space:laying:…)` |
| „Brett" im deutschen Text | „Legung" |

`Placement(stone:cell:)` im Dummy und `Move.placements` bleiben, wie sie
sind: Dort ist ein Placement tatsächlich ein gelegter Stein. `board` bleibt
dem Spielplan vorbehalten.

Warum es zählt und nicht bloß Geschmack ist: Die Legung ist die Ebene, auf
der die Geschwindigkeitsarbeit ansetzt. Sechs Züge teilen sich eine Legung —
sie unterscheiden sich nur in der Kartenwahl und lassen den Spielplan
unberührt. Alles Legungsabhängige (Fluss, Landschaftswertung, `Habitat.all`)
wird deshalb sechsmal gerechnet statt einmal, und die Legungen sind
zugleich der Schnitt, an dem sich die Suche auf mehrere Kerne verteilen
ließe. Über eine Ebene, die „Brett" heißt, während daneben ein Spielplan
liegt, lässt sich das nicht aufschreiben.

## Offen aus Phase 6 — am Tisch aufgeworfen

**Zählt ein Gebäude ohne drei Farben ringsum 0 oder −2?** ✅ **Geklärt am
2026-09-22: 0 Punkte, kein Abzug.** Aufgeworfen am 2026-09-21 beim Spielen,
mit dem Einwand, die Broschüre nenne −2. Ein Blick in die Broschüre
bestätigt stattdessen den Regeltext dieses Projekts: `regeln-basisspiel.md`
sagt „5 Punkte je Gebäude, das von mindestens 3 verschiedenfarbigen
Spielsteinen umgeben ist […] Andernfalls 0 Punkte", `Scoring.swift` setzt
das unverändert um (`colors.count >= 3 ? 5 : 0`), und der Prüffall *Ein
Gebäude am Rand hat zu wenige Farben* sichert die 0 zu. Kein Umbau nötig.

**Die Bewertung sieht die Auslage nicht.** ❓ Bekannte Modellgrenze, am
2026-09-21 an einem Beispiel vermessen. Ein Zug, der ein Feld zubaut, das ein
Anwärter einer **gehaltenen** Karte gebraucht hätte, wird richtig bewertet —
gemessen: Der Anwärter verschwindet (25 → 22 Anwärter, 2 fertige → 0), und wo
er der einzige war, fällt der Wert der Stellung. Für Karten, die Harmony
**nicht hält**, zählt dagegen nichts: Liegt die Karte nur offen aus, ist der
zerstörte Anwärter für die Bewertung unsichtbar.

Dazu kommt, dass je Karte nur der **beste** Anwärter zählt — Reserve schlägt
sich nur über „Offene Möglichkeiten" mit 0,05 je Anwärter nieder. Beides ist
Absicht, beides wäre zu ändern, wenn sich die Spielstärke daran als zu
schwach erweist. Das gehört gemessen, sobald Selbstspiel läuft, und hängt
damit an derselben offenen Frage wie die Gewichte.

## Offen aus Phase 6 — das Ende der Partie

**Die Vorhersage des Spielendes eichen.** ❓ Seit dem 2026-09-22 schreibt
`-logSearch` vor jeder Suche, wie viele Felder die Mitspielerinnen nach dem
Modell belegt haben (`ENDE belegt …`). Am Tisch lässt sich das nachzählen.
Die Vorhersage steuert seit demselben Abend, ungeeicht; `-noForecastEnd`
schaltet sie ab. Liegen die echten Zahlen daneben, sind zuerst die
Stapelwerte in `EndForecast.stacking` zu prüfen. Siehe `06-durchstich.md`,
*Wann die anderen fertig sind*.

**Freie Felder nach der Partie erfragen.** ❓ Eine Eingabe ohne Zeitdruck: je
Mitspielerin die freien Felder am Ende. Über einige Partien macht das aus
den geratenen Stapelwerten gemessene, ohne die Eingabe während des Spiels
zu verlängern.

**Freie Felder im Endspiel erfragen.** ❓ Erst, wenn die Vorhersage ein Ende
in etwa zwei Runden für möglich hält: „Wie viele Felder hat die vollste
Mitspielerin noch frei?" Eine Beobachtung statt einer Grenze — sie setzt die
belegten Felder und schärft die Vorhersage für den Rest. Nur, falls die
Protokolle zeigen, dass die letzte Runde zu oft falsch getroffen wird.

**Die Karten der Mitspielerinnen einrechnen.** ❓ Die dritte Schicht des
Modells. Wer Baum 3, Berg 3 oder Gebäude sammelt, stapelt mehr; wer Wasser,
Feld, Baum 1 oder Berg 1 hält, legt flach und greift zu Blau und Gelb.
Zurückgestellt, weil sie die meisten geratenen Werte trägt und die
Landschaftswertung alle Spielerinnen ohnehin zum Stapeln zieht.
