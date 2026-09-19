# Tierkarten

Erfasst nach `kartennotation.md`. Schablone:

```
  11      31
      21      41
  12      32
      22      42
  13      33
      23      43
```

**Status: 32 von 32 Karten — vollständig.** Die ersten neun dienten der
Erprobung der Notation; danach lief die Erfassung durch, obwohl
`00-methodik.md` die Fleißarbeit erst nach dem Durchstich aus Phase 6
vorsieht. An Vokabular und Schablone musste über alle 32 Karten hinweg nichts
geändert werden; die Sorge, die diese Reihenfolge begründet hat, ist damit
gegenstandslos geworden.

Jede hier verzeichnete Karte wurde zurückgezeichnet und gegen das
Spielmaterial bestätigt.

Zusätzlich prüft `tools/pruefe-tierkarten.py` den Bestand auf innere
Widersprüche: unbekannte
Steine, Würfelzellen außerhalb des Musters, nicht zusammenhängende Muster,
nicht steigende Punktleisten, doppelte Namen und identische Karten. Alle 32
Karten sind sauber.

## Formklassen

Die Muster wiederholen sich stark. Über alle 32 Karten treten nur **fünf**
Formen auf:

| Zellen | Form | Anzahl | Karten |
| --- | --- | --- | --- |
| `11,12` | zwei benachbarte Zellen | 10 | Erdmännchen, Frosch, Marienkäfer, Koala, Ente, Lachs, Fledermaus, Schwein, Adler, Eichhörnchen |
| `11,12,13` | Dreierkette | 7 | Wüstenfuchs, Otter, Hase, Echse, Lama, Panther, Krokodil |
| `11,12,21` | Dreieck aus drei paarweise benachbarten Zellen | 7 | Rochen, Flamingo, Affe, Papagei, Bär, Wolf, Igel |
| `12,21,32` | Mitte mit zwei Nachbarn unten links und unten rechts | 6 | Pinguin, Eisfuchs, Pfau, Maus, Eisvogel, Rabe |
| `12,21,22,32` | Mitte mit drei Nachbarn darunter | 2 | Waschbär, Biene |

Zwei Folgerungen für die Engine:

**Die Mustersuche muss nur fünf Formen kennen.** Die Vielfalt steckt in der
Füllung, nicht in der Geometrie. Da Musterinstanzen sich überlappen dürfen,
kann ein einzelner Spielstein gleichzeitig über mehrere Karten entscheiden —
die sechs Karten der Form `12,21,32` etwa unterscheiden sich nur in der Füllung
derselben drei Zellen.

**Die Lage des Zielsteins folgt aus der Form.** Bei den verzweigten Formen
`11,12,21`, `12,21,32` und `12,21,22,32` liegt der Tierwürfel ausnahmslos auf der
Zelle, die alle anderen berührt. Bei der Dreierkette `11,12,13` liegt er
ausnahmslos an einem **Ende**, nie in der Mitte. Keine Karte weicht davon ab.

--- | --- | --- |
| `11,12` | zwei senkrecht übereinander | Eichhörnchen, Erdmännchen, Lachs, Frosch, Schwein, Koala |
| `11,12,13` | drei senkrecht übereinander | Hase, Panther, Lama, Wüstenfuchs, Echse |
| `11,12,21` | Mitte mit zwei Nachbarn **auf derselben Seite** | Affe, Papagei |
| `12,21,32` | Mitte mit zwei Nachbarn **unten links und unten rechts** | Eisvogel, Pinguin, Pfau, Eisfuchs |
| `12,21,22,32` | Mitte mit drei Nachbarn darunter | Biene, Waschbär |

Das ist für die Engine erheblich: Ein einzelner Spielstein kann gleichzeitig
über mehrere Karten entscheiden, und die Mustersuche muss nur wenige Formen
kennen — die Vielfalt steckt in der Füllung, nicht in der Geometrie.

---

```
Karte:   Eisvogel
Muster:  12=Wasser  21=Baum3  32=Wasser
Würfel:  auf 21
Punkte:  5 / 11 / 18
```

Baum der Höhe 3, darunter links und rechts je ein Wasserstein. Bestätigt.

---

```
Karte:   Hase
Muster:  11=Gebäude  12=Baum1  13=Baum1
Würfel:  auf 13
Punkte:  5 / 10 / 17
```

Senkrechte Dreierkette in einer Spalte: Gebäude oben, darunter zwei Bäume der
Höhe 1. Bestätigt.

---

```
Karte:   Eichhörnchen
Muster:  11=Baum3  12=Gebäude
Würfel:  auf 12
Punkte:  4 / 9 / 15
```

Zwei senkrecht benachbarte Zellen: Baum der Höhe 3 über einem Gebäude.
Bestätigt.

---

```
Karte:   Erdmännchen
Muster:  11=Feld  12=Berg1
Würfel:  auf 12
Punkte:  2 / 5 / 9 / 14
```

