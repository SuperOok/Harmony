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

## Steinkürzel

Steine sind **Farben**, keine Landschaften — eine Landschaft entsteht erst
beim Legen. Das Vokabular aus `kartennotation.md` ist deshalb nicht
dasselbe, auch wenn es sich an drei Stellen deckt.

| Zeichen | Farbe | Merkhilfe | Anzahl |
| --- | --- | --- | --- |
| `W` | blau | Wasser | 23 |
| `S` | grau | Stein | 23 |
| `H` | braun | Holz | 21 |
| `L` | grün | Laub | 19 |
| `F` | gelb | Feld | 19 |
| `Z` | rot | Ziegel | 15 |

Die Namen folgen einer Regel, die aus den Stapelregeln kommt: **Auf Blau
und Gelb kann nie etwas gestapelt werden.** Diese beiden Steine *sind*
ihre Landschaft — ein blauer Stein ist Wasser, ein gelber ein Feld, und
mehr kann aus ihnen nicht werden. Sie heißen deshalb wie die Landschaft und
teilen sich `W` und `F` mit `kartennotation.md`.

Die übrigen vier sind **Zutaten**. Grau und Braun können unter einem
Gebäude liegen, Braun außerdem unter Laub, Rot auf Rot. Keiner von ihnen
ist verlässlich das, wozu er meistens wird, also heißen sie nach dem
Material, das sie immer sind: Stein, Holz, Laub, Ziegel. Ein Gebäude liest
sich damit natürlich — Ziegel auf Holz, Stein oder Ziegel.

`S` taucht drüben ebenfalls auf, aber nur mit Höhenziffer: `S1` bis `S3`
ist der Berg, also ein Stapel aus so vielen Steinen. Ohne Ziffer ist `S`
hier ein einzelner grauer Stein.

Weder „Massiv" für Grau noch „Korn" für Gelb wären richtig gewesen. Das
erste ist ein Landschaftswort für einen Stein, der ebenso gut ein Gebäude
trägt; das zweite behauptet ein angelegtes Getreidefeld, wo die Anleitung
auch offenes Land meinen kann, etwa Steppe.

Damit `H` für Holz frei wurde, heißt das Gebäude in `kartennotation.md`
`G` statt `H`; es hieß dort „Haus", obwohl die Regeln durchgehend von
Gebäuden sprechen. Die Kurzform dient nur dem Diktieren, die abgelegten
Kartendaten stehen in Langform — keine Umbenennung berührt sie.

Wie in `kartennotation.md` sind die Buchstaben nach Eindeutigkeit gewählt,
nicht nach Anfangsbuchstaben: Blau und Braun beginnen beide mit B, Grau,
Grün und Gelb alle drei mit G.

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

### Form

```
Ziehfolge: akzeptanz-01
Beutel:    WSH LFF ZSS WWL HHF ...     (120 Steine, in Ziehreihenfolge)
Stapel:    Pinguin Biene Lachs Wolf Rabe Frosch ...   (32 Karten)
```

Die Dreiergruppen im Beutel sind reine Lesehilfe — so werden die Steine
gezogen. Innerhalb einer Gruppe bedeutet die Reihenfolge nichts, siehe
Zugnotation. Eine Ziehfolge ist gültig, wenn sie genau 120 Steine mit der
richtigen Farbverteilung und genau 32 verschiedene Karten enthält. Das
prüft ein Werkzeug, nicht ein Mensch.

### Woher Ziehfolgen kommen

**Erzeugt**, mit einem Startwert. Der Startwert steht in der Datei, damit
sie sich neu erzeugen lässt, aber **maßgeblich ist die Datei**, nicht der
Startwert: Sobald die Engine Zufallszahlen anders verbraucht, liefert
derselbe Startwert eine andere Folge — die abgelegte Ziehfolge bleibt.

Abgelegte Protokolle tragen **neutrale Spielernamen**, „Spieler 1" und so
fort. Das Repository ist öffentlich, und ein Testfall aus einer echten
Partie enthielte sonst die Vornamen von Leuten, die davon nichts wissen.
Beim Ablegen wird ersetzt, nicht beim Spielen.

