# Stand der Engine und der App

Hier steht, was in `AGENTS.md` früher unter „Wo es steht“ stand: die
Geschichte der Phase 6 mit Messungen, Entscheidungen und den Befehlen für
Selbstspiel und `HarmonyMatch`. `AGENTS.md` trägt davon nur noch eine
Kurzfassung, weil es in jeder Sitzung ganz geladen wird, auch wenn es um
etwas ganz anderes geht. Der Text unten ist unverändert übernommen, auch die
Datierungen („Stand 2026-09-29“); die Kurzfassung in `AGENTS.md` ist
aktueller.

**Wo es steht:** Stand 2026-09-29. Der Durchstich aus Phase 6
trägt und läuft **auf dem Gerät**: Die App rechnet ihre Züge selbst, eine
Partie beginnt mit leerem Spielplan und füllt sich, und sie überdauert das
Weglegen. Geprüft wird mit 240 Regelfällen (`tools/tests.sh`, gut drei
Sekunden), 41 App-Fällen für Wissen der Partie, Verlauf, Spielstand, Sitzung und
Begründung (`tools/apptests.sh`) und acht Oberflächenfällen
(`tools/uitests.sh`).

**Durchgesehen am 2026-09-29.** Zwei Fehler in der Brücke zur Engine, die
kein Prüffall fand, weil die App-Schicht keine Fälle hatte: Die Beutelzählung
nahm als Startauslage die Attrappe statt der eingegebenen und ließ die
Nachfüllung nach Harmonys eigenem Zug aus; und bei leerem Beutel blieb das
genommene Auslagefeld mit seinen Steinen stehen, sodass die Engine mit
Steinen rechnete, die niemand nehmen kann. Dazu die Begründung: Sie hielt
Erwartungswerte für Punkte und rechnete Aussichten doppelt herunter, weil
`Term` seine Art nicht kannte. Jetzt trägt `Term.kind` die Art, `gain` und
`chance` als Zahlen.

**Seit dem 2026-09-30 gibt es einen Zustand statt zwei.** `GameState`
umschließt einen `EngineState` (`knowledge`) und hält nur, was die Engine
nicht braucht: die Namen der Sitzordnung und wer am Zug ist. Ereignisse
tragen sich über `recordTurn`, `recordOwnTurn` und `correct` in der Engine ein
(`EngineState+Record.swift`); die Brücke, die zwischen zwei Zuständen
übersetzte, ist weg, die Beutelzählung entsteht ohne Umweg. Geprüft ist das
zweifach: `RecordEquivalenceTests` spielt Partien am `Table` und trägt sie
ein — die Sicht muss Zug für Zug der von `Table.view(for:)` gleichen —, und
vor dem Umbau wurde von 152 Stellungen aus vier erzeugten Partien festgehalten,
was die Engine bekommt; danach war es Zeile für Zeile dasselbe. `Table.play`
und `SelfPlay` benutzen den Kern **nicht**: Sonst wäre der Abgleich kein
zweiter Weg mehr, und die Reihenfolge von Auslage und offenen Karten, die
Gleichstände der Suche mitbestimmt, hätte sich für `HarmonyMatch` geändert.

**Seit dem 2026-09-25 beginnt die App mit einem Start-Bildschirm** nach der
Startanimation: Partie fortsetzen oder neu beginnen, dazu *Spielstärke* und
*Über Harmony* mit Versionsnummer. Unter *Spielstärke* lassen sich alle
Stellschrauben der Engine einstellen, die eine Frage am Tisch beantworten —
Vorhersage des Spielendes, Bedenkzeit, Kartenplatz-Preis und die vier
geschätzten Gewichte (`EngineSettings` im Engine-Paket, gespeichert in
`UserDefaults`, je Suche frisch gelesen). Bewusst nicht einstellbar sind
`Weights.pointsNow` als Maßstab der übrigen und die Annahmen über das Spiel
selbst, etwa die Stapelanteile der Vorhersage; Begründung am Kopf von
`EngineSettings.swift`.

