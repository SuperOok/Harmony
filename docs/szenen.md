# Szenen der Tierkarten

Stand 2026-10-03, abends. Entwurf für kleine Start- und Zwischenanimationen, eine
je Tierkarte. Gezeichnet wird mit einem Generator in Python, der SVG
schreibt (`tools/szenen/`). Damit ist jede Änderung in Sekunden als Bild zu
sehen. In der App läuft bisher nur die erste Animation des Eichhörnchens,
vor dem Über-Bildschirm (siehe *In der App*).

## In der App

Die Übertragung geht nicht über eine Neufassung der Landschaften in Swift,
sondern über eine **Anzeigeliste**: `tools/szenen/export.py` liest das SVG
der Szene zurück und schreibt die Formen in Zeichenreihenfolge nach
`MyApp/Szenen/szene-eichhoernchen.json` (rund 480 KB, gut 3500 Knoten;
Pfade nur aus M, L, Q, C, Z, Verläufe, ein Ausschnitt für das Wasser, benannte
Gruppen). Dasselbe Python zeichnet damit Vorschau und App, ein Unterschied
kann nur im Zeichnen selbst entstehen. Nach jeder Änderung an Stil, Landschaft
oder Figur wird die Datei neu geschrieben:

```bash
python3 tools/szenen/export.py
```

| Datei | Inhalt |
| --- | --- |
| `MyApp/Szenen/SceneDisplayList.swift` | lädt die Liste, baut Pfade, zeichnet Knoten mit `Canvas`; Verläufe wie `objectBoundingBox` im SVG, Knoten außerhalb des Bildes werden übersprungen |
| `MyApp/Szenen/SquirrelTimeline.swift` | die Zeitleiste in Swift, Zahl für Zahl aus `animate.py`; Ankerpunkte und Kameraausschnitte stehen in der Liste (`animate.anchors`) |
| `MyApp/Szenen/SquirrelSceneView.swift` | `TimelineView` und `Canvas`, Kamera, Tier mit Schwanz, Nuss und Auge; Tippen beendet vorzeitig |

Eine Änderung an `animate.py` muss in `SquirrelTimeline.swift` nachgezogen
werden (und bei neuen Ankerpunkten in `anchors()`); der Test `SceneTests`
prüft nur Anfang, Ende und dass die Kamera nie wieder hineinzoomt.

Abgespielt wird sie, wenn in `StartView` „Über Harmony" angetippt wird: Die
Szene liegt als Decke über dem Start-Bildschirm, beim Ausblenden wird der
Über-Bildschirm darunter eingeschoben. Sie läuft 13,5 Sekunden, blendet in
den letzten 0,5 aus (das Tier blendet dort anders als im SVG nicht aus, die
Szene schon). Die Prüfeinstiege (`Launch.skipsIntro`) und „Bewegung
reduzieren" überspringen sie.

Der Ausschnitt ist ein Hochformat von 430 : 932 und wird so groß gezeichnet,
wie er auf den Bildschirm passt; ein breiterer Bildschirm zeigt seitlich mehr.
Dafür ist die Liste für den weitesten Ausschnitt (`weit`) gezeichnet, nicht
für `mittel` wie das SVG; der Mond sitzt deshalb an anderer Stelle.
**Auf dem Gerät nicht nachgemessen:** je Bild sind bis zu rund 3500 Formen zu
zeichnen. Verläufe laufen als Füllung mit Matrix, nicht als Maske.

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

Die Kamera zoomt nur heraus, nie wieder hinein: Erst heraus, dann wieder
hinein wirkte unruhig. Ein zweites Herausziehen am Ende ist dagegen gewollt.

## Das Eichhörnchen als Szene

Der erste voll ausgearbeitete Fall, an dem die Regeln oben entstanden sind.

**Die Karte.** Muster `Baum3` und `Gebäude`, der Würfel liegt auf dem
Gebäude, drei Würfel (4, 9 und 15 Punkte). Gebaut wird der volle
Lebensraum: dreimal das Muster, auf jedem der drei Häuser ein Tier. Wer das
Spiel kennt, soll an der Szene die Zahl der Tiere ablesen können.

