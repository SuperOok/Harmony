# Harmony

SwiftUI-App (iOS, iPadOS), gebaut mit Xcode 27.

Harmony stellt einen Computer-Mitspieler für das Brettspiel **Harmonies**.
Die Partie läuft am echten Tisch mit echtem Material; die App verwaltet nur
das Wissen eines einzelnen Spielers und schlägt dessen Züge vor. Sie ist
keine Digitalfassung des Spiels. Siehe `docs/` für Produktkern und Konzept.

Der Code ist zweierlei. `MyApp/` ist die App: hervorgegangen aus dem
**Klickdummy** aus Phase 5, dessen Ansichten unter `MyApp/Game/` liegen
(bis zum 2026-09-29 `Dummy/`), und seit Phase 6 mit der Engine verbunden. `HarmonyRules/` ist
ein Swift Package mit den **Regeln**, der **Engine**, dem **Tisch** für
Engines gegeneinander und den Mess- und Simulationswerkzeugen — ohne
Xcode-Projekt prüfbar.

**Wo es steht:** Stand 2026-10-03; Messungen, Entscheidungen und die Befehle
für Selbstspiel und `HarmonyMatch` stehen in `docs/stand.md`. Der Durchstich
aus Phase 6 trägt und läuft **auf dem Gerät**: Die App rechnet ihre Züge
selbst, eine Partie beginnt mit leerem Spielplan und füllt sich, und sie
überdauert das Weglegen. Geprüft wird mit 240 Regelfällen (`tools/tests.sh`,
gut drei Sekunden), 41 App-Fällen (`tools/apptests.sh`) und acht
Oberflächenfällen (`tools/uitests.sh`).

Was es gibt, in Stichworten:

- **Ein Zustand:** `GameState` umschließt einen `EngineState`; Ereignisse
  tragen sich über `recordTurn`, `recordOwnTurn` und `correct` ein
  (`EngineState+Record.swift`). `Table.play` und `SelfPlay` benutzen diesen
  Kern bewusst **nicht**, damit der Abgleich ein zweiter Weg bleibt.
- **Start-Bildschirm mit *Spielstärke*:** alle Stellschrauben der Engine, die
  eine Frage am Tisch beantworten (`EngineSettings`, `UserDefaults`, je Suche
  frisch gelesen).
- **Bewertung:** Preis für freie Kartenplätze, Vorhersage des Spielendes
  (`EndForecast`, auch für fremde Pläne) und der Würfel danach
  (`Weights.followUp`). Die Zahlen dazu stehen in `docs/stand.md`.
- **Selbstspiel** (`HarmonySelfPlay`) und **Engines gegeneinander mit
  Schiedsrichter** (`HarmonyMatch`, `HarmonyTable/Referee.swift`).
- **Rechenzeit** auf dem iPhone 15 Pro Max, Release-Bau: halbvolles Brett
  ~1 s, Harmonys erster Zug 9 s, teuerster gemessener Fall 24 s; die Suche
  bleibt abbrechbar. Mit Vorhersage und Würfel danach rechnet die Bewertung
  länger; **auf dem Gerät nicht nachgemessen**.
- **Tierszenen** als Entwurf für kleine Animationen, noch nicht in der App:
  `tools/szenen/`, Regeln in `docs/szenen.md`.

**Fürs Gerät `-configuration Release` bauen.** Das Schema baut beim
Laufenlassen Debug, und Debug ist hier sechs- bis achtmal langsamer.

**Offen:** Die Rechenzeit des Würfels danach auf dem Gerät; was zur
Spielstärke noch zu messen ist, steht im Skill `spielstaerke` und in
`docs/ideen-vorgemerkt.md` (die offenen Karten sind gemessen: kein
Unterschied). Was in Phase 5 offen blieb, führt `docs/05-ui.md` am Ende auf.
Die Rechenzeit der Landschaft je Legung steht in `docs/06-durchstich.md`
unter *Fünf Abhilfen*.

**Skills** unter `.claude/skills/` laden das Vorgehen für ein Gebiet erst bei
Bedarf: `spielstaerke` für Bewertung, Gewichte und Messungen mit
`HarmonyMatch`, `szenen` für die Tierszenen.

