# Phase 0 — Methodik

Wie wir dieses Projekt entwickeln. Festgelegt am 2026-09-18.

## Phasenfolge

Jede Phase beantwortet eine Frage, die die nächste voraussetzt, und endet
mit einem Dokument und einem Commit.

| | Phase | Kernfrage | Ergebnis |
| --- | --- | --- | --- |
| 1 | Produktkern | Für wen löst Harmony welches Problem, und was ausdrücklich nicht? | `01-produktkern.md` ✅ |
| 2 | Szenarien | Wie sieht die Nutzung konkret aus? | `02-szenarien.md` ✅ |
| 3 | Funktionsumfang | Was gehört in v1, was später, was nie? | `03-funktionsumfang.md` ✅ |
| 4 | Daten & Architektur | Welche Entitäten, welche Persistenz, welches Suchverfahren? | `04-architektur.md` ✅ |
| 5 | Oberfläche | Welche Ansichten, welche Eingabewege? | `05-ui.md` ✅ |
| 6 | Durchstich | Funktioniert die Kette von der Kartennotation bis zum Zugvorschlag? | `06-durchstich.md` ✅ — sie trägt, aber zu langsam |
| 7 | Kartenerfassung | Alle Tierkarten systematisch erfassen | `animals.json`, alle 32 ✅ |

Phase 7 ist **vorgezogen worden** und bereits abgeschlossen. Der Grund für
ihre späte Einordnung war das Risiko, nach vollständiger Erfassung noch das
Format wechseln zu müssen. Dieses Risiko sank mit jeder Karte, an der die
Notation unverändert trug; nach einem Dutzend Karten war es klein genug, um
durchzuarbeiten. Ob Phase 6 die Daten unverändert übernehmen kann, ist damit
nicht bewiesen — ein Umbau beträfe aber nur noch die Umwandlung in die
interne Form, nicht die Erfassung selbst.

Ab Phase 6 wird **Engine-Code** geschrieben, vorher nicht. Der Übergang
läuft über den Plan-Modus: erst ein Umsetzungsplan zur Freigabe, dann
Umsetzung.

Davon ausgenommen ist **Ansichtscode über Attrappendaten**. Der Satz war
gegen verfrühte Architektur gedacht, nicht gegen einen Klickdummy: Die
Eingabeeffizienz ist das erste Qualitätskriterium aus Phase 1 und lässt
sich nicht aufschreiben, nur antippen. Ein Dummy ohne Regeln dahinter kann
keine Architektur festzurren, aber er misst — in Antippern, siehe
`pruefverfahren.md`. Präzisiert am 2026-09-19, als der erste Dummy entstand.

**Ein Stück Regelcode ist trotzdem in Phase 5 entstanden**, und die
Reihenfolge hat das ausgehalten. Der Dummy musste Wertungen, Landschaften,
zulässige Stapel und die Steinbilanz *anzeigen*, und dafür mussten sie
gerechnet werden. Dieser Code liegt seit dem 2026-09-20 im Swift Package
`HarmonyRules/`, getrennt von den Ansichten und mit eigenen Tests —
also dort, wo Phase 4 ihn ohnehin verlangt, und nicht zwischen den Views.
Der Satz oben gilt weiter für das, wogegen er gerichtet war: Suche,
Zugvorschlag und Kartendaten beginnen mit Phase 6.

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

**Sollwerte stammen nicht aus dem Programm.** Ein erwarteter Wert, der aus
einem Programmlauf kommt, beschreibt nur, was das Programm gerade tut. Wie
geprüft wird, regelt `pruefverfahren.md`.

**Keine Regeln aus dem Gedächtnis.** Claudes Kenntnis von Harmonies ist
lückenhaft und darf nicht Grundlage der Regel-Engine werden. Jede Regel
stammt aus der Anleitung oder vom Spielmaterial.

## Sprachregelung

Dokumentation und Konzeptdokumente auf Deutsch, weil wir darin denken und
Nuancen in der eigenen Sprache schärfer werden. Quellcode, Bezeichner,
Kommentare und Commit-Nachrichten auf Englisch.

Ausgenommen sind **sichtbare Texte der Oberfläche**: Sie bleiben deutsch.
Damit liegen alle deutschen Zeichenketten an einer Stelle, falls die App
später internationalisiert wird, statt zwischen den Bezeichnern verstreut.

## Ablage

Konzeptdokumente liegen in `docs/` und sind versioniert. Das Repository ist
öffentlich; Geschäftliches, Wettbewerbsanalysen und wörtliche Regeltexte des
Brettspiels gehören nicht hinein.