**Anordnung.** Ein Baum der Höhe 3 darf sich alle drei Häuser teilen, wie im
Spiel; das ergibt vier Felder: der Baum in der Mitte, ein Haus vorn, zwei
hinten links und rechts. Ohne Teilen (`cards.py --getrennt`) wären es sechs
Felder mit drei Bäumen. Die geteilte Fassung ist die der Animation, weil sie
den Lebensraum klein hält und die Regel zeigt. Ob das bei jeder Karte so
sein soll oder je Karte entschieden wird, ist offen.

**Drei Animationen, eine je Würfel.** Bei der k-ten sitzen die Tiere der
vorigen schon auf ihren Häusern, und das k-te Tier erscheint und macht seine
kleine Bewegung. Das erste Tier sitzt vorn und ist am deutlichsten, die
späteren füllen den Hintergrund: Die Szene zählt so mit wie die Würfelleiste
der Karte. Bisher gibt es nur die erste.

**Die Handlung der ersten.** Sie beginnt in der Baumkrone und endet auf dem
Haus, weil das Haus die Landschaft ist, auf der der Würfel liegt. Das Tier
springt in die Krone, hält inne, die Kamera zoomt heraus; es läuft ein
Stück über die Krone (das wurde ausdrücklich gewünscht, bevor es springt),
springt aufs Dach, läuft den First hinunter, setzt sich auf sein Haus und
knabbert die Eichel. Dann zoomt die Kamera noch einmal heraus, bis alle drei
Häuser zu sehen sind, die beiden äußeren gut zur Hälfte.

**Größe.** Das Tier ist nur etwa ein Viertel so hoch wie das Haus
(`SIZE['Eichhörnchen']`). Bei so kleinen Tieren ist der Zoom nötig, nicht
Zierde: Die Animation beginnt in der Nahaufnahme, in der die Figur das Bild
füllt, und gibt erst nach und nach den Lebensraum frei.

**Umgebung: Wald.**
- Hinter dem Habitat und daneben steht Wald aus Bäumen der Höhen 1 bis 3.
  Hohe Bäume neben den Häusern sind erlaubt; dass dabei weitere
  Eichhörnchen-Habitate entstehen, stört nicht, die Szene soll aufmuntern.
  Das Habitat selbst soll nur nicht zu viel Platz einnehmen.
- Wasser gehört nicht hinter das Habitat, sondern in den Vordergrund, vor
  die Häuser, zusammen mit niedrigem Bewuchs.
- Keine Prärie im Hintergrund; ganz hinten stehen weiter Bäume und einzelne
  Berge.
- Vor den beiden äußeren Häusern liegt keine kahle Fläche: links zwei
  Wasserfelder, rechts ein Feld mit einem Busch darunter. Das Feld ist die
  Lesart `praerie` (Voreinstellung), `korn` wäre ebenso denkbar.
- Büsche sind unauffälliger als Bäume: niedriger, mehrere Ballen, die das
  Feld füllen, statt einer einzelnen Krone.

**Leere und Horizont.** Auf dem hochkanten Bildschirm blieb oben fast die
Hälfte leer. Gelöst ist das durch einen in der Welt verankerten Horizont mit
Abendhimmel und durch die gefüllte Umgebung. Dass der Dunst die hinteren
Tiere verschluckt, ist kein Problem: Sie bleiben ausreichend sichtbar.

**Die Figur.** Das Tier sitzt je nach Landschaft auf dem Dachfirst, auf einer
Blätterkugel der Krone oder auf dem Gipfel. Schwanz und Ohrpinsel sind
bewusst keine Kreise: der Schwanz eine buschige Feder mit Fellkante, die
Pinsel Haarbüschel.

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

Das Eichhörnchen (`figures.py`) kam zuerst; vier weitere folgen im nächsten
Abschnitt. Es ist aus Kreisen und
Ellipsen gebaut, aber wie die Steine schattiert: jedes Teil ein rundes
Volumen, hell oben links, dunkel unten rechts. Der Schwanz ist eine
einzige buschige Feder entlang einer Mittellinie mit Breitenverlauf, außen
mit Fellspitzen und innen mit hellen Strähnen; die Ohrpinsel sind
Haarbüschel. Schwanz, Kopf, Auge und Nuss sind eigene Gruppen mit
Drehpunkt und damit einzeln animierbar.

## Vier weitere Tiere (2026-10-04)

Je eine Landschaft, damit sich zeigt, wie Wasser, Getreide, Berg und Luft
aussehen können. Alle als SVG-Animation; **noch nicht in der App** (der
Export `export.py` ist auf das Eichhörnchen verdrahtet).

