# Prüfverfahren

Wie wir prüfen, dass Harmony tut, was sie soll. Festgelegt am 2026-09-19.

Dieses Dokument gehört zu keiner Phase. Es beschreibt das Vorgehen, nicht
den Gegenstand — so wie `kartennotation.md` beschreibt, wie erfasst wird,
und nicht, was auf den Karten steht.

## Abgrenzung

Geregelt wird hier, **wie** geprüft wird: welche Stockwerke es gibt, woher
Sollwerte kommen, wie Testfälle aussehen. **Was** geprüft wird, ergibt sich
aus den Regeln und dem Funktionsumfang und steht dort.

Nicht geregelt wird, wann gebaut wird. Am Ende steht ein Vorschlag dazu,
keine Festlegung.

## Der eine Grundsatz

**Ein Sollwert, der aus dem Programm stammt, prüft nichts.** Er beschreibt
nur, was das Programm gerade tut — auch wenn es falsch ist.

Das ist derselbe Gedanke wie die Prüfschleife in `kartennotation.md`, die
„richtig diktiert" von „richtig verstanden" trennt. Für Tests heißt er:

- Wo eine **Regel** geprüft wird, ist der Sollwert von Hand gerechnet oder
  stammt aus der Anleitung. Niemals aus einem Programmlauf.
- Wo das **Verhalten** festgehalten wird (Stockwerk 2), darf der Wert aus
  dem Programm stammen — aber dann ist er ausdrücklich eine
  Momentaufnahme und kein Sollwert, und eine Änderung verlangt, dass ein
  Mensch hinsieht.

Diese beiden zu vermischen macht die ganze Suite wertlos: Sie geht grün
durch, egal was sie misst.

## Die drei Stockwerke

| | Stockwerk | Prüft | Anzahl | Wann |
| --- | --- | --- | --- | --- |
| 1 | **Regelkern** | Wertung, Mustererkennung, Zuggenerierung | viele, je Millisekunden | mit der ersten Engine-Zeile |
| 2 | **Ganze Partien** | dass eine Partie regelkonform durchläuft | wenige Dutzend, kopflos | vertagt |
| 3 | **Oberfläche** | den Eingabeweg, nicht die Spiellogik | eine Handvoll | mit dem Klickdummy |

Die Form ist eine Pyramide: Je höher das Stockwerk, desto langsamer und
launischer der Test, desto weniger davon.

## Stockwerk 1 — Regelkern

Das Fundament und das einzige, das sofort gebraucht wird.

Geprüft werden reine Funktionen über Datenstrukturen: Brett rein, Zahl
raus. Keine Oberfläche, kein Simulator, keine App. Voraussetzung ist, dass
die Engine ein **eigenes Modul** ist und nicht zwischen den Views liegt —
nur dann laufen diese Tests ohne Host-App und damit in Sekunden statt
Minuten. Das ist eine Auflage an Phase 4, die faktisch hier entsteht.

Testfälle sind **handgebaute Kleinstellungen**: so wenige Steine wie
möglich, jede auf genau eine Regel gerichtet. Die lohnenden Fälle sind die,
bei denen die Regel überrascht:

- ein Berg ohne Bergnachbarn — 0 statt 1/3/7,
- ein grauer Stapel mit rotem Stein obendrauf — Gebäude, und **kein**
  Bergnachbar für den Berg daneben,
- ein Gebäude am Spielplanrand — leere Nachbarfelder zählen nicht mit,
- ein einzelner gelber Stein — 0, erst zwei angrenzende geben 5,
- ein brauner Stein ohne grün — 0,
- ein verzweigter Fluss — der Ast außerhalb der längsten Kette zählt nicht,
- ein Muster in einer gedrehten Lage, die nicht die kanonische ist,
- ein Muster, dessen Zielstein bereits einen Tierwürfel trägt,
- ein Tierwürfel, der liegenbleibt, nachdem das Muster überbaut wurde.

Die Sollwerte kommen von Hand. Wo die Anleitung ein gewertetes Beispiel
zeigt, ist dessen Punktzahl die beste Quelle überhaupt, weil sie nicht von
uns stammt.

