# Vorgemerkte Ideen

Beobachtungen, die beim Arbeiten an einer Phase anfielen, aber in eine spätere
gehören. Hier geparkt, damit sie weder verlorengehen noch die laufende Phase
entgleisen lassen.

Nichts hiervon ist entschieden.

## Für Phase 3 — Funktionsumfang

**Wie viel weiß Harmony über die Mitspieler?** Das Partieende kann auch ein
fremdes Tableau auslösen. Die Obergrenze der Partiedauer kennt Harmony
kostenlos aus dem Zugzähler; Eingabeaufwand lohnt also nur noch für die Frage,
ob jemand **früher** fertig wird. Siehe `regeln-basisspiel.md`.

**Mitzählen, was im Beutel liegt.** Die Farbverteilung der 120 Steine ist
bekannt. Wer mitzählt, weiß gegen Spielende recht genau, was noch kommen kann.
Das ist echte Spielstärke, kostet aber Eingaben über die Züge der anderen.

## Für Phase 4 — Daten und Architektur

**Karten brauchen einen stabilen Identifikator.** Die Karten tragen weder
Namen noch Nummern; unsere Etiketten sind frei erfunden. Eine Nummerierung ist
robuster als Namen, sobald alle 32 erfasst werden.

**Karten sind nicht über ihre Gesamtpunktzahl vergleichbar.** Die Biene bringt
mit zwei Würfeln 8 und 18, das Erdmännchen mit vieren 2/5/9/14. Maßgeblich ist
der **Zuwachs pro gelegtem Würfel** im Verhältnis zur Schwierigkeit des
Musters, nicht die Summe.

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

**Bildsymbole statt Namen.** Karten am Tisch über ein kleines Tierbild
auszuwählen ist schneller und sicherer als über einen Namen, den sich niemand
merkt. Die Originalillustrationen sind allerdings geschützt — selbstgezeichnete
Silhouetten oder Piktogramme erfüllen denselben Zweck ohne dieses Problem.
