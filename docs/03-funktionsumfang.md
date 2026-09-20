# Phase 3 — Funktionsumfang

Status: abgeschlossen, Stand 2026-09-19

Was v1 kann, was später kommt, was nie. Geschnitten wird gegen die
Szenarien aus Phase 2: Was dort nicht vorkommt, braucht v1 nicht.

## Schnittprinzip

**v1 ist der kleinste Umfang, mit dem eine Partie am Tisch vollständig
durchläuft.** Nicht der kleinste lauffähige Stand — eine App, die bei der
Endwertung aussteigt, hat keinen Nutzen und erlaubt keine Erfahrung. Aber
auch nicht mehr: Jede Funktion, die eine Partie nicht braucht, verzögert die
erste echte Partie, und erst die zeigt, ob das Konzept trägt.

**Die Messlatte für v1 ist der Durchlauf, nicht die Spielstärke.** Eine
Partie vom Aufbau bis zur Endwertung, ohne dass jemand einspringen muss, und
Harmony spielt keinen offensichtlichen Unsinn. Stärke ist danach eine Frage
der Bewertungsfunktion, und die lässt sich verbessern, ohne irgendetwas
umzubauen — vorausgesetzt, die Wertung ist von Anfang an sauber getrennt von
Suche und Oberfläche. Das ist eine Auflage an Phase 4.

## Gehört in v1

### Partie führen

| | Funktion | Quelle |
| --- | --- | --- |
| 1 | Aufbau erfassen: 5 Felder à 3 Steine, 5 offene Tierkarten, Planseite, Zugreihenfolge mit Harmonys Platz, Namen der Mitspieler (mit Voreinstellung) | Szenario 1 |
| 2 | Fremden Zug erfassen: geleertes Feld, 3 nachgefüllte Steine, genommene Tierkarte samt Nachrücker | Szenario 2 |
| 3 | Den eigenen Zug des Betreuers erfassen — identische Eingabe, kein Sonderfall | Szenario 2 |
| 4 | Harmonys Zug berechnen, als Handlungsanweisung anzeigen, bestätigen lassen | Szenario 3 |
| 5 | Zugverlauf mit Rücknahme einzelner Züge | Störfall A |
| 6 | Korrekturweg für Harmonys Tableau, abseits des regulären Zugs | Störfall B |
| 7 | Spielende erkennen und die letzte Runde zu Ende führen | Szenario 4 |
| 8 | Endwertung für Harmony, nach Landschaften und Karten aufgeschlüsselt | Szenario 4 |

### Engine

| | Funktion | Quelle |
| --- | --- | --- |
| 9 | Alle legalen Züge erzeugen: Feld nehmen, 3 Steine legen, höchstens 1 Karte nehmen, beliebig viele Tierwürfel setzen | Regeln |
| 10 | Bewertungsfunktion aus benennbaren Einzeltermen | Phase 1, Transparenz |
| 11 | Suche, die auf einem Teilzustand ansetzt und um das nachgefüllte Feld ergänzt | Szenario 3 |
| 12 | Beutelverfolgung aus den erfassten Nachfüllungen | Szenario 2 |
| 13 | Zugzähler und daraus die Obergrenze der Restlaufzeit | `ideen-vorgemerkt.md` |
| 14 | Beide Planseiten: Geometrie und Wasserwertung | siehe unten |
| 15 | Alle 32 Tierkarten des Basisspiels | `animals.json` |

### Transparenz

| | Funktion | Quelle |
| --- | --- | --- |
| 16 | Begründung des Zuges: die größten Beiträge zur Wertung, benannt | Störfall C |
| 17 | Zweitbester Zug und der Abstand zu ihm | Störfall C |
| 18 | Begründung nachträglich abrufbar, auch wenn weitergespielt wird | Störfall C |

## Die Konflikte aus Phase 1, entschieden

### Stärke gegen Eingabeeffizienz

Harmony erfährt in v1 über die Mitspieler:

- die **geteilten Auslagen** — ohnehin nötig, Kosten null,
- **wer welche Tierkarte genommen hat** — ein Tipp mehr, und nur dann, wenn
  überhaupt eine Karte genommen wird,
- eine manuelle Meldung, dass ein **fremdes Tableau fast voll** ist — höchstens
  ein Tipp pro Partie.

Nicht erfasst werden fremde Tableaus. Sie würden pro fremdem Zug drei
Steinplatzierungen verlangen und die Eingabe mehr als verdreifachen — gegen
das erste Qualitätskriterium aus Phase 1.