**Prüfschleife wie bei den Karten:** Eine Stellung wird aus der Notation
zurückgezeichnet, bevor ihr Sollwert festgeschrieben wird. Ein
Missverständnis über die Stellung sieht sonst genauso aus wie ein Fehler in
der Wertung.

## Stockwerk 2 — Ganze Partien (vertagt)

Eine vollständige Partie, kopflos durchgespielt, ohne Oberfläche.

**Vertagt, weil es nichts zu prüfen gibt, solange keine Engine existiert.**
Der Aufbau wird hier trotzdem festgelegt, aus einem Grund: Sein
Fixture-Format braucht Stockwerk 3 ebenfalls, und zwei Formate für
denselben Zweck wären einer zu viel.

### Invarianten

Bedingungen, die in **jeder** Partie gelten, unabhängig davon, wie gut
Harmony spielt. Sie überleben jede Änderung der Bewertungsfunktion und sind
damit das eigentliche Regressionsnetz.

- Jeder Zug nimmt genau 3 Steine und legt genau 3 Steine.
- Kein Stapel verletzt die Stapelregeln, keine Höhe über 3.
- Kein Tierwürfel liegt auf einem Muster, das nicht exakt passt.
- Nie mehr als 4 unabgeschlossene Tierkarten gleichzeitig.
- Aus dem Beutel werden nie mehr als 120 Steine gezogen.
- Die Partie endet, und zwar durch einen der beiden Auslöser.
- Alle Spieler hatten am Ende gleich viele Züge.
- Die Endpunktzahl stimmt mit einer **unabhängigen** Nachrechnung überein.

Der letzte Punkt hat eine Falle: Die Wertungsfunktion gegen sich selbst zu
prüfen ist zirkulär. Unabhängig ist die Nachrechnung nur, wenn sie aus
einer anderen Quelle stammt — eine bewusst naive Zweitfassung, etwa in
Python neben `tools/pruefe-tierkarten.py`, erfüllt das. Zwei Fassungen
derselben Regel sind selten gleich falsch.

### Momentaufnahme

Zusätzlich wird das **Zugprotokoll** mitgeschrieben und abgelegt: lesbar,
zeilenweise, diffbar.

Es ist ausdrücklich **kein Sollwert**. Verbessert jemand die
Bewertungsfunktion, ändert sich das Protokoll — das ist der Zweck der
Übung, nicht ein Fehler. Der Test schlägt deshalb nicht fehl, sondern legt
den Unterschied vor. Die Regel dazu:

- Ein geänderter Diff wird **gelesen**, nicht blind übernommen.
- Wer neu abnimmt, schreibt in die Commit-Nachricht, warum die Änderung
  richtig ist.
- Ändert sich ein Protokoll, das sich gar nicht ändern sollte — etwa nach
  einem reinen Umbau ohne Verhaltensänderung —, ist das ein Fund.

## Stockwerk 3 — Oberfläche

XCUITest, ein eigener Target-Typ. Er startet die App im Simulator als
eigenen Prozess und bedient sie über die Bedienungshilfen-Hierarchie,
dieselbe Schnittstelle, die auch VoiceOver benutzt.

Diese Tests prüfen **den Eingabeweg, nie die Spiellogik**. Die gehört ins
Fundament, wo sie tausendmal schneller läuft.

### Antippzahl statt Sekunden

Phase 2 ließ offen, was „schnell genug" heißt, und nannte es eine
Anforderung ohne Zahl. Sekunden taugen dafür nicht — sie hängen am Gerät
und an der Tagesform des Simulators.

**Antippvorgänge dagegen sind deterministisch und zählbar.** „Ein fremder
Zug ist mit höchstens *n* Antippern erfasst" ist eine prüfbare Zusicherung,
die genau das Kriterium bewacht, das Phase 1 an die erste Stelle gesetzt
hat. Wird die Oberfläche umständlicher, schlägt der Test an, bevor es am
Tisch auffällt.

