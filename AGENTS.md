# Harmony

SwiftUI-App (iOS, iPadOS, macOS), gebaut mit Xcode 27.

Harmony stellt einen Computer-Mitspieler für das Brettspiel **Harmonies**.
Die Partie läuft am echten Tisch mit echtem Material; die App verwaltet nur
das Wissen eines einzelnen Spielers und schlägt dessen Züge vor. Sie ist
keine Digitalfassung des Spiels. Siehe `docs/` für Produktkern und Konzept.

Der Stand ist derzeit im Wesentlichen die Xcode-Vorlage. Was unten als
Konvention steht, ist ein Ausgangspunkt, keine gewachsene Architektur.

## Aufbau

```
Harmony.xcodeproj      ein Target und ein Schema, beide „Harmony“
MyApp/                 sämtlicher Quellcode
  MyApp.swift          @main, WindowGroup
  ContentView.swift    Wurzel-View
  Assets.xcassets/
docs/                  Konzeptdokumente, nach Phasen nummeriert
```

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

Für ein konkretes Gerät `-destination 'platform=iOS Simulator,name=iPhone 18 Pro'`.
Gerätenamen ändern sich zwischen Xcode-Versionen — vorher
`xcrun simctl list devices available` prüfen, statt einen Namen fest
einzutragen.

Es gibt **kein Test-Target**. Keine `xcodebuild test`-Aufrufe erfinden,
solange keines existiert.

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
- Dokumentation auf Deutsch, Quellcode und Commit-Nachrichten auf Englisch.

## Hinweise zum Repository

- Das Remote `origin` ist **öffentlich**: `github.com/SuperOok/Harmony`.
  Niemals API-Schlüssel, Provisioning-Profile oder Signaturzertifikate
  einchecken. Ebenso keine wörtlich übernommenen Regeltexte oder
  Kartenillustrationen des Brettspiels — Regeln als solche sind frei,
  ihre konkrete Ausformulierung und Gestaltung nicht.
- `xcuserdata/` ist ignoriert. Xcode erzeugt das Schema beim ersten Öffnen
  neu, ein frischer Klon braucht also keine Zusatzschritte.
- Das Arbeitsverzeichnis liegt in iCloud Drive. Bei merkwürdigem
  Git-Verhalten — fehlende Objekte, Konfliktkopien in `.git/` — zuerst
  iCloud-Synchronisation verdächtigen, nicht Git.