Mitgeschriebene echte Partien sind vorerst nicht vorgesehen. Sie werden
allerdings fast umsonst, sobald v1 steht: Der Zugverlauf mit Rücknahme
(Funktion 5 aus Phase 3) ist bereits eine Aufzeichnung genau dieser Daten.
Ihn in eine Datei zu schreiben, macht aus einer Partie am Tisch einen
Testfall. Vermerkt, nicht eingeplant.

## Brettnotation

Wie eine Stellung auf einem persönlichen Spielplan aufgeschrieben wird —
das Fixture-Format für die Kleinstellungen aus Stockwerk 1.

### Eine Zelle ist ein Stapel

Geschrieben mit den Steinkürzeln, **von unten nach oben**. Die Richtung ist
keine Erfindung dieser Datei: `regeln-basisspiel.md` legt sie für
Datenstrukturen bereits fest, während Prosa umgekehrt liest — „X auf Y"
heißt dort X oben.

| Zelle | Bedeutung |
| --- | --- |
| `W` · `F` | Wasser · Feld |
| `L` · `HL` · `HHL` | Baum der Höhe 1 · 2 · 3 |
| `S` · `SS` · `SSS` | Berg der Höhe 1 · 2 · 3 |
| `HZ` · `SZ` · `ZZ` | Gebäude, je nach Unterbau |
| `H` · `Z` | nackter brauner bzw. roter Stein — keine Landschaft, 0 Punkte |

### Kein Landschaftsvokabular

Das Brett kommt ohne die Wörter Wasser, Baum, Berg und Gebäude aus, und das
ist der Zweck der Übung. Wer eine Teststellung in Landschaften aufschreibt,
setzt die Einordnung bereits voraus, die die Wertungsfunktion erst leisten
soll: `Berg2` zu notieren behauptet schon, dass zwei graue Steine ein Berg
sind. In Steinen notiert, prüft der Testfall diese Einordnung mit.

Zweiter Gewinn: In Steinen lassen sich auch **unzulässige** Stapel
hinschreiben — `ZZZ`, `WL`, `HHH`. Erst dadurch wird die Legalitätsprüfung
überhaupt testbar. Ein Format, das nur Gültiges ausdrücken kann, taugt nicht
zum Prüfen dessen, was Ungültiges erkennen soll.

### Die drei Gebäudetypen

Sie brauchen kein eigenes Zeichen; `HZ`, `SZ` und `ZZ` fallen aus der
Stapelschreibweise ab.

Für die **Wertung** ist der Unterbau ohnehin gleichgültig — bei der
Gebäudebedingung zählt nur der oberste Stein jedes Nachbarfeldes. Für
**Kartenmuster** ebenfalls, dort ist er laut Regeln beliebig. Und für
**spätere Züge** auch: Auf einem roten Stein darf nichts liegen, die
einzigen Dreierstapel sind `SSS` und `HHL`, ein Gebäude ist also endgültig.

Gebraucht wird die Unterscheidung an genau einer Stelle, dafür an einer
wichtigen: der **Steinerhaltung** als Invariante. Über Beutel, Auslage und
alle Tableaus müssen je Farbe 23/23/21/19/19/15 Steine herauskommen.
Vergisst das Brett den verdeckten Stein, ist diese Prüfung unmöglich — und
sie fängt fast jeden Buchführungsfehler.

In `kartennotation.md` bleibt es dagegen bei `G` ohne Zusatz. Dort wäre die
Unterscheidung nicht nur überflüssig, sondern schädlich: Eine Notation, die
einen für das Muster bedeutungslosen Unterschied ausdrücken **kann**,
verleitet dazu, ihn zu erfassen — und später jemanden dazu, darauf zu
vergleichen.

### Form

```
Stellung:  berg-ohne-nachbarn
Seite:     A
Felder:    32=SS  51=W
Würfel:    —
Erwartet:  Berge 0 · Wasser 0 · gesamt 0
```

