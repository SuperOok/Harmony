---
name: spielstaerke
description: Arbeit an Harmonys Spielstärke (HarmonyRules/Sources/HarmonyEngine): Bewertung, Gewichte, Suche, Vorhersage des Spielendes, EngineSettings, Messungen mit HarmonyMatch und HarmonySelfPlay, Rechenzeit, die Seite Spielstärke in der App. Beim Ändern oder Messen der Engine laden, nicht bei Animationen, Regeln oder reiner App-Logik.
---

# Spielstärke

Harmony wählt ihren Zug, indem die Suche jede Stellung nach dem Zug bewertet
(`Evaluator`). Was die Stärke ändert, ist fast immer ein Posten oder ein
Gewicht in dieser Bewertung. Gemessen wird, indem Engines mit verschiedenen
Einstellungen gegeneinander spielen. Die Ergebnisse stehen in den Dokumenten,
nicht hier: `docs/ideen-vorgemerkt.md` (jede Messung mit Zahlen, am Ende der
Abschnitte „Offen aus Phase 6"), `docs/stand.md` (Geschichte der Phase 6),
`docs/06-durchstich.md` (Begründungen und Rechenzeit). Erst dort nachlesen, ob
eine Frage schon gemessen ist.

## Wo was liegt (`HarmonyRules/Sources/`)

- `HarmonyEngine/Evaluation.swift`: die Bewertung in Posten — Punkte jetzt,
  Anwärter je Karte (`candidateTerms`), Würfel danach (`followUps`), offene
  Karten (`openCardTerm`), Landschaften, schlafende Landschaften
  (`dormant`), Vielfalt, freie Kartenplätze. `Weights` steht oben in der
  Datei. `prepare` rechnet einmal je Legung vor (`Prepared`).
- `HarmonyEngine/Moves.swift`, `Search.swift`: Züge und Suche, mehrere Kerne.
- `HarmonyEngine/EndForecast.swift`: Vorhersage, wann die Partie endet.
- `HarmonyEngine/EngineSettings.swift`: was die App einstellbar macht. Der
  Standard wird aus `Weights()` gelesen, nicht kopiert.
- `HarmonyRules/Habitat.swift`: Muster einer Karte auf dem Brett,
  `combinedRequirement` für gemeinsame Steine.
- `HarmonyTable/`: der ganze Tisch samt Schiedsrichter. `HarmonyMatch`: 2 bis
  4 Engines gegeneinander. `HarmonySelfPlay`: gegen würfelnde Gegnerinnen.
- App: `MyApp/Start/SettingsView.swift` (Spielstärke), `MyApp/Game/` (Suche
  und Anzeige).

## Eine Änderung machen

1. **Als abschaltbares Gewicht**, Standard = bisheriges Verhalten. Dann ist
   die Auswertung bei 0 oder Standard Zug für Zug dieselbe, und der Vergleich
   hat eine Basis.
2. **Das Gewicht an zwei Stellen verdrahten:** `Weights` und
   `EngineSettings` (Feld, `weights`, `init(from:)` mit `decodeIfPresent`,
   damit gespeicherte Einstellungen nicht verloren gehen), dazu der Schlüssel
   in `HarmonyMatch` (`Variant.init`, Kopfkommentar, Kopfzeile des Laufs).
3. **Zwei Prüffälle** in `EvaluationTests`: ohne das Gewicht kein Posten, mit
   ihm ein Posten und die erwartete Richtung. Ein Fall, der nur „größer als"
   prüft, muss die Geometrie so wählen, dass ein Unterschied wirklich
   entsteht — bei Mustern gibt es oft einen gleich guten Anwärter woanders.
4. **Vorgewogenes beachten:** `Prepared` gilt für eine Legung. Was ein Posten
   daraus nimmt, muss `untouched`/`laid` prüfen, sonst gilt ein Anwärter, dessen
   Feld ein Würfel dieses Zuges gerade genommen hat.
5. **Messen**, dann Standard ändern oder lassen, dann `AGENTS.md`/`docs/`
   nachführen. Einen alten Standard als `ohne-…` in `HarmonyMatch` behalten.

## Messen mit `HarmonyMatch`

```bash
cd HarmonyRules && swift build -c release --product HarmonyMatch
.build/release/HarmonyMatch --plaetze standard,standard+folgewuerfel=0.5 \
    --partien 16 --seite b -v --protokoll lauf.jsonl > lauf.log
```

- `--plaetze` 2 bis 4 Einstellungen, `--seite a|b`, `--partien` ist die Zahl
  der **Austeilungen**; jede wird in allen Sitzordnungen gespielt, also
  Partien = Austeilungen × Plätze. Varianten: `standard`, `ohne-kartenplatz`,
  `ohne-vorhersage`, `ohne-folgewuerfel`, Änderungen nach `+`
  (`standard+preis=7+outlook=0.7`).
- **Lesen:** „Paarweise" ist der Vergleich je Austeilung über alle
  Sitzordnungen, ± ist der Standardfehler. Bei 8 Austeilungen sind
  Unterschiede unter etwa 3 Punkten nicht von Rauschen zu trennen; erst 30 und
  mehr tragen Aussagen über 1 bis 2 Punkte. Läufe mit gleicher Einstellung
  auf mehreren Plätzen sind eine Gegenprobe. Streuen zwei Läufe stärker, als
  ihre Fehler erlauben, zählt die Streuung (so geschah es bei r2 gegen r5).
- **Aufschlüsselung** am Ende: Punkte je Landschaft, Kartenpunkte, fertige
  Karten, gelegte und offene Würfel, freie Felder, gesperrte Muster,
  geteilte Felder, Zentren. Sie sagt, wo Punkte liegen bleiben, nicht, wer
  gewinnt.
- **Dauer:** zu zweit gut 7 Minuten je Partie und Kern, acht Partien laufen
  nebeneinander; 32 Partien zu viert etwa 70 bis 110 Minuten. Zwei Läufe
  gleichzeitig laufen langsamer; die Verhältnisse der Zeiten gelten, die
  Werte nicht. Die Auswertung erscheint erst am Ende; mit `-v` kommt je Partie eine Zeile.
- **Warten** in einem Hintergrundbefehl mit
  `until grep -q "^Schiedsrichter:" lauf.log; do sleep 30; done`, nicht mit
  `sleep`. `timeout` gibt es auf macOS nicht.
- Eine Partie mit Beanstandung des Schiedsrichters wird gemeldet, nicht
  gezählt. Sie ist ein Fehler im Code, nicht im Ergebnis.

## Rechenzeit auf dem Gerät

`-logSearch` ist der einzige Weg an die Zeit; Anleitung und Befehle stehen in
`AGENTS.md` unter den Startparametern. Dazu:
- Release bauen (`-configuration Release`), Debug ist sechs- bis achtmal langsamer.
- Das Gerät muss **entsperrt** sein und wach bleiben, sonst bricht die Suche ab
  und der Lauf meldet „abgebrochen". Eine Zeit zählt nur bei „vollständig".
- `-longCards` überspringt den Start-Bildschirm und lädt trotzdem den
  Spielstand; `--terminate-existing` beendet die laufende App und damit eine
  Partie, die gerade bedient wird.
- Einen eigenen Spielstand für eine Stellung vorher hineinlegen (Befehl in
  `AGENTS.md`), den ursprünglichen danach zurückkopieren.

## Fallstricke

- **Bewertung und Suche sind bit-genau zu halten**, wo das Gewicht 0 ist.
  `Table.play` und `SelfPlay` benutzen den Kern bewusst nicht (zweiter Weg zum
  Abgleich, Reihenfolge von Auslage und offenen Karten bestimmt die
  Gleichstände der Suche).
- Ein Gewicht, das Rechenzeit kostet, muss sich **ausschalten** lassen, ohne
  dass die Rechnung trotzdem läuft (`guard weights.x > 0`).
- Eine Messung nennt Seite, Spielerzahl, Zahl der Partien und den
  Standardfehler. Ein Ergebnis ohne diese Angaben gehört nicht in die Doku.
- Die UI-Tests (`tools/uitests.sh`) laufen nicht, solange die Live-Ansicht des
  Simulators offen ist; vor einer Änderung an der Spielstärke-Seite trotzdem
  laufen lassen.

## Offen

Ideen und was noch zu messen ist, steht in der Memory-Datei zur Spielstärke und
in `docs/ideen-vorgemerkt.md`: Tiefe 2 der Folgewürfel, Gewicht 1,5 mit
Abschlag je Stufe breit, Rechenzeit der Folgewürfel auf dem Gerät, Tempo am
Ende, Behinderung der Mitspielerinnen.
