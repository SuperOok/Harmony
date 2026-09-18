# Tierkarten

Erfasst nach `kartennotation.md`. Schablone:

```
  1       7
      4      10
  2       8
      5      11
  3       9
      6      12
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
| `1,2` | zwei benachbarte Zellen | 10 | Erdmännchen, Frosch, Marienkäfer, Koala, Ente, Lachs, Fledermaus, Schwein, Adler, Eichhörnchen |
| `1,2,3` | Dreierkette | 7 | Wüstenfuchs, Otter, Hase, Echse, Lama, Panther, Krokodil |
| `1,2,4` | Dreieck aus drei paarweise benachbarten Zellen | 7 | Rochen, Flamingo, Affe, Papagei, Bär, Wolf, Igel |
| `2,4,8` | Mitte mit zwei Nachbarn unten links und unten rechts | 6 | Pinguin, Eisfuchs, Pfau, Maus, Eisvogel, Rabe |
| `2,4,5,8` | Mitte mit drei Nachbarn darunter | 2 | Waschbär, Biene |

Zwei Folgerungen für die Engine:

**Die Mustersuche muss nur fünf Formen kennen.** Die Vielfalt steckt in der
Füllung, nicht in der Geometrie. Da Musterinstanzen sich überlappen dürfen,
kann ein einzelner Spielstein gleichzeitig über mehrere Karten entscheiden —
die sechs Karten der Form `2,4,8` etwa unterscheiden sich nur in der Füllung
derselben drei Zellen.

**Die Lage des Zielsteins folgt aus der Form.** Bei den verzweigten Formen
`1,2,4`, `2,4,8` und `2,4,5,8` liegt der Tierwürfel ausnahmslos auf der
Zelle, die alle anderen berührt. Bei der Dreierkette `1,2,3` liegt er
ausnahmslos an einem **Ende**, nie in der Mitte. Keine Karte weicht davon ab.

--- | --- | --- |
| `1,2` | zwei senkrecht übereinander | Eichhörnchen, Erdmännchen, Lachs, Frosch, Schwein, Koala |
| `1,2,3` | drei senkrecht übereinander | Hase, Panther, Lama, Wüstenfuchs, Echse |
| `1,2,4` | Mitte mit zwei Nachbarn **auf derselben Seite** | Affe, Papagei |
| `2,4,8` | Mitte mit zwei Nachbarn **unten links und unten rechts** | Eisvogel, Pinguin, Pfau, Eisfuchs |
| `2,4,5,8` | Mitte mit drei Nachbarn darunter | Biene, Waschbär |

Das ist für die Engine erheblich: Ein einzelner Spielstein kann gleichzeitig
über mehrere Karten entscheiden, und die Mustersuche muss nur wenige Formen
kennen — die Vielfalt steckt in der Füllung, nicht in der Geometrie.

---

```
Karte:   Eisvogel
Muster:  2=Wasser  4=Baum3  8=Wasser
Würfel:  auf 4
Punkte:  5 / 11 / 18
```

Baum der Höhe 3, darunter links und rechts je ein Wasserstein. Bestätigt.

---

```
Karte:   Hase
Muster:  1=Gebäude  2=Baum1  3=Baum1
Würfel:  auf 3
Punkte:  5 / 10 / 17
```

Senkrechte Dreierkette in einer Spalte: Gebäude oben, darunter zwei Bäume der
Höhe 1. Bestätigt.

---

```
Karte:   Eichhörnchen
Muster:  1=Baum3  2=Gebäude
Würfel:  auf 2
Punkte:  4 / 9 / 15
```

Zwei senkrecht benachbarte Zellen: Baum der Höhe 3 über einem Gebäude.
Bestätigt.

---

```
Karte:   Erdmännchen
Muster:  1=Feld  2=Berg1
Würfel:  auf 2
Punkte:  2 / 5 / 9 / 14
```

Zwei senkrecht benachbarte Zellen: Feld über einem Berg der Höhe 1. **Vier**
Tierwürfel. Bestätigt.

---

```
Karte:   Biene
Muster:  2=Feld  4=Baum2  5=Feld  8=Feld
Würfel:  auf 4
Punkte:  8 / 18
```

Baum der Höhe 2 mit drei Feldern darunter — unten links, direkt darunter,
unten rechts. Vier Zellen über drei Spalten, **zwei** Tierwürfel. Bestätigt.

---

```
Karte:   Pinguin
Muster:  2=Wasser  4=Berg1  8=Wasser
Würfel:  auf 4
Punkte:  4 / 10 / 16
```

Berg der Höhe 1 mit je einem Wasserstein unten links und unten rechts.
**Formgleich mit dem Eisvogel**, nur die Mitte unterscheidet sich. Bestätigt.

---

```
Karte:   Affe
Muster:  1=Wasser  2=Wasser  4=Berg2
Würfel:  auf 4
Punkte:  5 / 11
```

Berg der Höhe 2 mit zwei Wassersteinen links davon, oben links und unten
links. Erste Form, bei der beide Nachbarn auf derselben Seite liegen.
Bestätigt.

---

```
Karte:   Lachs
Muster:  1=Berg3  2=Wasser
Würfel:  auf 2
Punkte:  3 / 6 / 10 / 16
```

Berg der Höhe 3 mit einem Wasserstein direkt darunter. Erste Karte, deren
Zielstein Wasser ist. Bestätigt.

---

```
Karte:   Frosch
Muster:  1=Baum1  2=Wasser
Würfel:  auf 2
Punkte:  2 / 4 / 6 / 10 / 15
```

Baum der Höhe 1 mit einem Wasserstein direkt darunter. **Fünf** Tierwürfel,
die höchste belegte Zahl. Formgleich mit dem Lachs, siehe dort. Bestätigt.

---

```
Karte:   Panther
Muster:  1=Baum2  2=Baum2  3=Feld
Würfel:  auf 3
Punkte:  5 / 11
```

Senkrechte Dreierkette in einer Spalte: zwei Bäume der Höhe 2 über einem
Feld. Formgleich mit dem Hasen. Erste Karte, deren Zielstein ein **Feld** ist.
Bestätigt.

---

```
Karte:   Papagei
Muster:  1=Wasser  2=Wasser  4=Baum2
Würfel:  auf 4
Punkte:  4 / 9 / 14
```

Baum der Höhe 2 mit zwei Wassersteinen links davon, oben links und unten
links. **Formgleich mit dem Affen**, nur die Mitte unterscheidet sich —
Baum2 statt Berg2. Bestätigt.

---

```
Karte:   Schwein
Muster:  1=Gebäude  2=Baum2
Würfel:  auf 2
Punkte:  4 / 8 / 13
```

Zwei senkrecht benachbarte Zellen: Gebäude über einem Baum der Höhe 2,
Zielstein ist der Baum. Formgleich mit dem Eichhörnchen, dort liegen
Zielstein und Gebäude umgekehrt. Bestätigt.

---

```
Karte:   Koala
Muster:  1=Baum1  2=Baum2
Würfel:  auf 2
Punkte:  3 / 6 / 10 / 15
```

Zwei senkrecht benachbarte Zellen: Baum der Höhe 1 über einem Baum der Höhe 2,
Zielstein ist der untere. Vier Tierwürfel. Bestätigt.

---

```
Karte:   Pfau
Muster:  2=Wasser  4=Gebäude  8=Wasser
Würfel:  auf 4
Punkte:  5 / 10 / 17
```

Gebäude mit je einem Wasserstein unten links und unten rechts. Dritte Karte
der Form von Eisvogel und Pinguin. Bestätigt.

---

```
Karte:   Lama
Muster:  1=Berg2  2=Feld  3=Feld
Würfel:  auf 3
Punkte:  5 / 12
```

Berg der Höhe 2 über zwei Feldern, senkrecht in einer Spalte; Zielstein ist
das untere Feld. Die beiden gelben Steine grenzen aneinander und zählen
damit nebenbei als Feldgruppe. Bestätigt.

---

```
Karte:   Wüstenfuchs
Muster:  1=Feld  2=Berg1  3=Berg1
Würfel:  auf 3
Punkte:  4 / 9 / 16
```

Feld über zwei Bergen der Höhe 1, senkrecht in einer Spalte; Zielstein ist
der untere Berg. Die beiden Berge grenzen aneinander und erfüllen damit die
Nachbarschaftsbedingung der Bergwertung. Bestätigt.

---

```
Karte:   Eisfuchs
Muster:  2=Baum1  4=Feld  8=Baum1
Würfel:  auf 4
Punkte:  5 / 10 / 17
```

Feld mit je einem Baum der Höhe 1 unten links und unten rechts. Vierte Karte
der Form von Eisvogel, Pinguin und Pfau. Bestätigt.

---

```
Karte:   Waschbär
Muster:  2=Wasser  4=Feld  5=Wasser  8=Wasser
Würfel:  auf 4
Punkte:  6 / 12
```

Feld mit drei Wassersteinen darunter — unten links, direkt darunter, unten
rechts. Vier Zellen über drei Spalten, **zwei** Tierwürfel; Form der Biene.
Bestätigt.

---

```
Karte:   Echse
Muster:  1=Feld  2=Feld  3=Gebäude
Würfel:  auf 3
Punkte:  5 / 10 / 16
```

Zwei Felder über einem Gebäude, senkrecht in einer Spalte; Zielstein ist das
Gebäude. Bestätigt.

---

```
Karte:   Igel
Muster:  1=Baum2  2=Baum2  4=Gebäude
Würfel:  auf 4
Punkte:  5 / 12
```

Gebäude mit zwei Bäumen der Höhe 2 links davon, oben links und unten links.
Mit sechs Steinen das teuerste Muster des Satzes. Bestätigt.

---

```
Karte:   Maus
Muster:  2=Feld  4=Gebäude  8=Feld
Würfel:  auf 4
Punkte:  5 / 10 / 17
```

Gebäude mit je einem Feld unten links und unten rechts. Gleiche Punktleiste
wie Pfau und Hase. Bestätigt.

---

```
Karte:   Rabe
Muster:  2=Gebäude  4=Feld  8=Gebäude
Würfel:  auf 4
Punkte:  4 / 9
```

Feld mit je einem Gebäude unten links und unten rechts. Einziges Muster mit
**zwei** Gebäuden und damit zwei roten Steinen; Rot ist mit 15 Steinen die
knappste Farbe. Bestätigt.

---

```
Karte:   Fledermaus
Muster:  1=Baum3  2=Berg1
Würfel:  auf 2
Punkte:  3 / 6 / 10 / 16
```

Baum der Höhe 3 über einem Berg der Höhe 1, Zielstein ist der Berg. Gleiche
Punktleiste wie der Lachs. Bestätigt.

---

```
Karte:   Krokodil
Muster:  1=Baum3  2=Wasser  3=Wasser
Würfel:  auf 3
Punkte:  4 / 9 / 15
```

Baum der Höhe 3 über zwei Wassersteinen, senkrecht in einer Spalte;
Zielstein ist der untere Wasserstein. Bestätigt.

---

```
Karte:   Rochen
Muster:  1=Berg1  2=Berg1  4=Wasser
Würfel:  auf 4
Punkte:  4 / 10 / 16
```

Wasserstein mit zwei Bergen der Höhe 1 links davon, oben links und unten
links. Die beiden Berge grenzen aneinander. Bestätigt.

---

```
Karte:   Adler
Muster:  1=Feld  2=Berg3
Würfel:  auf 2
Punkte:  5 / 11
```

Feld über einem Berg der Höhe 3, Zielstein ist der Berg. Bestätigt.

---

```
Karte:   Bär
Muster:  1=Berg2  2=Berg2  4=Baum1
Würfel:  auf 4
Punkte:  5 / 11
```

Baum der Höhe 1 mit zwei Bergen der Höhe 2 links davon, oben links und unten
links. Bestätigt.

---

```
Karte:   Ente
Muster:  1=Gebäude  2=Wasser
Würfel:  auf 2
Punkte:  2 / 4 / 8 / 13
```

Gebäude über einem Wasserstein, Zielstein ist das Wasser. Vier Tierwürfel.
Bestätigt.

---

```
Karte:   Otter
Muster:  1=Baum1  2=Baum1  3=Wasser
Würfel:  auf 3
Punkte:  5 / 10 / 16
```

Zwei Bäume der Höhe 1 über einem Wasserstein, senkrecht in einer Spalte;
Zielstein ist das Wasser. Bestätigt.

---

```
Karte:   Flamingo
Muster:  1=Feld  2=Feld  4=Wasser
Würfel:  auf 4
Punkte:  4 / 10 / 16
```

Wasserstein mit zwei Feldern links davon, oben links und unten links. Die
beiden gelben Steine grenzen aneinander. Bestätigt.

---

```
Karte:   Wolf
Muster:  1=Feld  2=Feld  4=Baum3
Würfel:  auf 4
Punkte:  4 / 10 / 16
```

Baum der Höhe 3 mit zwei Feldern links davon, oben links und unten links.
**Formgleich mit dem Flamingo** bei gleicher Punktleiste, obwohl das Muster
zwei Steine mehr kostet. Bestätigt.

---

```
Karte:   Marienkäfer
Muster:  1=Baum1  2=Feld
Würfel:  auf 2
Punkte:  2 / 5 / 8 / 12 / 17
```

Baum der Höhe 1 über einem Feld, Zielstein ist das Feld. **Fünf** Tierwürfel,
wie beim Frosch, aber mit höheren Werten. Bestätigt.