## Aufbau

```
Harmony.xcodeproj      drei Targets, „Harmony“, „HarmonyTests“ und
                       „HarmonyUITests“, dazu ein geteiltes Schema „Harmony“
HarmonyRules/          Swift Package: drei Bibliotheken samt Tests, drei
                       Werkzeuge
  Sources/HarmonyRules   die Regeln: Steine, Geometrie, Karten, Lebensräume
    Resources/animals.json  die 32 Tierkarten, Quelle der Wahrheit
  Sources/HarmonyEngine  das Verfahren: Zustand, Züge, Bewertung, Suche,
                         Vorhersage des Spielendes, Einstellungen
  Sources/HarmonyMeasure zählt den Zugraum
  Sources/HarmonySelfPlay spielt gegen Zufallsgegnerinnen, vergleicht Gewichte
  Sources/HarmonyTable   der ganze Tisch samt Schiedsrichter, für Engines
                         gegeneinander
  Sources/HarmonyMatch   2 bis 4 Engines mit verschiedenen Einstellungen
HarmonyTests/          App-Tests (im Simulator, mit der App als Host): Wissen
                       der Partie, Verlauf, Spielstand, Sitzung, Begründung
HarmonyUITests/        Oberflächentests: die Antippgrenzen
Harmony-Info.plist     Ergänzung zum erzeugten Info.plist: Farbe des
                       Startbildschirms (`LaunchBackground`), weil Xcode
                       dafür keinen Build-Schlüssel kennt
MyApp/                 der Rest des Quellcodes
  MyApp.swift          @main, WindowGroup
  ContentView.swift    Wurzel-View
  SplashView.swift     Startanimation: das Icon setzt sich zusammen
  IconFlower.swift     die Blüte des Icons, für Animation und Start
  Launch.swift         Startparameter und gespeicherte Einstellungen
  Start/               Start-Bildschirm, Spielstärke, Über Harmony
  Game/                die Spielansichten, entstanden als Klickdummy in
                       Phase 5, heute mit Engine
    EngineBridge.swift Vorschlag → Zug auf dem Bildschirm, Verlauf → Steine der anderen
    GameStore.swift    der gespeicherte Spielstand, beim Laden nachgespielt
    GameLog.swift      Ereignisse, die Stellung (`GameState`), Spielende
    GameSession.swift  die laufende Partie: Ereignisse und was daraus folgt
    HarmonySearch.swift die Suche nach Harmonys Zug, wie der Bildschirm sie sieht
    SampleData.swift   Attrappendaten, dazu die Farben der Steine
    BoardView.swift    Sechseckgitter, Zelldarstellung
    OpponentTurnView.swift  der Bildschirm der Partie, verteilt auf:
    RecordTurnView.swift    Erfassung fremder Züge
    HarmonyTurnView.swift   Harmonys Zug als Anweisung
    HarmonyReportSheet.swift  was der Tisch nach ihrem Zug meldet
    GameOverView.swift      Endwertung
    HistorySheet.swift      Verlauf, Zurücknehmen, Neue Partie
    RationaleSheet.swift    Begründung eines Zuges
    RefillEntry.swift       Eingabe der Nachfüllung
    CorrectionView.swift    Berichtigung von Harmonys Tableau
    Components.swift        gemeinsame Bausteine
  Assets.xcassets/
docs/                  Konzeptdokumente; nummeriert nach Phasen, dazu
                       phasenübergreifende wie `pruefverfahren.md`
tools/                 Prüfwerkzeuge: Kartendaten (Python), Regeltests
                       (tests.sh), Oberflächentests (uitests.sh),
                       Verzweigung messen (messe-verzweigung.sh),
                       App-Icon zeichnen (app-icon.swift)
  szenen/              Entwurf der Tierszenen als SVG (Python): Stil,
                       Landschaften, Szene; Regeln in docs/szenen.md
```