- **Felder** listet nur belegte Zellen, alles andere ist leer. Eine Zelle
  heißt `<Spalte><Zeile>`, beide ab 1 und immer zweistellig — `32` ist die
  zweite Zelle der dritten Spalte. Dieselbe Regel gilt auf beiden
  Spielplanseiten und auf der Kartenschablone, siehe
  `regeln-basisspiel.md`.
- **Würfel** nennt die Zellen mit einem Tierwürfel. Er macht den Stein
  besetzt und damit für weitere Muster unbrauchbar.
- **Erwartet** ist der von Hand gerechnete Sollwert, **nie** ein
  Programmlauf. Er wird **aufgeschlüsselt** notiert, nicht nur als Summe:
  Eine Gesamtzahl verbirgt zwei Fehler, die einander aufheben.

Die Prüfschleife gilt wie bei den Karten — die Stellung wird aus der
Notation zurückgezeichnet, bevor ihr Sollwert festgeschrieben wird.

## Zugnotation

Gebraucht an vier Stellen, die schon festgeschrieben sind: im **Zugprotokoll**
der Momentaufnahme, im **Zugverlauf** für die Rücknahme aus Störfall A, in der
**Begründung**, die den zweitbesten Zug benennen muss, und beim **Debuggen**
der Suche.

Ein Zug ist eine **geordnete Folge von Aktionen**. Fünf Formen genügen,
und ein Zug benutzt nie alle:

| Form | Bedeutung |
| --- | --- |
| `<Stein><Zelle>` | Spielstein legen, z. B. `H32` |
| `T<Zelle>/<Karte>` | Tierwürfel setzen, von dieser Karte genommen |
| `+<Karte>` | Tierkarte nehmen |
| `-<Steine>` | Auslagenfeld genommen, über seinen Inhalt benannt |
| `><Steine>` oder `><Karte>` | aus dem verdeckten Vorrat nachgerückt |

Jede Zeile beginnt mit dem Spieler. Harmonys Zug:

```
Harmony  H32 L32 S43 T32/Pinguin  +Biene  >WSF >Wolf
```

Holz auf 3.2, Laub darauf — zusammen ein Baum der Höhe 2 —, Stein auf 4.3,
ein Tierwürfel **von der Pinguinkarte** auf den Baum, die Bienenkarte
genommen; nachgefüllt wurden Wasser, Stein, Feld und die Wolfskarte.

Die Karte beim Würfel ist nicht schmückend. Ein Würfel wird stets von einer
bestimmten Karte genommen, und zwar ihr unterster; welche Karte, entscheidet
über die Punkte. Am Tisch muss der Betreuer wissen, von welcher Karte er ihn
nehmen soll, und im Protokoll wäre `T32` mehrdeutig, sobald zwei Karten
dieselbe Zelle bedienen könnten.

Ein fremder Zug:

```
Anke     -HLZ  +Pinguin  >WSF >Wolf
```

Anke nahm das Feld mit Holz, Laub und Ziegel, nahm die Pinguinkarte;
nachgerückt sind dieselben vier Dinge wie oben.

Der Unterschied ist kein Sonderfall, sondern folgt aus dem, was sichtbar
ist: Bei Harmony sind die Platzierungen bekannt und benennen das genommene
Feld bereits, bei einem Mitspieler ist **nur** das genommene Feld bekannt
und keine einzige Platzierung.

Der Spielername vorn ist nicht bloß Zierde: Er ordnet die Kartennahme einem
Mitspieler zu, woraus dessen Farbnachfrage folgt — siehe
`04-architektur.md`.

### Stapeln braucht kein Zeichen

Dieselbe Zelle zweimal heißt, der zweite Stein kommt obenauf. `H32 L32` ist
die Brettnotation `32=HL`, nur zeitlich statt räumlich aufgeschrieben.

### Bei Harmony steht das genommene Feld nicht dabei

Man nimmt alle 3 Steine eines Feldes und legt alle 3. Die gelegten Steine
**sind** also das genommene Feld — oben `H`, `L`, `S`. Es zusätzlich
hinzuschreiben wäre nicht nur überflüssig, sondern eine Stelle, an der sich
ein Protokoll selbst widersprechen kann. Bei einem fremden Zug gibt es
diese Wahl nicht: Dort ist `-HLZ` das einzige, was überhaupt sichtbar war.