Zwei senkrecht benachbarte Zellen: Feld über einem Berg der Höhe 1. **Vier**
Tierwürfel. Bestätigt.

---

```
Karte:   Biene
Muster:  12=Feld  21=Baum2  22=Feld  32=Feld
Würfel:  auf 21
Punkte:  8 / 18
```

Baum der Höhe 2 mit drei Feldern darunter — unten links, direkt darunter,
unten rechts. Vier Zellen über drei Spalten, **zwei** Tierwürfel. Bestätigt.

---

```
Karte:   Pinguin
Muster:  12=Wasser  21=Berg1  32=Wasser
Würfel:  auf 21
Punkte:  4 / 10 / 16
```

Berg der Höhe 1 mit je einem Wasserstein unten links und unten rechts.
**Formgleich mit dem Eisvogel**, nur die Mitte unterscheidet sich. Bestätigt.

---

```
Karte:   Affe
Muster:  11=Wasser  12=Wasser  21=Berg2
Würfel:  auf 21
Punkte:  5 / 11
```

Berg der Höhe 2 mit zwei Wassersteinen links davon, oben links und unten
links. Erste Form, bei der beide Nachbarn auf derselben Seite liegen.
Bestätigt.

---

```
Karte:   Lachs
Muster:  11=Berg3  12=Wasser
Würfel:  auf 12
Punkte:  3 / 6 / 10 / 16
```

Berg der Höhe 3 mit einem Wasserstein direkt darunter. Erste Karte, deren
Zielstein Wasser ist. Bestätigt.

---

```
Karte:   Frosch
Muster:  11=Baum1  12=Wasser
Würfel:  auf 12
Punkte:  2 / 4 / 6 / 10 / 15
```

Baum der Höhe 1 mit einem Wasserstein direkt darunter. **Fünf** Tierwürfel,
die höchste belegte Zahl. Formgleich mit dem Lachs, siehe dort. Bestätigt.

---

```
Karte:   Panther
Muster:  11=Baum2  12=Baum2  13=Feld
Würfel:  auf 13
Punkte:  5 / 11
```

Senkrechte Dreierkette in einer Spalte: zwei Bäume der Höhe 2 über einem
Feld. Formgleich mit dem Hasen. Erste Karte, deren Zielstein ein **Feld** ist.
Bestätigt.

---

```
Karte:   Papagei
Muster:  11=Wasser  12=Wasser  21=Baum2
Würfel:  auf 21
Punkte:  4 / 9 / 14
```

Baum der Höhe 2 mit zwei Wassersteinen links davon, oben links und unten
links. **Formgleich mit dem Affen**, nur die Mitte unterscheidet sich —
Baum2 statt Berg2. Bestätigt.

---

```
Karte:   Schwein
Muster:  11=Gebäude  12=Baum2
Würfel:  auf 12
Punkte:  4 / 8 / 13
```

Zwei senkrecht benachbarte Zellen: Gebäude über einem Baum der Höhe 2,
Zielstein ist der Baum. Formgleich mit dem Eichhörnchen, dort liegen
Zielstein und Gebäude umgekehrt. Bestätigt.

---

```
Karte:   Koala
Muster:  11=Baum1  12=Baum2
Würfel:  auf 12
Punkte:  3 / 6 / 10 / 15
```

Zwei senkrecht benachbarte Zellen: Baum der Höhe 1 über einem Baum der Höhe 2,
Zielstein ist der untere. Vier Tierwürfel. Bestätigt.

---

```
Karte:   Pfau
Muster:  12=Wasser  21=Gebäude  32=Wasser
Würfel:  auf 21
Punkte:  5 / 10 / 17
```

Gebäude mit je einem Wasserstein unten links und unten rechts. Dritte Karte
der Form von Eisvogel und Pinguin. Bestätigt.

---

```
Karte:   Lama
Muster:  11=Berg2  12=Feld  13=Feld
Würfel:  auf 13
Punkte:  5 / 12
```

Berg der Höhe 2 über zwei Feldern, senkrecht in einer Spalte; Zielstein ist
das untere Feld. Die beiden gelben Steine grenzen aneinander und zählen
damit nebenbei als Feldgruppe. Bestätigt.

---

```
Karte:   Wüstenfuchs
Muster:  11=Feld  12=Berg1  13=Berg1
Würfel:  auf 13
Punkte:  4 / 9 / 16
```

Feld über zwei Bergen der Höhe 1, senkrecht in einer Spalte; Zielstein ist
der untere Berg. Die beiden Berge grenzen aneinander und erfüllen damit die
Nachbarschaftsbedingung der Bergwertung. Bestätigt.

---

```
Karte:   Eisfuchs
Muster:  12=Baum1  21=Feld  32=Baum1
Würfel:  auf 21
Punkte:  5 / 10 / 17
```

Feld mit je einem Baum der Höhe 1 unten links und unten rechts. Vierte Karte
der Form von Eisvogel, Pinguin und Pfau. Bestätigt.