`MyApp/`, `HarmonyTests/` und `HarmonyUITests/` sind **synchronisierte Gruppen**
(`PBXFileSystemSynchronizedRootGroup`). Neue Dateien darin landen ohne
Eingriff in `project.pbxproj` im jeweiligen Target — anders als die
Warnung oben zum Umbenennen vermuten lässt.

Das Quellverzeichnis heißt `MyApp/`, das Target dagegen `Harmony` — ein
Überbleibsel der Vorlage. Ein Umbenennen erfordert Anpassungen an den
Dateireferenzen in `project.pbxproj` und ist deshalb keine Nebenbei-Änderung.

## Bauen

Am besten das generische Ziel, das nicht davon abhängt, welche Simulatoren
gerade installiert sind:

```bash
xcodebuild -project Harmony.xcodeproj -scheme Harmony -destination 'generic/platform=iOS Simulator' build
```

Für einen konkreten Simulator **`id=` statt `name=`** benutzen:

```bash
xcodebuild ... -destination 'platform=iOS Simulator,id=<UDID>'
```

Gerätenamen sind nicht eindeutig. Den iPhone 15 Pro Max gibt es zweimal, mit
iOS 17.0 und mit iOS 27.0, und der iOS-17-er kann die App wegen des
Deployment-Targets von 27.0 gar nicht laden. `xcrun simctl list devices available`
zeigt die UDIDs.

### Auf das echte iPhone

Signierung ist automatisch eingerichtet; das Profil gilt jeweils rund eine
Woche und muss danach neu erzeugt werden.

```bash
xcodebuild ... -configuration Release -destination 'platform=iOS,id=<Geräte-UDID>' -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device <Geräte-UDID> <Pfad>/Harmony.app
```

**`-configuration Release` gehört dazu**, sonst landet ein Debug-Bau auf dem
Gerät und die Engine rechnet sechs- bis achtmal so lange. Der Pfad zum
gebauten `Harmony.app` endet dann auf `Release-iphoneos/`.

`xcrun devicectl list devices` zeigt gekoppelte Geräte.

### Tests

Die Regeln liegen im Swift Package `HarmonyRules/` und werden dort
geprüft — ohne Xcode-Projekt, ohne Simulator, in gut drei Sekunden:

```bash
tools/tests.sh
```

`tools/tests.sh -v` nennt jeden Fall einzeln. Der Rückgabewert ist der von
`swift test`, das Skript taugt also für eine Automatik. Direkt geht es
genauso: `cd HarmonyRules && swift test`.

Die App-Schicht — Wissen der Partie, Verlauf, Spielstand, Sitzung, Begründung — hat
eigene Fälle im Ziel `HarmonyTests`. Sie laufen im Simulator, aber ohne
Bedienung und in Sekunden:

```bash
tools/apptests.sh
```

Die Spielstand-Fälle arbeiten auf einer Datei für sich; die der laufenden App
bleibt unberührt.

Die Oberfläche wird getrennt geprüft — Stockwerk 3, angelegt am
2026-09-20. `tools/uitests.sh` führt das ganze Schema aus, also auch die
App-Fälle. Diese Tests brauchen einen Simulator und ungefähr vier Minuten,
gehören also nicht in denselben Lauf wie die Regeltests. Läuft nebenher
die Live-Ansicht des Simulators in der Claude-App, werden sie so langsam,
dass einzelne Fälle an Zeitüberschreitungen scheitern; ein solcher Fall
besteht einzeln (`-only-testing:`) meist, und das ist dann kein Codefehler:

```bash
tools/uitests.sh
```

Das Skript nimmt das Bezugsgerät aus `docs/05-ui.md`; ein anderes wird als
UDID übergeben. Von Hand ist es derselbe Aufruf:

```bash
xcodebuild test -project Harmony.xcodeproj -scheme Harmony \
  -destination 'platform=iOS Simulator,id=<UDID>'
```

### Wenn xcodebuild Xcode nicht findet

`xcode-select` zeigt auf diesem Rechner auf die Command Line Tools, wodurch
jeder nackte `xcodebuild`-Aufruf abbricht:

```
tool 'xcodebuild' requires Xcode, but active developer directory
'/Library/Developer/CommandLineTools' is a command line tools instance
```

