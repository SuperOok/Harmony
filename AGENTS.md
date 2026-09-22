# Harmony

SwiftUI-App (iOS, iPadOS), gebaut mit Xcode 27.

Harmony stellt einen Computer-Mitspieler für das Brettspiel **Harmonies**.
Die Partie läuft am echten Tisch mit echtem Material; die App verwaltet nur
das Wissen eines einzelnen Spielers und schlägt dessen Züge vor. Sie ist
keine Digitalfassung des Spiels. Siehe `docs/` für Produktkern und Konzept.

Der Code ist zweierlei. `MyApp/` ist der **Klickdummy** aus Phase 5:
Ansichten über Attrappendaten, ohne Engine. `HarmonyRules/` ist der
Anfang des **Regelmoduls** — Wertung, Landschaften, zulässige Stapel,
Steinbilanz —, entstanden, weil der Dummy diese Regeln zum Anzeigen
braucht und sie dort prüfbar liegen. Die Konzeptarbeit ist weiter,
siehe `docs/`.

**Wo es steht:** Stand 2026-09-22. Der Durchstich aus Phase 6
trägt und läuft **auf dem Gerät**: Die App rechnet ihre Züge selbst, eine
Partie beginnt mit leerem Spielplan und füllt sich, und sie überdauert das
Weglegen. Geprüft wird mit 172 Regelfällen (`tools/tests.sh`, gut eine
Sekunde) und fünf Oberflächenfällen (`tools/uitests.sh`).

**Gespielt zu werden findet Lücken, die kein Prüffall findet.** Am
2026-09-22 drei Stück, alle in `docs/06-durchstich.md` unter *Zwei Lücken,
am Tisch gefunden*. Am Tisch aufgefallen: Die Bewertung kannte für Gebäude
**keine Aussicht** und schob sie deshalb in die Ecken, wo drei Farben
unmöglich sind; und `ownTurnsLeft` zählte nur den Beutel, während in
Wahrheit der eigene Spielplan die Partie beendet — Harmony rechnete durchweg
mit etwa der doppelten Restzeit und schloss darum nichts ab. Beim Nachzählen
kam die dritte dazu: Dieselbe Lücke bestand für **Bergnachbarschaft,
Feldgruppe und Baumhöhe**. Alle vier tragen jetzt `Evaluator.dormant`
gemeinsam — etwas, das 0 zählt und auf Steine auf noch offenen Feldern
wartet —, und sie teilen sich ein Steinbudget von `3 · ownTurnsLeft`, weil
ihre Summe sonst mehr verspricht, als Züge hergeben.

**Die Rechenzeit war das große Problem und ist es nicht mehr.** Am
2026-09-20/21 sind fünf Hebel gebaut und jeweils auf dem Gerät gemessen
worden: im Release bauen (Faktor 5,8), Legungsabhängiges einmal je Legung
statt sechsmal (2,5), die Nachbarschaft als Tabelle (1,15), die Legungen auf
mehrere Kerne verteilen (2,3) und inkrementell bewerten (2,1 bis 3,0). Dazu
das Sieben der Anwärter über einen Würfel hinweg, das den teuersten Fall
halbierte.

Auf dem iPhone 15 Pro Max, Release-Bau:

| Stellung | Züge | Zeit |
| --- | --- | --- |
| halbvolles Brett | 12.270 | ~1 s |
| Harmonys erster Zug | 235.290 | 9 s |
| 6 Steine, 2 Karten | 112.085 | 3,5 s |
| 3 Karten, fast leerer Plan | 401.856 | **24 s** |

**Der teuerste Fall ist nicht der leerste Plan**, sondern drei Karten in der
Hand auf offenem Plan: Dort legen sechs von zehn Zügen einen Würfel. Keine
gemessene Stellung liegt noch über der halben Minute aus Szenario 2. Der
Abkürzen-Knopf bleibt dennoch — 24 Sekunden sind kein Abstand, und eine
Suche muss abbrechbar sein, sobald sich die Stellung ändert.

Was offen ist, steht in `docs/06-durchstich.md` unter *Fünf Abhilfen*: die
Landschaft wird weiter je Legung ganz gerechnet und ist damit der größte
Posten des Vorrechnens.

**Eine Regelfrage ist noch offen**, aufgeworfen beim Spielen am 2026-09-21
und in `docs/ideen-vorgemerkt.md` festgehalten: dass die Bewertung nur die
Karten in Harmonys Hand kennt, nie die offenen. Die zweite, ob ein Gebäude
ohne drei Farben ringsum 0 oder −2 zählt, ist am 2026-09-22 geklärt — die
Broschüre bestätigt 0, wie Regeltext und Code es bereits umsetzen. Was in
Phase 5 offen blieb, führt `docs/05-ui.md` am Ende auf.

