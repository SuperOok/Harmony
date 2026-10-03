# Szenen der Tierkarten

Stand 2026-10-03. Entwurf für kleine Start- und Zwischenanimationen, eine
je Tierkarte. Noch nichts davon ist in der App. Gezeichnet wird mit einem
Generator in Python, der SVG schreibt (`tools/szenen/`). Damit ist jede
Änderung in Sekunden als Bild zu sehen. Die SwiftUI-Fassung folgt, wenn der
Stil steht.

## Wo was liegt

| Datei | Inhalt |
| --- | --- |
| `tools/szenen/style.py` | alle Stellschrauben: Farben, Maße, Höhen, Dunst, Feldlesarten |
| `tools/szenen/landscapes.py` | eine Funktion je Landschaft: wie sie aussieht |
| `tools/szenen/scene.py` | stellt Landschaften auf den Plan, sortiert nach Tiefe, schreibt das SVG |
| `tools/szenen/entwuerfe/` | erste Tierfigur (Eichhörnchen), still und als Sprung animiert |
| `tools/szenen/out/` | erzeugte Bilder, nicht eingecheckt |

```bash
python3 tools/szenen/scene.py --feld korn
```

```bash
qlmanage -t -s 1000 -o /tmp tools/szenen/out/beispiel-korn.svg
```

Eine Zahl ändern heißt `style.py`, eine Form ändern heißt
`landscapes.py`. Beides wirkt auf jede Szene.

## Grundsätze

**Die Szene entsteht aus dem Muster der Karte, nicht aus ihrer Grafik.**
Das Urheberrecht schützt die Gestaltung eines Bildes, nicht das Motiv.
Die Kartengrafiken zeigen das Tier in seinem Lebensraum. Nachgestellte
Bildaufbauten, Posen oder Perspektiven der Karte wären eine Bearbeitung,
und das Repo ist öffentlich. Das Muster aus `animals.json` ist dagegen
Spielregel. Gezeichnet wird also, was die Karte verlangt, mit eigenen
Figuren in eigenen Posen. Nebenbei zeigt die Animation damit am Tisch,
welches Muster das Tier braucht.

**Die Steine bleiben erkennbar.** Jede Landschaft ist aus den Spielsteinen
gebaut und nur so weit abgewandelt, dass sie als Haus, Baum oder Berg zu
lesen ist. Wer das Spiel kennt, soll die Steine zählen können.

**Farbwelt des App-Icons.** Dunkler Hintergrund `#22313A`, die
Steinfarben der Spielansicht, dazu je ein heller und ein dunkler Ton.
Licht fällt von links oben. Durch die erleuchteten Fenster und den Dunst
wirkt die Szene wie eine Abendstimmung.

**Schräg von oben auf den Plan.** Sechseckfelder, zur Ellipse gestaucht
(`SQUASH`), ohne Fluchtpunkt. Der Plan reicht über die Szene hinaus.
Hinten verblasst alles zur Hintergrundfarbe hin: Je Reihe gehen 22 %
Sichtbarkeit verloren, und die Farben verlieren Sättigung. Oben läuft die
Fläche ins Dunkle aus.

## Die Landschaften

**Gebäude.** Unten der graue, braune oder rote Stein, schmaler als das
Feld (`HOUSE_RX`). Er trägt eine Tür mit Rundbogen und ein erleuchtetes
Sprossenfenster. Oben der Ziegel als Satteldach, dessen First vom
Betrachter weg läuft, mit Schornstein auf der Schattenseite. Das Dach ist
breiter als die Wand (`EAVE_RX`), sodass ein Überstand entsteht. Es hat
keine eigene Wand: Die Schrägen laufen bis zur Traufe.

**Baum.** Die Holzsteine als schmaler Stamm (`TRUNK_RX`). Der Blattstein
wird zur Krone aus zehn Kugeln in drei Lagen, hinten dunkler. Ein Baum
der Höhe 1 ist ein Busch.