---

```
Karte:   Waschbär
Muster:  12=Wasser  21=Feld  22=Wasser  32=Wasser
Würfel:  auf 21
Punkte:  6 / 12
```

Feld mit drei Wassersteinen darunter — unten links, direkt darunter, unten
rechts. Vier Zellen über drei Spalten, **zwei** Tierwürfel; Form der Biene.
Bestätigt.

---

```
Karte:   Echse
Muster:  11=Feld  12=Feld  13=Gebäude
Würfel:  auf 13
Punkte:  5 / 10 / 16
```

Zwei Felder über einem Gebäude, senkrecht in einer Spalte; Zielstein ist das
Gebäude. Bestätigt.

---

```
Karte:   Igel
Muster:  11=Baum2  12=Baum2  21=Gebäude
Würfel:  auf 21
Punkte:  5 / 12
```

Gebäude mit zwei Bäumen der Höhe 2 links davon, oben links und unten links.
Mit sechs Steinen das teuerste Muster des Satzes. Bestätigt.

---

```
Karte:   Maus
Muster:  12=Feld  21=Gebäude  32=Feld
Würfel:  auf 21
Punkte:  5 / 10 / 17
```

Gebäude mit je einem Feld unten links und unten rechts. Gleiche Punktleiste
wie Pfau und Hase. Bestätigt.

---

```
Karte:   Rabe
Muster:  12=Gebäude  21=Feld  32=Gebäude
Würfel:  auf 21
Punkte:  4 / 9
```

Feld mit je einem Gebäude unten links und unten rechts. Einziges Muster mit
**zwei** Gebäuden und damit zwei roten Steinen; Rot ist mit 15 Steinen die
knappste Farbe. Bestätigt.

---

```
Karte:   Fledermaus
Muster:  11=Baum3  12=Berg1
Würfel:  auf 12
Punkte:  3 / 6 / 10 / 16
```

Baum der Höhe 3 über einem Berg der Höhe 1, Zielstein ist der Berg. Gleiche
Punktleiste wie der Lachs. Bestätigt.

---

```
Karte:   Krokodil
Muster:  11=Baum3  12=Wasser  13=Wasser
Würfel:  auf 13
Punkte:  4 / 9 / 15
```

Baum der Höhe 3 über zwei Wassersteinen, senkrecht in einer Spalte;
Zielstein ist der untere Wasserstein. Bestätigt.

---

```
Karte:   Rochen
Muster:  11=Berg1  12=Berg1  21=Wasser
Würfel:  auf 21
Punkte:  4 / 10 / 16
```

Wasserstein mit zwei Bergen der Höhe 1 links davon, oben links und unten
links. Die beiden Berge grenzen aneinander. Bestätigt.

---

```
Karte:   Adler
Muster:  11=Feld  12=Berg3
Würfel:  auf 12
Punkte:  5 / 11
```

Feld über einem Berg der Höhe 3, Zielstein ist der Berg. Bestätigt.

---

```
Karte:   Bär
Muster:  11=Berg2  12=Berg2  21=Baum1
Würfel:  auf 21
Punkte:  5 / 11
```

Baum der Höhe 1 mit zwei Bergen der Höhe 2 links davon, oben links und unten
links. Bestätigt.

---

```
Karte:   Ente
Muster:  11=Gebäude  12=Wasser
Würfel:  auf 12
Punkte:  2 / 4 / 8 / 13
```

Gebäude über einem Wasserstein, Zielstein ist das Wasser. Vier Tierwürfel.
Bestätigt.

---

```
Karte:   Otter
Muster:  11=Baum1  12=Baum1  13=Wasser
Würfel:  auf 13
Punkte:  5 / 10 / 16
```

Zwei Bäume der Höhe 1 über einem Wasserstein, senkrecht in einer Spalte;
Zielstein ist das Wasser. Bestätigt.

---

```
Karte:   Flamingo
Muster:  11=Feld  12=Feld  21=Wasser
Würfel:  auf 21
Punkte:  4 / 10 / 16
```

Wasserstein mit zwei Feldern links davon, oben links und unten links. Die
beiden gelben Steine grenzen aneinander. Bestätigt.

---

```
Karte:   Wolf
Muster:  11=Feld  12=Feld  21=Baum3
Würfel:  auf 21
Punkte:  4 / 10 / 16
```

Baum der Höhe 3 mit zwei Feldern links davon, oben links und unten links.
**Formgleich mit dem Flamingo** bei gleicher Punktleiste, obwohl das Muster
zwei Steine mehr kostet. Bestätigt.

---

```
Karte:   Marienkäfer
Muster:  11=Baum1  12=Feld
Würfel:  auf 12
Punkte:  2 / 5 / 8 / 12 / 17
```

Baum der Höhe 1 über einem Feld, Zielstein ist das Feld. **Fünf** Tierwürfel,
wie beim Frosch, aber mit höheren Werten. Bestätigt.