**Fürs Gerät `-configuration Release` bauen.** Das Schema baut beim
Laufenlassen Debug, und Debug ist hier sechs- bis achtmal langsamer. Die
Zahlen oben gelten nur für den Release-Bau.

## Aufbau

```
Harmony.xcodeproj      zwei Targets, „Harmony“ und „HarmonyUITests“,
                       dazu ein geteiltes Schema „Harmony“
HarmonyRules/          Swift Package, zwei Bibliotheken samt Tests
  Sources/HarmonyRules   die Regeln: Steine, Geometrie, Karten, Lebensräume
    Resources/animals.json  die 32 Tierkarten, Quelle der Wahrheit
  Sources/HarmonyEngine  das Verfahren: Zustand, Züge, Bewertung, Suche,
                         Vorhersage des Spielendes
  Sources/HarmonyMeasure zählt den Zugraum
HarmonyUITests/        Oberflächentests: die Antippgrenzen
MyApp/                 der Rest des Quellcodes
  MyApp.swift          @main, WindowGroup
  ContentView.swift    Wurzel-View
  Dummy/               Klickdummy aus Phase 5, keine Engine
    SampleData.swift   Attrappendaten, dazu die Farben der Steine
    BoardView.swift    Sechseckgitter, Zelldarstellung
    OpponentTurnView.swift  Erfassung fremder Züge
    CorrectionView.swift    Berichtigung von Harmonys Tableau
  Assets.xcassets/
docs/                  Konzeptdokumente; nummeriert nach Phasen, dazu
                       phasenübergreifende wie `pruefverfahren.md`
tools/                 Prüfwerkzeuge: Kartendaten (Python), Regeltests
                       (tests.sh), Oberflächentests (uitests.sh),
                       Verzweigung messen (messe-verzweigung.sh),
                       App-Icon zeichnen (app-icon.swift)
```

`MyApp/` und `HarmonyUITests/` sind **synchronisierte Gruppen**
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
geprüft — ohne Xcode-Projekt, ohne Simulator, in unter einer Sekunde:

```bash
tools/tests.sh
```

`tools/tests.sh -v` nennt jeden Fall einzeln. Der Rückgabewert ist der von
`swift test`, das Skript taugt also für eine Automatik. Direkt geht es
genauso: `cd HarmonyRules && swift test`.

Die Oberfläche wird getrennt geprüft — Stockwerk 3, angelegt am
2026-09-20. Diese Tests brauchen einen Simulator und ungefähr eine Minute,
gehören also nicht in denselben Lauf wie die Regeltests:

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
- `ContentView.swift` enthält einen `#Preview`- und einen
  `#Playground`-Block. Previews funktionsfähig halten; sie sind die
  schnellste Rückmeldung in diesem Projekt.
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
- Acht Startparameter: `-forgetGame` verwirft einen gespeicherten Stand
  beim Start, was die Persistenztests brauchen; `-harmonyTurn` öffnet direkt auf Harmonys
  Bildschirm, mit einer Attrappenstellung mitten in der Partie;
  `-sampleMove` hält zusätzlich die Engine heraus und zeigt den
  Beispielzug, was die Oberflächentests brauchen; `-longCards` legt die
  fünf längsten Kartennamen in die Auslage, um Umbrüche im schlechtesten
  Fall zu prüfen; `-endScore` und `-endScoreB` öffnen die Endwertung über
  einem Schlussbrett der jeweiligen Planseite; `-logSearch` schreibt nach
  jeder Suche eine Zeile mit Zeit, Zugzahl, Notation und Vollständigkeit auf
  die Standardausgabe, dazu eine Zeile `ENDE` mit der Vorhersage, wann die
  fremden Spielpläne voll sind; `-forecastEnd` lässt diese Vorhersage in
  die Bewertung ein, ohne ihn wird sie nur geschrieben.

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

  **Ohne Startparameter beginnt eine Partie leer** — leerer Spielplan,
  keine Karten in Harmonys Hand — und füllt sich über die Züge. Die
  Attrappenstellung hängt seit dem 2026-09-20 nur noch an
  `-harmonyTurn`.

  Eine angefangene Partie **überdauert das Weglegen**: Der Ereignisverlauf
  liegt als `spielstand.json` in Application Support und wird nach jedem
  Ereignis geschrieben. Die Prüfeinstiege schreiben **nicht** — sonst käme
  die Attrappenstellung beim nächsten echten Start zurück und sähe aus wie
  eine gespielte Partie. Verworfen wird sie über *Neue Partie* im
  Verlauf.

## Hinweise zum Repository

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