```bash
python3 tools/szenen/stories.py                 # alle vier
python3 tools/szenen/stories.py Ente Adler      # einzelne
```

| Tier | Karte (Muster, Würfel) | Figur | Geschichte |
| --- | --- | --- | --- |
| **Ente** | Gebäude + Wasser, 4 Würfel, Würfel auf Wasser | `figures_more.py`: Erpel, an der Wasserlinie abgeschnitten, Ring davor | paddelt von links herein, schaut sich um, gründelt (Heck hoch, Kopf unter Wasser), schüttelt das Heck; Ringe auf dem Wasser |
| **Marienkäfer** | Baum1 + Feld, 5 Würfel, Würfel auf Feld | `fig_bug.py`: von hinten oben, ein Oval, Flügeldecken öffnen sich wie Türen; die Flügel sind bis dahin ganz eingeklappt | **Drei Käfer auf Grasland** (`story_bug.py`): zwei krabbeln langsam durchs Gras (mit Pausen), der dritte krabbelt über einen Busch, bleibt stehen, öffnet die Decken, entfaltet die Flügel und fliegt zu den anderen hinunter; **die Halme davor verdecken sie** (`depth`); Kamera nicht mehr ganz so nah (25 Einheiten breit) |
| **Adler** | Berg3 + Feld, 2 Würfel, Würfel auf Berg3 | `fig_eagle.py`: Weißkopfseeadler, klein und befiedert der Kopf, kurzer Hakenschnabel, lange gefaltete Flügel; `fig_chick.py`: Küken; `nest.py`: Horst | **Horst auf dem Gipfel** (`story_eagle.py`): die Mutter brütet, das Männchen fliegt mit einem Fisch heran, landet am Rand, füttert drei Küken nacheinander und fliegt weiter; Küken und Mutter bleiben, die Kamera zieht zweimal heraus |
| **Rabe** | Gebäude + Feld, 2 Würfel, Würfel auf Feld | dieselbe Vogelfigur, schwarz, schlanker | fliegt über das Feld (Schatten läuft am Boden), landet, hüpft zweimal, ruft dreimal |

**Der Adler** ist seit dem 2026-10-04 größer (`SIZE` 0,085) und wirkt weniger wie ein Geier: Der erste Entwurf (`fig_bird.py`, jetzt nur noch Vorlage des Raben) hatte einen großen kahlen Kopf auf langem Hals und einen hängenden Schnabel. Der Horst ist ein Zwei-Hälften-Zeichnung (`nest.py`): Boden und hintere Kante unter den Tieren, vordere Kante darüber; sie sitzen darin, nicht davor. Die Geschichte steht in einer eigenen Datei, damit eine zweite Sitzung an `stories.py` arbeiten kann.

**Die Flugpose** (`fig_eagle_flight.py`, 2026-10-04). Der erste Flug drehte
Flügelbilder um die Schulter und sah aufrecht aus. Jetzt ist der Flügel eine
flache Form (Arm, Hand, fünf gespreizte Handschwingen), die im Raum um den
Körper gedreht und flachgedrückt wird, Bild für Bild: Der Adler fliegt
waagrecht, der Kopf vorgestreckt, der Schwanz ein weißer Fächer, die Beine
angezogen. Eben ausgestreckt hängt der nahe Flügel zu uns herab und der
ferne ragt nach oben weg; angehoben zeigen beide nach oben; im Abschlag
fährt der nahe am Bauch vorbei, und die Hand bleibt im Schlag zurück und
knickt am Handgelenk. Die Geschichte gibt je Bild zwei Winkel
(`wing_paths(arm, hand)`), die Pfade laufen als `d`-Animation (neue Teileart
`path` in `anim.py`). Zum Landen richtet sich die Figur auf (Drehung um die
Krallen), faltet die Flügel und wird nach 0,4 s durch die sitzende abgelöst;
zum Abflug umgekehrt.

**Warum Adler und nicht Lama.** Der Würfel des Lamas liegt auf dem Feld
neben dem Berg, nicht auf dem Berg. Der Adler (Berg3 + Feld) hat ihn auf dem
Gipfel und deckt zugleich das Fliegen ab; der Rabe fliegt, landet aber auf
dem Feld, weil seine Karte es so verlangt.

**Aufbau.**

