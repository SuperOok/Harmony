# Harmony

SwiftUI-App (iOS, iPadOS, macOS), gebaut mit Xcode 27.

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

**Wo es steht:** Phase 5 ist abgeschlossen, alle Ansichten der
Funktionsliste sind gebaut. Der nächste Schritt ist in
`docs/pruefverfahren.md` unter *Vorschlag zum Zeitpunkt* festgehalten:
ein UI-Test-Target mit der Antippzahl als erster Zusicherung. Was in
Phase 5 offen blieb, führt `docs/05-ui.md` am Ende auf.

## Aufbau

```
Harmony.xcodeproj      ein Target und ein Schema, beide „Harmony“
HarmonyRules/          Swift Package: die Regeln, samt ihren Tests
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
tools/                 Prüfwerkzeuge: Kartendaten (Python), Tests (tests.sh)
```

`MyApp/` ist eine **synchronisierte Gruppe** (`PBXFileSystemSynchronizedRootGroup`).
Neue Dateien darin landen ohne Eingriff in `project.pbxproj` im Target —
anders als die Warnung oben zum Umbenennen vermuten lässt.

Das Quellverzeichnis heißt `MyApp/`, das Target dagegen `Harmony` — ein
Überbleibsel der Vorlage. Ein Umbenennen erfordert Anpassungen an den
Dateireferenzen in `project.pbxproj` und ist deshalb keine Nebenbei-Änderung.

## Bauen

```bash
xcodebuild -project Harmony.xcodeproj -scheme Harmony -destination 'platform=macOS' build
```

Für iOS besser das generische Ziel verwenden, das nicht davon abhängt,
welche Simulatoren gerade installiert sind:

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
xcodebuild ... -destination 'platform=iOS,id=<Geräte-UDID>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <Geräte-UDID> <Pfad>/Harmony.app
```

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

Es gibt **kein UI-Test-Target**. Keine `xcodebuild test`-Aufrufe für die
App erfinden, solange keines existiert.

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
| Unterstützte Plattformen | `iphoneos iphonesimulator macosx` |
| `SDKROOT` | `auto` |
| Deployment-Target | 27.0 auf allen Plattformen |
| Swift-Sprachmodus | 5.0 |

`SDKROOT = auto` bedeutet, dass das SDK dem Ziel folgt — ein Schema deckt
alle Plattformen ab. Das so lassen, statt plattformspezifische Targets
anzulegen.

## Konventionen

- Ausschließlich SwiftUI. Kein UIKit oder AppKit, sofern nicht eine
  bestimmte API dazu zwingt.
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
- Der Dummy kennt vier Startparameter: `-harmonyTurn` öffnet ihn direkt auf
  Harmonys Bildschirm, `-longCards` legt die fünf längsten Kartennamen in
  die Auslage, um Umbrüche im schlechtesten Fall zu prüfen, und
  `-endScore` beziehungsweise `-endScoreB` öffnen die Endwertung über einem
  Schlussbrett der jeweiligen Planseite.

## Hinweise zum Repository

- Das Remote `origin` ist **öffentlich**: `github.com/SuperOok/Harmony`.
  Niemals API-Schlüssel, Provisioning-Profile oder Signaturzertifikate
  einchecken. Ebenso keine wörtlich übernommenen Regeltexte oder
  Kartenillustrationen des Brettspiels — Regeln als solche sind frei,
  ihre konkrete Ausformulierung und Gestaltung nicht.
- `xcuserdata/` ist ignoriert. Xcode erzeugt das Schema beim ersten Öffnen
  neu, ein frischer Klon braucht also keine Zusatzschritte.
- **Das Arbeitsverzeichnis lag bis zum 2026-09-20 in iCloud Drive** und
  liegt seither hier. Über denselben Dateien liefen zwei
  Synchronisationen, und eine davon war überflüssig, weil das
  GitHub-Remote dasselbe leistet — mit Historie und ohne Konfliktkopien.
  Dazu scheiterte `swift test` darin am Signieren, weil erweiterte
  Attribute an den Build-Produkten hingen; deshalb baute
  `tools/tests.sh` eine Zeitlang außerhalb. Beides ist erledigt, der
  Sonderweg im Skript ist entfernt.