Die Endemeldung ist die wertvollste der drei: Das Partieende ist der
Zeitpunkt, an dem Harmony ihre Karten abschließen muss, und sie kennt sonst
nur ihr *eigenes* Tableau als Auslöser. Eine Fehleinschätzung um eine Runde
kann eine halbfertige Tierkarte kosten.

*Einschränkung, ehrlich vermerkt:* Die Kartenzuordnung sagt, **was** jemand
genommen hat, nicht, wann er es abschließt. Die Regelgrenze von 4
unabgeschlossenen Karten lässt sich daraus also **nicht** zuverlässig
ableiten — dazu müsste man fremde Tierwürfel mitzählen. Was v1 gewinnt, ist
eine Vermutung darüber, welche der offenen Karten vor Harmonys nächstem Zug
verschwindet. Ob das den einen Tipp wert ist, zeigt erst der Durchstich.

### Stärke gegen Transparenz

Gezeigt werden die **größten Beiträge** zur Gesamtwertung, nicht die
vollständige Rechnung, und zusätzlich der **zweitbeste Zug mit Abstand**.
Eine Zahl ohne Vergleich beantwortet den Widerspruch aus Störfall C nicht:
„Dieser Zug bringt 14" heißt nichts, solange niemand weiß, dass der nächste
13 bringt oder 6.

Die Suchtiefe wird dadurch **nicht** begrenzt. Die Begründung erklärt, warum
dieser Zug besser ist als der nächstbeste, nicht, wie tief gerechnet wurde.

### Beide Planseiten, nicht eine

Seite A hat 23 Felder und wertet Wasser als **Fluss** (längster unter allen
kürzesten Wegen), Seite B hat 25 Felder und wertet **Inseln**
(Zusammenhangsgebiete der nicht-blauen Felder). Das sind zwei Geometrien und
zwei Wertungsregeln.

Trotzdem beides in v1, weil der Aufwand klein und die Einschränkung teuer
wäre. Die Geometrie ist eine Liste von Feldern mit Nachbarschaften, also
Daten, kein Code. Beide Wasserwertungen sind auf einem Brett mit 25 Feldern
Standardgraphenarbeit — die eine sucht den Durchmesser eines
Zusammenhangsgebiets, die andere zählt Zusammenhangsgebiete. Nur eine Seite
zu unterstützen hieße dagegen, dem Tisch vorzuschreiben, wie er aufbaut;
das fällt spätestens in der ersten Partie unangenehm auf.

Nebeneffekt: Zwei Geometrien von Anfang an zwingen dazu, das Brett nicht
fest zu verdrahten. Das ist ohnehin die robustere Bauweise.

## Kommt später

Nichts davon ist verworfen, nur vertagt.

- **Kameraerkennung der Steinauslage.** Der größte denkbare Gewinn an
  Eingabezeit und ein eigenes Projekt im Projekt. v1 tippt. Die Eingabe
  sollte aber so gebaut sein, dass eine Erkennung sie später speisen kann,
  statt sie zu ersetzen.
- **iPad-Layout.** Das iPad liegt am Tisch besser als ein iPhone. Der Code
  baut für beide, erprobt wird v1 aber nur am iPhone — und zwar am
  **iPhone 15 Pro Max** als Bezugsgerät, siehe `05-ui.md`. Schmalere
  iPhones sind damit vertagt, nicht ausgeschlossen. macOS dagegen ist am
  2026-09-20 ganz herausgefallen: Die Zusage stammte aus der Projektvorlage
  und war nie eingelöst — gebaut hat die App dort nie.
- **Erweiterungen**, zuerst die Naturgeister. Das Kartenformat ist
  erweiterbar entworfen (Phase 1).
- **Mehrere Harmonys in einer Partie.** Kein Szenario verlangt es; die
  Datenhaltung soll es nur nicht verbauen.
- **Einstellbare Spielstärke.** Eine drosselbare Engine ist eine
  Zusatzanforderung an das Verfahren, kein Ziel für v1.
- **Partie über Tage fortsetzen.** Phase 2 hat es ausdrücklich nicht als
  Szenario aufgenommen. Der Zustand muss den Wechsel in den Hintergrund
  überstehen, mehr nicht.
- **Fremde Tableaus erfassen**, falls der Durchstich zeigt, dass Harmony
  ohne sie zu schwach bleibt.
