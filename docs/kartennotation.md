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
  Steine hoch, und welcher Stein unten liegt, ist für das Muster gleichgültig. Die Brettnotation in `pruefverfahren.md` unterscheidet die drei
  Unterbauten sehr wohl — dort geht es um wirkliche Steine, hier um ein
  Muster, dem sie gleichgültig sind.
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
  11      31
      21      41
  12      32
      22      42
  13      33
      23      43
```

Eine Zelle heißt `<Spalte><Zeile>`, beide ab 1 gezählt und immer
zweistellig: erste Ziffer die Spalte von links, zweite die Zelle von oben
innerhalb dieser Spalte. Dieselbe Regel gilt für beide Spielplanseiten in
`regeln-basisspiel.md` — jede Spalte beginnt überall bei `.1`, es gibt
nichts weiter zu merken.

Vier Spalten zu drei Feldern reichen für die bislang gesehenen Muster. Braucht
eine Karte mehr Platz, wird die Schablone nach rechts oder unten erweitert und
die Erweiterung hier vermerkt.

Die absolute Lage innerhalb der Schablone ist bedeutungslos — ein Muster ist
eine Form, kein Ort. Wir legen es der Einfachheit halber möglichst weit nach
oben links.

## Format je Karte

```
Karte:   Beispieltier
Muster:  12=Wasser  21=Berg1
Würfel:  auf 21
Punkte:  3 / 8 / 14
```

- **Muster** listet nur die belegten Zellen.
- **Würfel** nennt die Zelle, auf die der Tierwürfel gelegt wird. Sie muss im
  Muster vorkommen.
- **Punkte** stehen in Leserichtung der Karte, also **von unten aufsteigend**.
  Ihre Anzahl ist zugleich die Anzahl der Tierwürfel der Karte; ein separates
  Feld dafür wäre redundant.

Die Würfelzahl **schwankt je Karte** — beobachtet wurden 3 und 4, laut Hauke
gibt es Karten mit bis zu 5. Die Punktleiste ist deshalb eine **Liste
variabler Länge**, keine feste Dreierstruktur. Die Untergrenze ist noch nicht
belegt.

Das obige Beispiel ist **erfunden** und dient nur der Veranschaulichung des
Formats. Echte Karten stehen in `animals.json`, der Ablageform.

### Der Name ist unsere Erfindung

Die Karten tragen **keinerlei aufgedruckten Identifikator** — weder Namen noch
Nummern. Das einzige Unterscheidungsmerkmal ist das Tierbild. Der Name im
Feld `Karte:` ist deshalb ein Etikett von uns, keine Eigenschaft der Karte.

Daraus folgt:

- Der Name muss **eindeutig** und am Bild **wiedererkennbar** sein, aber nicht
  zoologisch korrekt. „Affe“ genügt, solange es nur eine Affenkarte gibt.
- Eine **Nummerierung wird nicht eingeführt.** Sie wäre ein zweiter
  erfundener Identifikator neben dem ersten, ohne dessen Vorteil: Ein Name
  ist am Tisch vorlesbar und am Bild wiedererkennbar, eine Nummer nicht.
  `tools/pruefe-tierkarten.py` erzwingt die Eindeutigkeit der Namen, womit
  sie das leisten, was eine Nummer leisten sollte.

### Kurzform zum Diktieren

Die Langform oben ist die Diktierform. Abgelegt werden die Karten seit dem
2026-09-20 in `animals.json`, siehe `06-durchstich.md`; die Umsetzung von
der einen in die andere Form ist mechanisch. Zum Diktieren am Tisch gibt es
zusätzlich eine Kurzform in einer Zeile:

```
Panther: 11 B2 12 B2 13 F T 13 P 5 11
```

Gelesen als: Zellen 11 und 12 tragen je einen Baum der Höhe 2, Zelle 13 ein
Feld, der Tierwürfel liegt auf Zelle 13, die Punkte sind 5 und 11.

| Zeichen | Bedeutung |
| --- | --- |
| `W` | Wasser |
| `F` | Feld |
| `B1` `B2` `B3` | Baum |
| `S1` `S2` `S3` | Berg |
| `G` | Gebäude |
| `T <Zelle>` | Tierwürfel auf dieser Zelle |
| `P <Zahlen>` | Punkte, von unten aufsteigend |

Berg heißt `S1` bis `S3`: Die Ziffer ist die Höhe, der Buchstabe der Stein,
aus dem er besteht — ein Berg ist nichts als gestapelter Stein. `B` war für
ihn ohnehin nicht zu haben, das beansprucht der Baum. Der Tierwürfel heißt
`T`, weil **W** bereits an Wasser vergeben ist.
Ein Kürzel, das beim Diktieren nachgefragt werden muss, spart keine Zeit.

Das Gebäude behält dagegen sein `G`. Der zunächst befürchtete Zusammenstoß
mit „Gebirge" tritt nicht ein, sobald der Berg `M` heißt — die Befürchtung
rechnete die drei Kollisionen gleichzeitig, obwohl die erste die dritte
auflöst. Das hält `H` frei für Holz in der **Steinnotation**, die
`pruefverfahren.md` festlegt: Diese Notation beschreibt Landschaften,
jene die Farben, aus denen sie gebaut werden. Geteilt sind `W`, `F` und `S`.
Bei Blau und Gelb ist der Stein die Landschaft — auf ihnen darf nie
gestapelt werden. Bei Grau steht hier immer eine Höhenziffer dabei: `S2`
ist ein Berg aus zwei Steinen, `S` allein drüben ein einzelner grauer
Stein.

Claude überträgt die Kurzform in die Langform und zeichnet wie gehabt zurück;
die Prüfschleife bleibt unverändert.

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
  ·           ·
        Berg1      ·
  Wasser      ·        ← Würfel auf Berg1
```

3. Hauke vergleicht das Diagramm mit der Karte in der Hand.

Der Rückweg entkoppelt „richtig diktiert“ von „richtig verstanden“. Ohne ihn
würde ein Missverständnis erst in der Engine auffallen, wo niemand mehr die
Kartendaten verdächtigt.

## Reihenfolge der Erfassung

Zuerst die **unangenehmsten** Karten, nicht die einfachsten: Nur an ihnen
zeigt sich, ob Vokabular und Schablone tragen. Vorgesehen war, die
Fleißarbeit über alle 32 Karten erst nach dem Durchstich zu beginnen; sie
lief am 2026-09-19 durch, weil an Vokabular und Schablone über alle Karten
hinweg nichts zu ändern war. Die Sorge, die diese Reihenfolge begründet
hat, ist damit gegenstandslos.