| Datei | Inhalt |
| --- | --- |
| `anim.py` | schreibt eine Geschichte als animiertes SVG, für jede Figur: Füße, Blickrichtung (`face`), Drehung (`rot`), Stauchung, Kamera, Teile mit Drehpunkt (`rotate`, `translate`, `scale`), Schatten auf dem Boden, Ringe (`below`) |
| `stories.py` | die vier Geschichten, Bild für Bild: `Setup` liefert Szene, Zielfeld und die drei Kameraausschnitte (nah, weit, Lebensraum) |
| `figures_more.py` | Farbtöne der neuen Figuren, Erpel |
| `fig_bug.py`, `fig_bird.py` | Marienkäfer; Adler und Rabe aus einem Bau (`bird_body`) |
| `cards.py` | `MIX` und `BEHIND` je Tier: Wasser um die Ente, Felder um den Käfer, Berge um den Adler, Äcker um den Raben |

**Ansehen.** Die Vorschau hakt bei SMIL: `qlmanage` zeichnet es nicht. Im
Browser (zum Beispiel lokal mit `python3 -m http.server -d tools/szenen/out`)
lässt sich eine Stelle anspringen:

```js
const s = document.documentElement; s.pauseAnimations(); s.setCurrentTime(6.5)
```

**Was noch fehlt.** Es sind erste Entwürfe, nicht abgenommen: Die Figuren
sind klein im Bild (der Lebensraum-Ausschnitt zeigt alle Würfel, nicht nur
den ersten), der Erpel taucht nur mit dem Kopf, der Adler ähnelt einem Geier,
und die Flügelschläge sind grob (ein Flügel dreht sich um die Schulter,
Verkürzung fehlt). Die zweiten und dritten Tiere je Karte kommen nicht vor.

**Übergabe (Stand 2026-10-04, Rückmeldung: „gute Anfänge, überarbeiten").**
Zwei Sitzungen arbeiten daran, deshalb hier der Stand, damit keine die
andere überrascht:

- Die vier Entwürfe sind unverändert so, wie sie committet sind; was
  zuerst anzufassen wäre, steht im Absatz davor. Gestaltet wird über
  Bilder, ein Wunsch pro Runde.
- Eine Änderung an einer Figur oder Geschichte betrifft nur ihre Datei
  (`figures_more.py`, `fig_bug.py`, `fig_bird.py`, `stories.py`); `anim.py`,
  `scene.py`, `cards.py` gelten für alle Tiere, dort Änderungen absprechen.
- Nicht in der App sind die vier Tiere und ihre Szenen. Der Weg dahin ist
  der des Eichhörnchens (*In der App*): `export.py` auf einen Tiernamen
  und `SquirrelTimeline` auf eine Zeitleiste je Tier verallgemeinern; eine
  Liste je Tier ist rund 0,5 MB, siehe *Noch offen*.
- Offene Messung: Rechenzeit der Szene auf dem iPhone (kein Gerät
  angeschlossen gewesen).
- Die Sitzungen haben je einen eigenen Worktree und Branch (`szenen1`,
  `szenen2`, beide unter `.claude/worktrees/`). `szenen2` zweigt vom Stand
  `6e6210a` ab, vor dieser Notiz. Zusammengeführt wird später per Merge;
  Konflikte sind in `anim.py`, `scene.py`, `cards.py` und `stories.py` zu
  erwarten, wo beide Seiten Tiere eintragen (`STORIES`, `MIX`, `SIZE`).

## Noch offen

- Die Animationen 2 und 3 je Karte: Tier k kommt auf sein Würfelfeld, die
  früheren sitzen schon an ihren Plätzen. `cards.build(name, arrived=k)`
  liefert die Szene dafür.
- Die übrigen 31 Tiere; bis dahin steht auf dem Würfelfeld ein Würfel.
- Umgebung (`MIX`) und Feldlesart je Tier festlegen.
- Ob der Dunst innerhalb eines zusammenhängenden Gebirges einheitlich
  sein soll.
- Die Rechenzeit der Szene auf dem Gerät. Wird sie zu knapp, bieten sich an:
  die Felder (über 1000 Halme) nur nahe vor der Kamera zeichnen, oder die
  ruhende Kulisse je Kameraschritt zwischenspeichern.
- Die Liste ist mit 480 KB groß, weil sie jede Form einzeln ausschreibt.
  Für mehr als ein Tier wird eine gemeinsame Kulisse oder eine Verdichtung
  (Halme und Wellen aus Formeln) nötig.