Über eine Nummer ließe es sich ohnehin nicht benennen: Die fünf Felder des
gemeinsamen Spielplans tragen keine Beschriftung und liegen im Kreis. Wer
am Tisch „Feld 3" sagt, muss erst klären, wo gezählt wird. Über den Inhalt
findet man es sofort.

### Die Auslage hat keine Reihenfolge

Weder die fünf Felder untereinander noch die drei Steine innerhalb eines
Feldes. Bei der Eingabe darf es deshalb auf keine Reihenfolge ankommen —
wer `HLS` tippt, meint dasselbe Feld wie mit `SLH`.

Liegen zwei Felder gleich, sind sie austauschbar: Welches physisch genommen
wurde, ändert den Zustand nicht. Für Phase 4 heißt das, die Auslage ist eine
**Mehrfachmenge aus fünf Tripeln**, kein Array mit Plätzen.

### Die Reihenfolge der Aktionen dagegen zählt

Und zwar wirklich. Man darf einen Stein auf einen soeben gelegten setzen,
und ein Tierwürfel sperrt seinen Stein fürs Weiterbauen — „nie auf oder
unter einen Tierwürfel". `H32 T32 L32` ist deshalb **unzulässig**,
`H32 L32 T32` gültig. Nur eine geordnete Folge kann diesen Unterschied
ausdrücken und damit prüfbar machen.

**Konvention:** Tierwürfel werden so weit hinten geschrieben, wie es
dasselbe Ergebnis liefert. In der großen Mehrzahl der Züge stehen die drei
Steine dann vorn, und das genommene Auslagenfeld steht auf den ersten Blick
da.

Eine Ausnahme bleibt, und sie ist beabsichtigt: Wer ein Muster vollendet,
den Würfel setzt und mit einem weiteren Stein darüberbaut, **muss**
verschachteln — später ginge es nicht mehr, weil das Muster dann zerstört
ist. Diese Züge fallen im Protokoll auf, und das ist richtig so; sie sind
eine der Möglichkeiten, die ein naiver Bewerter nie erwägt. Nebenbei hat
damit jedes Ergebnis genau eine Schreibweise, was die Diffs stabil hält.

### Karten heißen beim Namen

`+Pinguin`, nicht `+K07`. Die Namen sind laut `kartennotation.md` unsere
Etiketten, aber sie sind eindeutig — `tools/pruefe-tierkarten.py` erzwingt
das —, und am Tisch vorlesbar. Eine Nummer wäre ein zweiter erfundener
Identifikator ohne diesen Vorteil.

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
- **`K` für Korn bei Gelb** — konsequent nach Material benannt, aber zu
  viel behauptet: Ein gelber Stein ist nicht zwangsläufig ein angelegtes
  Getreidefeld, sondern ebenso offenes Land. `F` für Feld trifft es und
  deckt sich mit der Landschaft, weil ein gelber Stein nie etwas anderes
  wird.
- **Nummern für die Tierkarten** — die Namen sind erfunden, aber eindeutig
  und vorlesbar; eine Nummer wäre ein zweiter erfundener Identifikator ohne
  diesen Vorteil.
- **Das genommene Auslagenfeld im Zug benennen** — überflüssig, weil die
  drei gelegten Steine es bereits sind, und eine Gelegenheit für
  Widersprüche im Protokoll.
- **`GZ`, `GH`, `GS` für die drei Gebäudetypen** — die Unterscheidung wird
  gebraucht, aber sie fällt aus der Stapelschreibweise ohnehin ab. Ein
  eigenes Zeichen wäre ein zweiter Weg, dasselbe zu sagen, und das
  Landschaftswort „Gebäude" gehört gar nicht aufs Brett.
- **Alle sechs Buchstaben von den Landschaften trennen** — wäre eine
  klarere Ansage, aber `W` und `F` bedeuten in beiden Notationen wirklich
  dasselbe. Einen Unterschied zu erfinden, wo keiner ist, hilft niemandem.