**Berg.** Ein Felskegel aus zwölf Flächen, nach Lichteinfall schattiert.
Auf jeder Steinhöhe springt er zurück, und der Absatz ist heller; so
bleiben die Steine zählbar. Bergsteine sind 45 % höher gezeichnet als die
übrigen, damit **ein Berg der Höhe 3 mindestens so hoch ist wie ein Baum
der Höhe 3**. Ab Höhe 3 trägt er eine Schneekappe. Benachbarte Berge
überlappen sich, und zwischen ihnen läuft ein niedrigerer Grat mit einer
Senke. Dadurch wirken sie wie ein Gebirge statt wie einzelne Türme.

**Wasser.** Kein Stein, sondern das ganze Feld, eben und leicht
abgesenkt. Benachbarte Wasserfelder bilden eine Fläche ohne Fugen. Ein Ufer
gibt es nur zum Land hin: eine helle Uferlinie, an den hinteren Rändern
eine dunkle Böschung. Wellenbögen beleben die Fläche. Später sollen Tiere
darin schwimmen.

**Feld.** Ebenfalls flächig und über Nachbarfelder hinweg ohne Fuge. Das
Feld gibt es in drei Lesarten, gewählt je Tier:

| Lesart | Bild | Tiere |
| --- | --- | --- |
| `korn` | niedriges Getreide, Ähren in vier Goldtönen | Maus, Rabe, Biene, Marienkäfer, Echse, Waschbär |
| `praerie` | Grasbüschel in Grün bis Gold, vereinzelte Blüten | Wolf, Panther, Lama, Flamingo, Adler |
| `steppe` | Sand mit Kieseln, vereinzelte trockene Büschel | Wüstenfuchs, Erdmännchen |

Offen ist der Eisfuchs: Eine Tundra mit Schnee wäre eine vierte Lesart.
Echse und Waschbär passen auch zu Steppe bzw. Wiese. Die Halme werden mit
den stehenden Dingen nach Tiefe sortiert. So verdecken sie, was hinter
ihnen steht, und ein Tier kann aus dem Korn schauen.

## Verworfen

- **Kreise statt Steine.** Der erste Entwurf stapelte Kreise. Das wirkte
  flach und stimmte nicht, weil Steine mit der flachen Seite aufeinander
  liegen und nicht am Rand.
- **Dach mit First quer zum Betrachter.** Von oben sah das aus wie eine
  Mulde.
- **Dach mit Hals.** Mit einer senkrechten Ziegelwand unter dem Giebel
  sah das Haus aus wie ein Pilz.
- **Krone als einzelne Wölbung.** Sie wirkte wie ein Kissen oder ein
  Pilzhut. Erst die einzelnen Kugeln machen daraus einen Baum.
- **Berg als Steinstapel mit Felsspitze.** Das sah aus wie Fässer mit
  Zelt, und die Füllstücke zwischen Nachbarn verschwanden hinter den
  Scheiben.

## Die Tierfigur

Bisher gibt es nur das Eichhörnchen (`tools/szenen/entwuerfe/`): flach,
aus Kreisen und Ellipsen gebaut. Der Schwanz ist eine Kette von Kreisen,
als Anklang an die Punkte des Icons. Jedes Teil (Schwanz, Kopf, Auge,
Nuss, Körper) ist eine eigene Gruppe mit Drehpunkt und damit einzeln
animierbar. Die animierte Fassung springt vom Dach auf den Baum und
knabbert dort an der Nuss. Sie stammt noch aus der Zeit vor den räumlichen
Steinen und passt im Stil noch nicht zur Kulisse.

## Noch offen

- Wie die Muster einer Karte auf dem Plan liegen. Angedacht ist die volle
  Würfelbesetzung: das Muster so oft, wie die Karte Würfel trägt, und auf
  jedem Würfelfeld ein Tier.
- Ob der Dunst innerhalb eines zusammenhängenden Gebirges einheitlich
  sein soll; jetzt zerfällt ein Gebirge über zwei Reihen in zwei Helligkeiten.
- Die Tierfiguren im räumlichen Stil der Kulisse.
- Die Übertragung nach SwiftUI (`TimelineView` und `Canvas`, wie bei der
  Blüte des Icons). Die Kulisse wird dort aus denselben Formeln gerechnet,
  der Code bleibt klein. Das SVG des Generators ist mit rund 100 KB nur
  deshalb groß, weil es jeden Halm einzeln ausschreibt.
