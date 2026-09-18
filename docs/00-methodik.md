# Phase 0 — Methodik

Wie wir dieses Projekt entwickeln. Festgelegt am 2026-09-18.

## Phasenfolge

Jede Phase beantwortet eine Frage, die die nächste voraussetzt, und endet
mit einem Dokument und einem Commit.

| | Phase | Kernfrage | Ergebnis |
| --- | --- | --- | --- |
| 1 | Produktkern | Für wen löst Harmony welches Problem, und was ausdrücklich nicht? | `01-produktkern.md` ✅ |
| 2 | Szenarien | Wie sieht die Nutzung konkret aus? | `02-szenarien.md` |
| 3 | Funktionsumfang | Was gehört in v1, was später, was nie? | `03-funktionsumfang.md` |
| 4 | Daten & Architektur | Welche Entitäten, welche Persistenz, welches Suchverfahren? | `04-architektur.md` |
| 5 | Oberfläche | Welche Ansichten, welche Eingabewege? | `05-ui.md` |
| 6 | Durchstich | Funktioniert die Kette von der Kartennotation bis zum Zugvorschlag? | Lauffähiger Code, wenige Karten |
| 7 | Kartenerfassung | Alle Tierkarten systematisch erfassen | `tierkarten.md`, alle 32 ✅ |

Phase 7 ist **vorgezogen worden** und bereits abgeschlossen. Der Grund für
ihre späte Einordnung war das Risiko, nach vollständiger Erfassung noch das
Format wechseln zu müssen. Dieses Risiko sank mit jeder Karte, an der die
Notation unverändert trug; nach einem Dutzend Karten war es klein genug, um
durchzuarbeiten. Ob Phase 6 die Daten unverändert übernehmen kann, ist damit
nicht bewiesen — ein Umbau beträfe aber nur noch die Umwandlung in die
interne Form, nicht die Erfassung selbst.

Ab Phase 6 wird Code geschrieben, vorher nicht. Der Übergang läuft über den
Plan-Modus: erst ein Umsetzungsplan zur Freigabe, dann Umsetzung.

## Warum die Kartenerfassung zuletzt kommt

Die Legeregeln der Tierkarten sind grafische Muster auf den Karten. Sie zu
erfassen ist die größte Einzelarbeit des Projekts — und sie ist wertlos,
wenn sich die gewählte Notation hinterher als unzureichend erweist.

Deshalb: erst eine Notation entwerfen, an wenigen bewusst schwierigen Karten
erproben, dann einen vollständigen Durchstich bis zum Zugvorschlag bauen.
Erst wenn diese Kette nachweislich trägt, lohnt sich die Fleißarbeit. Ein
Formatwechsel nach fünf erfassten Karten kostet nichts, nach allen Karten
kostet er das Projekt.

Nebeneffekt: Der Durchstich kann ein Erfassungswerkzeug enthalten, das die
Fleißarbeit danach erheblich beschleunigt.

## Arbeitsweise

**Fragen statt raten.** Wo Claude etwas annimmt, wird es als Annahme
markiert, damit es widerlegt werden kann.

**Entscheidungen bekommen eine Begründung.** Nicht nur was festgelegt wurde,
sondern warum — sonst lässt sich später nicht beurteilen, ob eine Festlegung
noch trägt.

**Verworfenes bleibt stehen.** Jedes Dokument endet mit einem Abschnitt
„Nicht gewählt, weil …“. Das verhindert, dieselbe Option zweimal zu prüfen.

**Rückwärtsgehen ist erlaubt.** Zeigt sich in Phase 4, dass Phase 2 zu
optimistisch war, wird Phase 2 geändert. Die Reihenfolge ist eine Denkhilfe,
kein Genehmigungsverfahren.

**Keine Regeln aus dem Gedächtnis.** Claudes Kenntnis von Harmonies ist
lückenhaft und darf nicht Grundlage der Regel-Engine werden. Jede Regel
stammt aus der Anleitung oder vom Spielmaterial.

## Sprachregelung

Dokumentation und Konzeptdokumente auf Deutsch, weil wir darin denken und
Nuancen in der eigenen Sprache schärfer werden. Quellcode, Bezeichner und
Commit-Nachrichten auf Englisch.

## Ablage

Konzeptdokumente liegen in `docs/` und sind versioniert. Das Repository ist
öffentlich; Geschäftliches, Wettbewerbsanalysen und wörtliche Regeltexte des
Brettspiels gehören nicht hinein.