**Seit dem 2026-10-03 rechnet die Bewertung den Würfel danach mit**
(`Weights.followUp`, Standard 1, `followUpDepth` 1): je Karte wird der beste
Anwärter als gebaut gedacht und der beste für den **übernächsten** Würfel
gesucht, gemeinsame Steine einmal gezählt. Gemessen mit `HarmonyMatch` über
beide Seiten und zwei bis vier Spielerinnen: gegen null rund +2 bis +9
Punkte je Partie; 0,5 und 1,0 sind nicht zu trennen, 1,5 und Tiefe 3 bringen
nichts mehr. Es kostet rund 40 Prozent Rechenzeit, **auf dem Gerät noch nicht
nachgemessen** (siehe unten: 30,2 s im ersten Zug bei Tiefe 3); unter *Spielstärke* → „Würfel danach" lässt es sich
abschalten, mit Gewicht und Tiefe 1 bis 3. In `HarmonyMatch` ist der alte
Standard `ohne-folgewuerfel`. Einzelheiten in `docs/ideen-vorgemerkt.md`.

**Seit dem 2026-09-23 läuft Selbstspiel** (`HarmonySelfPlay`): Harmony gegen
würfelnde Mitspielerinnen, Varianten der Gewichte gepaart auf denselben
Partien verglichen. Als Erstes gemessen und eingebaut ist ein **Preis für
freie Kartenplätze** — vorher nahm Harmony in den ersten vier Zügen jede
Karte, weil Nehmen in der Bewertung nichts kostete. Mit Preis
`[10, 6, 2,5, 0]` holt sie +3,4 ± 0,7 Punkte je Partie (250 Paare, beide
Seiten, zwei bis vier Spielerinnen); Seite B allein ist unentschieden.
Einzelheiten in `docs/06-durchstich.md` unter *Der Preis eines
Kartenplatzes*. Eine Runde von 400 Partien dauert auf dem Mac gut zwei
Stunden:

```bash
cd HarmonyRules && swift run -c release HarmonySelfPlay --games 40 --take 0.45 --variants ohne,standard -v
```

**Seit dem 2026-09-27 spielen auch Engines gegeneinander** (`HarmonyMatch`):
zwei bis vier, jede mit eigenen `EngineSettings`, jede nur mit dem Wissen,
das Harmony am Tisch hätte. Jede Austeilung wird in allen Sitzordnungen
gespielt, und ein **Schiedsrichter** (`HarmonyTable/Referee.swift`) prüft
jeden Zug gegen den ganzen Tisch — Auslagefeld, Steine, Stapel, Karte,
Kartenlimit, Würfel und Lebensraum — und nach jedem Zug die volle
Steinbilanz. Eine beanstandete Partie wird gemeldet, nicht gezählt. Eine
Partie zu zweit dauert auf einem Kern gut sieben Minuten; acht laufen
nebeneinander. Erste Messung: Der Kartenplatz-Preis hält auch gegen eine
echte Engine, +3,5 ± 1,1 Punkte zu zweit (80 Partien, nichts beanstandet).

```bash
cd HarmonyRules && swift run -c release HarmonyMatch --plaetze standard,ohne-kartenplatz --partien 40 -v
```

**Gespielt zu werden findet Lücken, die kein Prüffall findet.** Am
2026-09-22 drei Stück, alle in `docs/06-durchstich.md` unter *Zwei Lücken,
am Tisch gefunden*. Am Tisch aufgefallen: Die Bewertung kannte für Gebäude
**keine Aussicht** und schob sie deshalb in die Ecken, wo drei Farben
unmöglich sind; und `ownTurnsLeft` zählte nur den Beutel, während in
Wahrheit der eigene Spielplan die Partie beendet — Harmony rechnete durchweg
mit etwa der doppelten Restzeit und schloss darum nichts ab. Beim Nachzählen
kam die dritte dazu: Dieselbe Lücke bestand für **Bergnachbarschaft,
Feldgruppe und Baumhöhe**. Alle vier tragen jetzt `Evaluator.dormant`
gemeinsam — etwas, das 0 zählt und auf Steine auf noch offenen Feldern
wartet —, und sie teilen sich ein Steinbudget von `3 · ownTurnsLeft`, weil
ihre Summe sonst mehr verspricht, als Züge hergeben.