Die Zahl *n* steht noch nicht fest; sie ergibt sich aus dem ersten
Prototyp. Gegen den kann man sie sogar schon messen, bevor irgendeine
Funktion dahintersteckt — der Eingabeweg ist genau das, was ein Klickdummy
bereits vollständig enthält.

### Drei Regeln

**Bezeichner statt Beschriftungen.** Elemente werden über
`accessibilityIdentifier` angesprochen, nie über sichtbaren Text. Sonst
bricht jeder Test, sobald eine deutsche Beschriftung umformuliert wird. Die
Bezeichner sind ein Vertrag zwischen View und Test — und die Unterstützung
für Bedienungshilfen fällt dabei ab.

**Determinismus über Startparameter.** Die App startet im Test mit einem
Verweis auf eine Ziehfolge (`launchArguments`), dieselbe, die auch
Stockwerk 2 benutzt.

**Kein Bildvergleich.** XCUITest heftet Bildschirmfotos ans Protokoll, aber
es gibt keine eingebaute Zusicherung „sieht aus wie beim letzten Mal".
Echte visuelle Regression bräuchte eine Fremdbibliothek. Für v1 nicht.

## Ziehfolgen

Das gemeinsame Fixture-Format für Stockwerk 2 und 3.

Eine Ziehfolge ersetzt den Zufall, sonst nichts. Sie besteht aus genau zwei
Listen:

- die **Reihenfolge des Beutels** — alle 120 Steine, aus denen die ersten
  15 die Auslage füllen und je 3 eine Nachfüllung,
- die **Reihenfolge des Kartenstapels** — alle 32 Karten, aus denen die
  ersten 5 offen liegen.

Mehr braucht es nicht. Wer wann welches Feld nimmt, ist eine Entscheidung
der Spieler und gehört nicht ins Fixture.

### Steinkürzel

Steine sind **Farben**, keine Landschaften — eine Landschaft entsteht erst
beim Legen. Das Vokabular aus `kartennotation.md` ist deshalb nicht
dasselbe, auch wenn es sich an drei Stellen deckt.

| Zeichen | Farbe | Merkhilfe | Anzahl |
| --- | --- | --- | --- |
| `W` | blau | Wasser | 23 |
| `S` | grau | Stein | 23 |
| `H` | braun | Holz | 21 |
| `L` | grün | Laub | 19 |
| `K` | gelb | Korn | 19 |
| `Z` | rot | Ziegel | 15 |

Jeder Name bezeichnet das **Material**, das der Stein in jedem Fall ist,
nie eine Rolle, die er nur manchmal spielt. Ein roter Stein kann Unterbau
statt Dach sein — ein Gebäude darf aus zwei roten Steinen bestehen —, ein
brauner Gerüst statt Stamm. Ziegel und Holz bleiben sie dabei. So liest
sich auch ein Gebäude natürlich: Ziegel auf Holz, Stein oder Ziegel.

Die Steinnotation teilt sich mit den Landschaftskürzeln aus
`kartennotation.md` bewusst **keine** Buchstaben außer `W`.
Landschaften sind, was man baut; Steine sind, woraus man baut. Eine frühere
Fassung ließ `W`, `F` und `M` in beiden Notationen dasselbe bedeuten, weil
Wasser, Feld und Berg einfarbig sind — das war hübsch, zwang aber für Grau
und Gelb Landschaftsnamen auf („Massiv", „Feld"), wo ein Material gemeint
ist. Die Trennung ist wichtiger; `kartennotation.md` verlangt sie ohnehin.

Gelb heißt `K` für Korn, nicht `G` für Getreide: `G` ist dort bereits das
Gebäude. Umgekehrt wurde `H` für Holz frei, indem das Gebäude von „Haus"
auf „Gebäude" umbenannt wurde — so sprechen auch die Regeln durchgehend.
Die Kurzform dient nur dem Diktieren, die abgelegten Kartendaten stehen in
Langform; keine Umbenennung berührt sie.

Wie in `kartennotation.md` sind die Buchstaben nach Eindeutigkeit gewählt,
nicht nach Anfangsbuchstaben: Blau und Braun beginnen beide mit B, Grau,
Grün und Gelb alle drei mit G.

