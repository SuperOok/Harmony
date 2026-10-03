# Szenen der Tierkarten

Stand 2026-10-03, abends. Entwurf für kleine Start- und Zwischenanimationen, eine
je Tierkarte. Noch nichts davon ist in der App. Gezeichnet wird mit einem
Generator in Python, der SVG schreibt (`tools/szenen/`). Damit ist jede
Änderung in Sekunden als Bild zu sehen. Die SwiftUI-Fassung folgt, wenn der
Stil steht.

## Wo was liegt

| Datei | Inhalt |
| --- | --- |
| `tools/szenen/style.py` | alle Stellschrauben: Farben, Maße, Höhen, Dunst, Feldlesarten |
| `tools/szenen/landscapes.py` | eine Funktion je Landschaft: wie sie aussieht |
| `tools/szenen/scene.py` | stellt Landschaften auf den Plan, sortiert nach Tiefe, legt Dunst und Himmel darüber, schreibt das SVG durch eine Kamera |
| `tools/szenen/cards.py` | die Szene einer Karte: Muster so oft wie Würfel, Anordnung, Umgebung, Kameraausschnitte |
| `tools/szenen/figures.py` | die Tierfiguren, schattiert, in Teilen animierbar |
| `tools/szenen/animate.py` | die Eichhörnchen-Animation als animiertes SVG |
| `tools/szenen/entwuerfe/` | erste flache Fassung des Eichhörnchens, nur noch zur Erinnerung |
| `tools/szenen/out/` | erzeugte Bilder, nicht eingecheckt |

```bash
python3 tools/szenen/scene.py --feld korn       # Beispielszene mit jeder Landschaft
python3 tools/szenen/cards.py Eichhörnchen      # Szene einer Karte, drei Zoomstufen
python3 tools/szenen/animate.py                 # die Animation
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

**Schräg von oben auf den Plan.** Sechseckfelder mit flacher Oberseite wie
auf dem Spielplan, vertikal gestaucht (`SQUASH`), ohne Fluchtpunkt. Der
Plan reicht über die Szene hinaus. Oben liegt ein Horizont mit Abendhimmel,
Sternen und Mondsichel, der in der Welt verankert ist und beim Zoomen nicht
wandert.

**Dunst ohne Filter.** Hinten verblasst alles zur Hintergrundfarbe. Das
geschieht durch halbtransparente Schleier zwischen den Reihen, die alles
bedecken, was weiter oben im Bild liegt; was danach gezeichnet wird, ist
näher und bleibt klar. SVG-Filter taugen dafür nicht: WebKit zeichnet
gefilterte Gruppen bei starkem Zoom nicht mehr oder sehr langsam, auf dem
iPhone fehlten dadurch Baumkronen und Wasser, und die Animation ruckelte.

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

## Die Szene einer Karte

Das Muster der Karte wird so oft auf den Plan gelegt, wie die Karte Würfel
trägt, in allen sechs Drehungen, nicht gespiegelt. Muster dürfen Steine
teilen wie im Spiel, jeder Würfel aber liegt auf einem eigenen Feld. Eine
Suche (`cards.place`) wählt die Anordnung: wenig Felder, alles im Bild, das
erste Tier vorn in der Mitte, die übrigen hinten und seitlich verteilt,
nichts Hohes vor einem Tier. Ein Baum der Höhe 3 darf sich drei Häuser
teilen; das Eichhörnchen braucht dann vier Felder statt neun.

Die **Umgebung** füllt den Plan, damit die Szene nicht leer ist, in drei
Zonen je Tier (`MIX`): vorn nur Niedriges (Wasser, Felder, Büsche), in der
Mitte und weit hinten je nach Tier. Das Eichhörnchen lebt im Wald: Bäume
direkt hinter dem Habitat, Wald ringsum, kein offenes Feld. Weitere
Habitate in der Umgebung stören nicht, die Szene soll aufmuntern, nicht
zählen. Vor den beiden äußeren Häusern liegen links zwei Wasserfelder,
rechts ein Feld mit einem Busch darunter.

**Büsche** (Baum1) sind keine Krone, sondern acht niedrige Ballen, die das
Feld füllen, ohne Stamm und dunkler als Kronen.

**Kamera.** Das Bild ist hochkant wie das iPhone 15 Pro Max (430 × 932).
Drei Ausschnitte je Karte: `nah` (das erste Tier), `mittel` (das Habitat),
`weit` (mit Umgebung bis zum Horizont). Kleine Tiere brauchen die Nähe, das
Eichhörnchen ist nur etwa ein Viertel so hoch wie das Haus.

## Die Animation

`animate.py` rechnet die Zeitleiste Bild für Bild (25 je Sekunde) und
schreibt sie als SMIL-Werte ins SVG; das SVG enthält keine Logik, und
dieselbe Zeitleiste kann später SwiftUI antreiben. Sie läuft 13,5 Sekunden
und beginnt in der Baumkrone, nicht auf dem Haus: Das Haus ist die
Landschaft des Würfels, dort endet jede Animation.

1. Nahaufnahme der Krone, das Eichhörnchen springt hinein, hält inne.
2. Die Kamera zoomt einmal heraus.
3. Es läuft über die Krone, springt aufs Dach, läuft den First hinunter.
4. Es kommt auf seinem Haus zur Ruhe und knabbert.
5. Die Kamera zoomt ein zweites Mal heraus: alle drei Häuser, die
   äußeren gut zur Hälfte im Bild.

Zoom nur herein, nie wieder zurück, das wirkt unruhig.

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
- **SVG-Filter für den Dunst.** Siehe oben: zu langsam bei starkem Zoom.
- **Video der Animation zur Prüfung.** Ein WebKit-Programm nahm sie Bild für
  Bild auf. Nach dem Wegfall der Filter läuft das SVG auch auf dem iPhone
  flüssig, der Umweg war überflüssig und ist gestrichen.
- **Berg als Steinstapel mit Felsspitze.** Das sah aus wie Fässer mit
  Zelt, und die Füllstücke zwischen Nachbarn verschwanden hinter den
  Scheiben.

## Die Tierfigur

Bisher gibt es nur das Eichhörnchen (`figures.py`). Es ist aus Kreisen und
Ellipsen gebaut, aber wie die Steine schattiert: jedes Teil ein rundes
Volumen, hell oben links, dunkel unten rechts. Der Schwanz ist eine
einzige buschige Feder entlang einer Mittellinie mit Breitenverlauf, außen
mit Fellspitzen und innen mit hellen Strähnen; die Ohrpinsel sind
Haarbüschel. Schwanz, Kopf, Auge und Nuss sind eigene Gruppen mit
Drehpunkt und damit einzeln animierbar.

## Noch offen

- Die Animationen 2 und 3 je Karte: Tier k kommt auf sein Würfelfeld, die
  früheren sitzen schon an ihren Plätzen. `cards.build(name, arrived=k)`
  liefert die Szene dafür.
- Die übrigen 31 Tiere; bis dahin steht auf dem Würfelfeld ein Würfel.
- Umgebung (`MIX`) und Feldlesart je Tier festlegen.
- Ob der Dunst innerhalb eines zusammenhängenden Gebirges einheitlich
  sein soll.
- Die Übertragung nach SwiftUI (`TimelineView` und `Canvas`, wie bei der
  Blüte des Icons). Die Kulisse wird dort aus denselben Formeln gerechnet,
  der Code bleibt klein; das SVG ist mit rund 400 KB nur deshalb groß,
  weil es jede Form einzeln ausschreibt.
