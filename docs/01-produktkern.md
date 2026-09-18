# Phase 1 — Produktkern

Status: abgeschlossen, Stand 2026-09-18

## Was Harmony ist

Harmony ist eine iPhone-App, die einen zusaetzlichen Mitspieler fuer eine
Partie des Brettspiels **Harmonies** stellt. Die Partie findet am echten
Tisch mit echtem Material statt. Die App verwaltet kein digitales Spiel,
sondern das Wissen eines einzelnen Spielers: ihr eigenes Tableau und die
geteilten Auslagen.

Der Ablauf pro Zug:

1. Die menschlichen Spieler geben den veraenderten Spielzustand ein
   (Bausteinauslage, verfuegbare Tierkarten).
2. Harmony berechnet ihren besten Zug.
3. Die App zeigt den Zug an und begruendet ihn.
4. Ein Mensch fuehrt den Zug stellvertretend auf dem echten Brett aus.

## Was Harmony nicht ist

- **Keine Digitalfassung von Harmonies.** Es gibt keinen Modus, in dem
  Menschen gegeneinander in der App spielen.
- **Kein Regellehrer.** Die App erklaert das Spiel nicht und prueft die
  Zuege der Menschen nicht.
- **Kein Punktezaehler fuer alle.** Harmony kennt ihr eigenes Ergebnis,
  nicht zwingend das der anderen.
- **Kein Online-Dienst.** Alles laeuft lokal auf dem Geraet.

## Leitentscheidungen

| Frage | Entscheidung | Begruendung |
| --- | --- | --- |
| Publikum | Noch offen; Konzept so anlegen, dass eine Veroeffentlichung moeglich bleibt | Die Entscheidung muss jetzt nicht fallen, darf aber nicht durch fruehe Festlegungen verbaut werden |
| Verfahren | Klassische Spielbaumsuche mit handgeschriebener Bewertungsfunktion. Kein ML, keine gelernten Modelle | Jede Teilwertung ist benennbar — Voraussetzung fuer das Transparenzziel |
| Umfang | Nur Basisspiel umsetzen, Kartenformat erweiterbar entwerfen | Kleinste vollstaendige Datenbasis, ohne spaetere Erweiterungen zu verbauen |
| Spielstaerke | So stark wie moeglich | Harmony soll ein ernstzunehmender Gegner sein, kein Platzhalter |

## Qualitaetskriterien

Drei Eigenschaften entscheiden, ob die App taugt. Sie stehen bewusst in
dieser Reihenfolge, weil die erste die anderen begrenzt.

**Eingabeeffizienz.** Jede Sekunde Eingabe ist eine Sekunde, in der niemand
spielt. Die App konkurriert mit dem Brettspiel um die Aufmerksamkeit am
Tisch und muss sich dieser Konkurrenz entziehen. Das ist ein haerteres
Kriterium als bei einer gewoehnlichen App.

**Transparenz.** Ein undurchschaubarer Bot ist am Spieltisch kein
Mitspieler, sondern ein Orakel: Man kann ihm nicht widersprechen und nicht
von ihm lernen. Intern berechnete Wertungen sollen sichtbar sein.

**Spielstaerke.** Harmony soll so gut spielen, wie es unter den beiden
vorigen Bedingungen moeglich ist.

## Spannungsfeld

Die drei Kriterien ziehen nicht in dieselbe Richtung. Diese Konflikte sind
in Phase 3 und 4 zu entscheiden, nicht wegzudefinieren.

**Staerke gegen Eingabeeffizienz.** Harmonies laeuft pro Spieler weitgehend
lokal ab, geteilt sind nur Bausteinauslage und Tierkarten. Deshalb kommt
Harmony mit dem Wissen ueber die eigenen Bereiche grundsaetzlich aus. Eine
staerkere Engine wuesste allerdings gern mehr: welche Tierkarte ein
Mitspieler ansteuert, wie nah jemand am Spielende ist, welche Bausteine
andere brauchen. Jede dieser Informationen kostet Eingabezeit. Wo die
Grenze liegt, ist eine Produktentscheidung.

**Staerke gegen Transparenz.** Je tiefer die Suche, desto schwerer laesst
sich das Ergebnis in einem Satz begruenden. Eine Bewertungsfunktion mit
vielen fein austarierten Termen ist praezise, aber nicht mehr am Tisch
erklaerbar. Moeglicher Ausweg: die Begruendung auf die groessten
Beitraege zur Gesamtwertung beschraenken.

## Nicht gewaehlt, weil

- **Einfache Regelheuristik ohne Suche** — waere am leichtesten zu
  erklaeren, widerspricht aber dem Staerkeziel.
- **Erweiterungen von Anfang an** — die Kartenerfassung waere ein eigenes
  Arbeitspaket und wuerde den ersten spielbaren Stand verzoegern.
- **Einstellbare Spielstaerke** — nicht ausgeschlossen, aber kein Ziel
  fuer v1; eine drosselbare Engine ist eine Zusatzanforderung an das
  Verfahren.

## Offene Punkte

1. **Regelquelle.** Die exakten Legeregeln aller Tierkarten sind das
   Herzstueck des Projekts. Es braucht eine belastbare Quelle; nichts davon
   darf aus dem Gedaechtnis rekonstruiert werden. Zu klaeren in Phase 2.
2. **Zufall.** Ausgeschlossen sind gelernte Modelle. Ob auch
   Zufallsverfahren wie Monte-Carlo ausgeschlossen sein sollen, ist offen.
   Reproduzierbarkeit wuerde das Debuggen und die Transparenz stuetzen.
   Zu klaeren in Phase 4.
3. **Marke und Kartendaten.** Spielregeln als solche sind nicht
   urheberrechtlich geschuetzt, Kartentexte, Namen, Illustrationen und die
   Marke sind es. Relevant erst bei einer Veroeffentlichung, praegt aber
   schon jetzt die Struktur der Kartendaten.