- **Statistik über mehrere Partien.** Interessant für die Arbeit an der
  Bewertungsfunktion, nicht für den Tisch.
- **Punkte aller Spieler zusammenrechnen.** Vorgesehen für v2: Harmony
  ersetzt den Block aus der Packung. Das war in Phase 1 unter „Kommt nie"
  geführt und ist am 2026-09-20 hierher verschoben worden — die Methodik
  erlaubt Rückwärtsgehen, und der Nutzen am Tisch ist offensichtlich.
- **Ergebnisse vergangener Partien.** Ebenfalls v2. Sie hängen an den
  Namen aus der Spielerverwaltung; ohne Wiedererkennung ließe sich keine
  alte Partie zuordnen. In v1 **nicht** enthalten.
- **Spielerverwaltung.** Voraussetzung für die beiden Vorigen und in v1
  bereits enthalten, aber nur zur Hälfte: Die Spielerauswahl beim Aufbau
  greift auf eine Liste bekannter Namen zu, die **über Programmstarts
  hinweg erhalten bleibt**. Namen lassen sich hinzufügen und entfernen.

  Was v1 **nicht** speichert, sind Ergebnisse. Die Grenze verläuft
  zwischen „wer spielt hier öfter mit" und „wie ist es ausgegangen".

  Zwei Punkte gehören dazu bedacht, bevor gespeichert wird: Das Repository
  ist **öffentlich**, Namen und Ergebnisse realer Personen gehören nicht
  hinein (siehe die neutralen Namen in `pruefverfahren.md`). Und Phase 1
  sagt „kein Online-Dienst" — die Daten bleiben auf dem Gerät.

## Kommt nie

Aus Phase 1 übernommen und hier verbindlich:

- **Digitalfassung von Harmonies.** Kein Modus, in dem Menschen in der App
  gegeneinander spielen.
- **Regellehrer.** Die App erklärt das Spiel nicht und prüft die Züge der
  Menschen nicht.
- **Online-Dienst, Konten, Synchronisation.** Alles bleibt lokal.
- **Gelernte Modelle.** Die Bewertung bleibt handgeschrieben und benennbar.
- **Harmony am Tisch mit vier Menschen.** Das Spiel hat vier Plätze.

## Nicht gewählt, weil

- **Kamera in v1** — würde die erste Partie um Wochen verschieben und hängt
  an Erkennungsqualität, die sich nicht planen lässt. Tippen setzt zuerst
  die Messlatte, an der eine Kamera sich später messen muss.
- **Volle fremde Tableaus** — siehe oben; der Eingabepreis steht in keinem
  Verhältnis, solange nicht erwiesen ist, dass Harmony ohne sie zu schwach
  spielt.
- **„Harmony gewinnt" als Abnahmekriterium für v1** — koppelt den ersten
  lauffähigen Stand an Feinschliff, der ohne lauffähigen Stand gar nicht
  möglich ist. Falsche Reihenfolge.
- **Nur eine Planseite** — siehe oben.
- **Automatisches Erkennen fremder Spielenden** — hieße, fremde Tableaus zu
  verfolgen. Der eine manuelle Tipp leistet dasselbe für einen Bruchteil.
- **Naturgeister in v1** — bereits in Phase 1 ausgeschlossen, hier nur
  bestätigt.

## Offene Punkte

1. **Lohnt die Kartenzuordnung?** Sie ist billig, aber ihr Nutzen ist
   unbewiesen (siehe oben). Falls der Durchstich zeigt, dass die Engine
   nichts damit anfängt, ersatzlos streichen — das spart einen Tipp pro Zug.
2. **Reichen die Tierwürfel?** 75 Stück für bis zu 4 Spieler. v1 nimmt an,
   dass der Vorrat nie leer wird, und bildet die Grenze nicht ab. Falls doch
   je ein Engpass auftritt, ist es ein Regelfall, den v1 falsch spielt.
3. **Wie tief wird gesucht?** Eine Umfangsfrage nur scheinbar — sie hängt am
   Verfahren und gehört damit in Phase 4.
4. **Was heißt „kein offensichtlicher Unsinn"?** Die Abnahme von v1 braucht
   ein Kriterium, das man am Tisch anwenden kann. Vorschlag zur Prüfung am
   Durchstich: kein Zug, der einen freien Tierwürfel liegen lässt, den er
   hätte setzen können.