**Das Spielende wird vorhergesagt**, seit dem 2026-09-22 auch für die
fremden Spielpläne: aus den Steinen, die jede Mitspielerin genommen hat
(`EndForecast`). Die Vorhersage steuert die Bewertung und steht in „Harmony
ist am Zug" über dem Brett; ihre Stapelwerte sind geschätzt, nicht geeicht.
Einzelheiten in `docs/06-durchstich.md` unter *Das Ende der Partie*.

**Die Rechenzeit war das große Problem und ist es nicht mehr.** Am
2026-09-20/21 sind fünf Hebel gebaut und jeweils auf dem Gerät gemessen
worden: im Release bauen (Faktor 5,8), Legungsabhängiges einmal je Legung
statt sechsmal (2,5), die Nachbarschaft als Tabelle (1,15), die Legungen auf
mehrere Kerne verteilen (2,3) und inkrementell bewerten (2,1 bis 3,0). Dazu
das Sieben der Anwärter über einen Würfel hinweg, das den teuersten Fall
halbierte.

Auf dem iPhone 15 Pro Max, Release-Bau:

| Stellung | Züge | Zeit |
| --- | --- | --- |
| halbvolles Brett | 12.270 | ~1 s |
| Harmonys erster Zug | 235.290 | 9 s |
| 6 Steine, 2 Karten | 112.085 | 3,5 s |
| 3 Karten, fast leerer Plan | 401.856 | **24 s** |

Gemessen vor der Vorhersage des Spielendes; mit ihr rechnet die Bewertung
auf dem Mac rund zehn Prozent länger.

**Nachgemessen am 2026-10-03 auf dem Gerät „Zackebuh“** (von Hauke
gemeldet, `-logSearch`): Harmonys erster Zug mit Vorhersage und Würfel danach
in Tiefe 3 braucht **30,2 s bei 321.816 Zügen**. Das gilt als akzeptabel, weil
spätere Züge viel weniger Züge prüfen. Der Standard (Tiefe 1) wurde nicht
einzeln gemessen und liegt darunter, da Tiefe 3 auf dem Mac etwa die doppelte
Zeit von Tiefe 1 braucht.

**Der teuerste Fall ist nicht der leerste Plan**, sondern drei Karten in der
Hand auf offenem Plan: Dort legen sechs von zehn Zügen einen Würfel. Keine
gemessene Stellung liegt noch über der halben Minute aus Szenario 2. Der
Abkürzen-Knopf bleibt dennoch — 24 Sekunden sind kein Abstand, und eine
Suche muss abbrechbar sein, sobald sich die Stellung ändert.

Was offen ist, steht in `docs/06-durchstich.md` unter *Fünf Abhilfen*: die
Landschaft wird weiter je Legung ganz gerechnet und ist damit der größte
Posten des Vorrechnens.

**Eine Regelfrage ist noch offen**, aufgeworfen beim Spielen am 2026-09-21
und in `docs/ideen-vorgemerkt.md` festgehalten: dass die Bewertung nur die
Karten in Harmonys Hand kennt, nie die offenen. Die zweite, ob ein Gebäude
ohne drei Farben ringsum 0 oder −2 zählt, ist am 2026-09-22 geklärt — die
Broschüre bestätigt 0, wie Regeltext und Code es bereits umsetzen. Was in
Phase 5 offen blieb, führt `docs/05-ui.md` am Ende auf.

**Fürs Gerät `-configuration Release` bauen.** Das Schema baut beim
Laufenlassen Debug, und Debug ist hier sechs- bis achtmal langsamer. Die
Zahlen oben gelten nur für den Release-Bau.