Statt die Einstellung systemweit zu ändern, dem Befehl eine Variable
voranstellen:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

Die dauerhafte Lösung wäre `sudo xcode-select -s /Applications/Xcode.app`.
Sie braucht ein Passwort und ist damit Sache des Nutzers, nicht eines Agents.

## Build-Einstellungen

| Einstellung | Wert |
| --- | --- |
| Bundle-Identifier | `de.superook.Harmony` |
| Unterstützte Plattformen | `iphoneos iphonesimulator` |
| `SDKROOT` | `auto` |
| Deployment-Target | iOS 27.0 |
| Swift-Sprachmodus | 5.0 |

`SDKROOT = auto` bedeutet, dass das SDK dem Ziel folgt — ein Schema deckt
Gerät und Simulator ab. Das so lassen, statt plattformspezifische Targets
anzulegen.

**macOS ist am 2026-09-20 herausgenommen worden.** Es war eine Zusage der
Vorlage, nicht des Projekts: Gebaut hat die App dort nie, weil der
Klickdummy durchgehend iOS-eigene APIs benutzt —
`navigationBarTitleDisplayMode` und die `UIColor`-Konstanten gibt es unter
AppKit nicht. Aufgefallen ist es erst, als das UI-Test-Target den Befehl
aus diesem Abschnitt erstmals nachprüfte. Wiederherstellen ließe sich die
Unterstützung, aber sie wäre Arbeit an einer Plattform, an der das Spiel
nicht gespielt wird: `05-ui.md` misst durchgehend gegen ein iPhone, und am
Tisch liegt kein Mac.

## Konventionen

- Ausschließlich SwiftUI. Kein UIKit oder AppKit, sofern nicht eine
  bestimmte API dazu zwingt. Plattformeigene Aufrufe wie
  `navigationBarTitleDisplayMode` sind seit dem Wegfall von macOS
  unbedenklich.
- `ContentView.swift` enthält einen `#Preview`-Block. Previews
  funktionsfähig halten; sie sind die schnellste Rückmeldung in diesem
  Projekt.
- Das Deployment-Target ist bewusst aktuell, neuere Plattform-APIs dürfen
  also ohne Verfügbarkeitsprüfung verwendet werden.
- **Sprachen:** Bezeichner, Kommentare und Commit-Nachrichten auf Englisch.
  Dokumentation und **sichtbare Texte in der Oberfläche** auf Deutsch. Die
  Trennung hält die deutschen Zeichenketten beisammen, falls die App später
  internationalisiert wird.
- **Sichtbare Texte werden gegendert**, im generischen Femininum:
  „Spielerinnen", „Mitspielerin". Festgelegt am 2026-09-20.
- Die Notationsbuchstaben bleiben deutsch begründet — `S` für Stein, `H` für
  Holz, `Z` für Ziegel —, weil abgelegte Kartendaten und Protokolle sie
  benutzen. Siehe `docs/pruefverfahren.md`.
