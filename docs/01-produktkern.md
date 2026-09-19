# Phase 1 — Produktkern

Status: abgeschlossen, Stand 2026-09-18

## Was Harmony ist

Harmony ist eine iPhone-App, die einen zusätzlichen Mitspieler für eine
Partie des Brettspiels **Harmonies** stellt. Die Partie findet am echten
Tisch mit echtem Material statt. Die App verwaltet kein digitales Spiel,
sondern das Wissen eines einzelnen Spielers: ihr eigenes Tableau und die
geteilten Auslagen.

Der Ablauf pro Zug:

1. Die menschlichen Spieler geben den veränderten Spielzustand ein
   (Bausteinauslage, verfügbare Tierkarten).
2. Harmony berechnet ihren besten Zug.
3. Die App zeigt den Zug an und begründet ihn.
4. Ein Mensch führt den Zug stellvertretend auf dem echten Brett aus.

## Was Harmony nicht ist

- **Keine Digitalfassung von Harmonies.** Es gibt keinen Modus, in dem
  Menschen gegeneinander in der App spielen.
- **Kein Regellehrer.** Die App erklärt das Spiel nicht und prüft die Züge
  der Menschen nicht.
- **Kein Punktezähler für alle.** Harmony kennt ihr eigenes Ergebnis, nicht
  zwingend das der anderen.
- **Kein Online-Dienst.** Alles läuft lokal auf dem Gerät.

## Leitentscheidungen

| Frage | Entscheidung | Begründung |
| --- | --- | --- |
| Publikum | Noch offen; Konzept so anlegen, dass eine Veröffentlichung möglich bleibt | Die Entscheidung muss jetzt nicht fallen, darf aber nicht durch frühe Festlegungen verbaut werden |
| Verfahren | Klassische Spielbaumsuche mit handgeschriebener Bewertungsfunktion. Kein ML, keine gelernten Modelle | Jede Teilwertung ist benennbar — Voraussetzung für das Transparenzziel |
| Umfang | Nur Basisspiel umsetzen, Kartenformat erweiterbar entwerfen | Kleinste vollständige Datenbasis, ohne spätere Erweiterungen zu verbauen |
| Spielstärke | So stark wie möglich | Harmony soll ein ernstzunehmender Gegner sein, kein Platzhalter |

## Qualitätskriterien

Drei Eigenschaften entscheiden, ob die App taugt. Sie stehen bewusst in
dieser Reihenfolge, weil die erste die anderen begrenzt.

**Eingabeeffizienz.** Jede Sekunde Eingabe ist eine Sekunde, in der niemand
spielt. Die App konkurriert mit dem Brettspiel um die Aufmerksamkeit am
Tisch und muss sich dieser Konkurrenz entziehen. Das ist ein härteres
Kriterium als bei einer gewöhnlichen App.

**Transparenz.** Ein undurchschaubarer Bot ist am Spieltisch kein
Mitspieler, sondern ein Orakel: Man kann ihm nicht widersprechen und nicht
von ihm lernen. Intern berechnete Wertungen sollen sichtbar sein.

**Spielstärke.** Harmony soll so gut spielen, wie es unter den beiden
vorigen Bedingungen möglich ist.

## Spannungsfeld

Die drei Kriterien ziehen nicht in dieselbe Richtung. Diese Konflikte sind
in Phase 3 und 4 zu entscheiden, nicht wegzudefinieren.

**Stärke gegen Eingabeeffizienz.** Harmonies läuft pro Spieler weitgehend
lokal ab, geteilt sind nur Bausteinauslage und Tierkarten. Deshalb kommt
Harmony mit dem Wissen über die eigenen Bereiche grundsätzlich aus. Eine
stärkere Engine wüsste allerdings gern mehr: welche Tierkarte ein Mitspieler
ansteuert, wie nah jemand am Spielende ist, welche Bausteine andere
brauchen. Jede dieser Informationen kostet Eingabezeit. Wo die Grenze liegt,
ist eine Produktentscheidung.

**Stärke gegen Transparenz.** Je tiefer die Suche, desto schwerer lässt sich
das Ergebnis in einem Satz begründen. Eine Bewertungsfunktion mit vielen
fein austarierten Termen ist präzise, aber nicht mehr am Tisch erklärbar.
Möglicher Ausweg: die Begründung auf die größten Beiträge zur Gesamtwertung
beschränken.

## Nicht gewählt, weil

- **Einfache Regelheuristik ohne Suche** — wäre am leichtesten zu erklären,
  widerspricht aber dem Stärkeziel.
- **Erweiterungen von Anfang an** — die Kartenerfassung wäre ein eigenes
  Arbeitspaket und würde den ersten spielbaren Stand verzögern.
- **Einstellbare Spielstärke** — nicht ausgeschlossen, aber kein Ziel für
  v1; eine drosselbare Engine ist eine Zusatzanforderung an das Verfahren.

## Offene Punkte

1. **Zufall.** ✅ Erledigt in Phase 4: Die Engine ist deterministisch.
   Gewählt wurde Expectimax über die Beutelzüge — der Beutelinhalt ist
   bekannt, es lässt sich abzählen statt Stichproben zu ziehen. Siehe
   `04-architektur.md`.
2. **Marke und Kartendaten.** Spielregeln als solche sind nicht
   urheberrechtlich geschützt, Kartentexte, Namen, Illustrationen und die
   Marke sind es. Relevant erst bei einer Veröffentlichung, prägt aber schon
   jetzt die Struktur der Kartendaten.

Der zuvor hier vermerkte Punkt „Regelquelle“ ist erledigt: Anleitung und
Spielmaterial liegen vor. Die Erfassungsmethodik regelt `00-methodik.md`.
