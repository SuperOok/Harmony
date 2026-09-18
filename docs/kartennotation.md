# Erfassungsnotation für Tierkarten

Wie wir die 32 Tierkarten des Basisspiels erfassen. Festgelegt am 2026-09-18.

## Abgrenzung

Diese Notation ist **kein Speicherformat**. Sie ist für Menschen gemacht:
schnell zu tippen, laut vorlesbar, vor allem aber prüfbar. Wie die Engine die
Karten intern hält, entscheidet Phase 4; dazwischen liegt eine Umwandlung.

Beide Formate zu vermischen würde eines von beiden verderben.

## Vokabular

Aus den Stapelregeln ergibt sich ein abgeschlossener Zeichensatz:

| Zeichen | Bedeutung |
| --- | --- |
| `Wasser` | 1 blauer Spielstein |
| `Feld` | 1 gelber Spielstein |
| `Baum1` `Baum2` `Baum3` | grün auf 0, 1 oder 2 braunen Steinen |
| `Berg1` `Berg2` `Berg3` | Stapel aus 1, 2 oder 3 grauen Steinen |
| `Gebäude` | rot auf einem roten, braunen oder grauen Stein |

Mehr wird nicht gebraucht:

- `Gebäude` trägt **keine** Höhenangabe. Ein Gebäude ist immer genau zwei
  Steine hoch, und welcher Stein unten liegt, ist für das Muster gleichgültig.
- Es gibt **kein** Zeichen für „leer“. Unbelegte Zellen eines Musters sind
  grundsätzlich „egal“ — deshalb dürfen sich Lebensräume überlappen.
- Es gibt **kein** Zeichen für einen nackten braunen Stein. Solche Zellen
  kommen auf Karten nicht vor.
- Der Farbstreifen der Karte wird **nicht** erfasst. Er erinnert nur an die
  Farbe des Zielsteins und ergibt sich aus dessen Landschaftstyp.

## Schablone

Muster werden über eine feste, nummerierte Hex-Schablone diktiert. Die Felder
sind flat-top-Sechsecke wie auf dem Spielplan, die geraden Spalten sitzen eine
halbe Zelle tiefer:

```
  1       7
      4      10
  2       8
      5      11
  3       9
      6      12
```

Vier Spalten zu drei Feldern reichen für die bislang gesehenen Muster. Braucht
eine Karte mehr Platz, wird die Schablone nach rechts oder unten erweitert und
die Erweiterung hier vermerkt.

Die absolute Lage innerhalb der Schablone ist bedeutungslos — ein Muster ist
eine Form, kein Ort. Wir legen es der Einfachheit halber möglichst weit nach
oben links.

## Format je Karte

```
Karte:   Pinguine
Muster:  1=Wasser  2=Wasser  4=Berg1
Würfel:  auf 4
Punkte:  4 / 10 / 16
```

- **Muster** listet nur die belegten Zellen.
- **Würfel** nennt die Zelle, auf die der Tierwürfel gelegt wird. Sie muss im
  Muster vorkommen.
- **Punkte** stehen in Leserichtung der Karte, also **von unten aufsteigend**.
  Ihre Anzahl ist zugleich die Anzahl der Tierwürfel der Karte; ein separates
  Feld dafür wäre redundant.

Das obige Beispiel ist **erfunden** und dient nur der Veranschaulichung des
Formats. Die Punktwerte 4 / 10 / 16 stammen aus Haukes Beschreibung der
Pinguinkarte, das Muster nicht.

## Drehungen

Laut Anleitung darf ein Lebensraummuster beliebig ausgerichtet sein; die
Abbildung zeigt dazu sechs Varianten, also die sechs Drehungen eines
Hexmusters. Gespiegelte Lagen sind nicht vorgesehen.

Erfasst wird deshalb genau **eine kanonische Lage** je Karte, nämlich die auf
der Karte abgebildete. Die sechs Drehungen erzeugt die Engine selbst. Sie von
Hand zu erfassen wäre sechsfache Arbeit und sechsfaches Fehlerrisiko.

## Prüfschleife

Das Fehlerrisiko liegt nicht im Tippen, sondern im Verstehen. Deshalb gilt für
jede erfasste Karte:

1. Hauke diktiert die Karte im obigen Format.
2. Claude zeichnet das Muster **aus der Notation zurück** in ein Diagramm:

```
  Wasser      ·
        Berg1      ·
  Wasser      ·        ← Würfel auf Berg1
```

3. Hauke vergleicht das Diagramm mit der Karte in der Hand.

Der Rückweg entkoppelt „richtig diktiert“ von „richtig verstanden“. Ohne ihn
würde ein Missverständnis erst in der Engine auffallen, wo niemand mehr die
Kartendaten verdächtigt.

## Reihenfolge der Erfassung

Zuerst die **unangenehmsten** Karten, nicht die einfachsten: Nur an ihnen
zeigt sich, ob Vokabular und Schablone tragen. Die Fleißarbeit über alle 32
Karten beginnt erst nach dem Durchstich aus Phase 6, wenn die Kette von der
Notation bis zum Zugvorschlag nachweislich funktioniert.