### Form

```
Ziehfolge: akzeptanz-01
Beutel:    WSH LKK ZSS WWL HHK ...     (120 Steine, in Ziehreihenfolge)
Stapel:    Pinguin Biene Lachs Wolf Rabe Frosch ...   (32 Karten)
```

Die Dreiergruppen im Beutel sind reine Lesehilfe — so werden die Steine
gezogen. Eine Ziehfolge ist gültig, wenn sie genau 120 Steine mit der
richtigen Farbverteilung und genau 32 verschiedene Karten enthält. Das
prüft ein Werkzeug, nicht ein Mensch.

### Woher Ziehfolgen kommen

**Erzeugt**, mit einem Startwert. Der Startwert steht in der Datei, damit
sie sich neu erzeugen lässt, aber **maßgeblich ist die Datei**, nicht der
Startwert: Sobald die Engine Zufallszahlen anders verbraucht, liefert
derselbe Startwert eine andere Folge — die abgelegte Ziehfolge bleibt.

Mitgeschriebene echte Partien sind vorerst nicht vorgesehen. Sie werden
allerdings fast umsonst, sobald v1 steht: Der Zugverlauf mit Rücknahme
(Funktion 5 aus Phase 3) ist bereits eine Aufzeichnung genau dieser Daten.
Ihn in eine Datei zu schreiben, macht aus einer Partie am Tisch einen
Testfall. Vermerkt, nicht eingeplant.

## Vorschlag zum Zeitpunkt

Kein Beschluss, nur eine Reihenfolge, die aus dem Obigen folgt:

1. **Jetzt nichts.** Es gibt keinen Engine-Code, also nichts zu prüfen.
2. **Mit der ersten Engine-Zeile** ein Unit-Test-Target und Stockwerk 1.
   Die Tests entstehen mit der Regel, nicht danach — nachträglich
   angelegte Tests prüfen meist nur, was das Programm ohnehin tut.
3. **Mit dem Klickdummy** ein UI-Test-Target, zunächst mit einem einzigen
   Test: der Antippzahl für einen fremden Zug.
4. **Wenn eine Partie durchläuft**, Stockwerk 2.

Das Anlegen der Targets ändert `project.pbxproj` und ist damit keine
Nebenbei-Änderung, siehe `CLAUDE.md`. Bis dahin gilt dort weiterhin: keine
`xcodebuild test`-Aufrufe erfinden.

## Nicht gewählt, weil

- **Startwert statt Ziehfolge** — kompakter, aber nicht stabil: Ein Umbau
  der Engine verschiebt den Zufallsverbrauch und damit jede abgelegte
  Erwartung. Regressionstests, die bei jedem Umbau neu abgenommen werden
  müssen, werden nach der dritten Runde gelöscht.
- **Exakte Zugfolge als Sollwert** — ließe jede Verbesserung der
  Bewertung als Fehler erscheinen. Dasselbe Schicksal.
- **Nur Invarianten, ohne Momentaufnahme** — überlebt alles, sieht aber
  nicht, wenn Harmony plötzlich schlechter spielt. Der Diff ist das
  einzige Frühwarnzeichen, das wir bekommen können.
- **Visuelle Regression in v1** — braucht eine Fremdbibliothek für einen
  Nutzen, den bei einer Oberfläche in Bewegung niemand einlöst.
- **UI-Tests für Spiellogik** — sie liefe dort tausendmal langsamer und
  brächte keine einzige zusätzliche Erkenntnis.
- **Rollennamen statt Materialien** — „Stamm" für Braun, „Dach" für Rot,
  „Massiv" für Grau. Alle drei beschreiben, was der Stein manchmal wird,
  nicht was er ist, und „Ziegel auf Massiv" für ein Steinhaus liest sich
  schief. *Massiv* ist als Substantiv für ein Gebirge ohnehin selten.
- **Buchstaben, die beide Notationen teilen** — siehe oben; die Ersparnis
  kostete die Materialbenennung und damit mehr, als sie einbrachte.