- Neun Startparameter: `-forgetGame` verwirft einen gespeicherten Stand
  beim Start, was die Persistenztests brauchen; `-harmonyTurn` öffnet direkt auf Harmonys
  Bildschirm, mit einer Attrappenstellung mitten in der Partie;
  `-sampleMove` hält zusätzlich die Engine heraus und zeigt den
  Beispielzug, was die Oberflächentests brauchen; `-longCards` legt die
  fünf längsten Kartennamen in die Auslage, um Umbrüche im schlechtesten
  Fall zu prüfen; `-endScore` und `-endScoreB` öffnen die Endwertung über
  einem Schlussbrett der jeweiligen Planseite; `-logSearch` schreibt nach
  jeder Suche eine Zeile mit Zeit, Zugzahl, Notation und Vollständigkeit auf
  die Standardausgabe, dazu eine Zeile `ENDE` mit der Vorhersage, wann die
  fremden Spielpläne voll sind; `-noForecastEnd` nimmt diese Vorhersage
  aus der Bewertung, die sonst mit ihr rechnet — gleich, was unter
  *Spielstärke* eingestellt ist; `-showStart` zeigt den Start-Bildschirm
  auch neben den übrigen Prüfeinstiegen.

  **`-logSearch` ist der einzige Weg an die Rechenzeit auf dem Gerät** — dort
  läuft kein Messprogramm und liest niemand mit. Ein Spielstand lässt sich
  vorher hineinlegen, um eine bestimmte Stellung zu messen:

  ```bash
  xcrun devicectl device copy to --device <UDID> --domain-type appDataContainer \
    --domain-identifier de.superook.Harmony --source stellung.json \
    --destination "Library/Application Support/spielstand.json"
  ```

  ```bash
  xcrun devicectl device process launch --device <UDID> --console \
    --terminate-existing de.superook.Harmony -- -logSearch
  ```

  Die **Startanimation und der Start-Bildschirm** kommen nur beim Start
  von Hand; jeder dieser Prüfeinstiege überspringt beide, damit die
  Oberflächentests nicht warten. `-showStart` holt den Start-Bildschirm
  zurück, für dessen eigene Tests.

  **Ohne Startparameter beginnt eine Partie leer** — leerer Spielplan,
  keine Karten in Harmonys Hand — und füllt sich über die Züge. Die
  Attrappenstellung hängt seit dem 2026-09-20 nur noch an
  `-harmonyTurn`.

  Eine angefangene Partie **überdauert das Weglegen**: Der Ereignisverlauf
  liegt als `spielstand.json` in Application Support und wird nach jedem
  Ereignis geschrieben. Die Prüfeinstiege schreiben **nicht** — sonst käme
  die Attrappenstellung beim nächsten echten Start zurück und sähe aus wie
  eine gespielte Partie. Verworfen wird sie über *Neue Partie* im
  Verlauf; danach kommen wie beim Öffnen der App Startanimation und
  Start-Bildschirm, damit sich die Spielstärke vor der nächsten Partie
  einstellen lässt.

## Hinweise zum Repository

- **Worktrees für parallele Sitzungen** legt das Werkzeug `EnterWorktree`
  an, nicht `git worktree add` von Hand: Es setzt sie nach
  `.claude/worktrees/<name>` auf einen neuen Branch; der Ordner ist
  ignoriert. **Vorsicht beim Ausgangspunkt:** Die Voreinstellung
  (`worktree.baseRef: fresh`) zweigt von `origin/<Standardbranch>` ab, also
  von `main` und nicht vom aktuellen Stand. Solange Arbeit auf
  `review-cleanup` noch nicht in `main` ist, fehlt sie dort; dann
  `worktree.baseRef: head` einstellen, oder einen von Hand angelegten
  Worktree betreten (`EnterWorktree` mit `path`; er muss unter
  `.claude/worktrees/` liegen). In einem Worktree nur die eigenen Pfade
  stagen, nie `git add -A`.
- Das Remote `origin` ist **öffentlich**: `github.com/SuperOok/Harmony`.
  Niemals API-Schlüssel, Provisioning-Profile oder Signaturzertifikate
  einchecken. Ebenso keine wörtlich übernommenen Regeltexte oder
  Kartenillustrationen des Brettspiels — Regeln als solche sind frei,
  ihre konkrete Ausformulierung und Gestaltung nicht.
- `xcuserdata/` ist ignoriert. Das Schema „Harmony“ liegt dagegen als
  **geteiltes** Schema unter `Harmony.xcodeproj/xcshareddata/` und ist
  eingecheckt — sonst wüsste `xcodebuild test` in einem frischen Klon
  nicht, welches Testtarget gemeint ist.
- **Das Arbeitsverzeichnis lag bis zum 2026-09-20 in iCloud Drive** und
  liegt seither hier. Über denselben Dateien liefen zwei
  Synchronisationen, und eine davon war überflüssig, weil das
  GitHub-Remote dasselbe leistet — mit Historie und ohne Konfliktkopien.
  Dazu scheiterte `swift test` darin am Signieren, weil erweiterte
  Attribute an den Build-Produkten hingen; deshalb baute
  `tools/tests.sh` eine Zeitlang außerhalb. Beides ist erledigt, der
  Sonderweg im Skript ist entfernt.
