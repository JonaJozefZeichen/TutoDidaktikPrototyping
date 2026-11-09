# Tuto Didaktik-Tool und Bereich für Lehrende (lokaler Teststand)

Website, auf der das Didaktik-Team Aufgaben importiert, kontrolliert, verbessert und für die App freigibt. Konzept: *Design Document; Didaktik-Tool.md* im Tuto-Vault.

Im selben Programm läuft der **Bereich für Lehrende** (Lehrpersonen an Schulen und Nachhilfelehrer\*innen von Mindlink): Klassen (Kompetenzen der Klasse, Zuweisungen mit Bearbeitungsstand, Förderpakete nur an die Betroffenen, Antworten pro Person), Aufgabenkatalog mit Filtern, Merkliste mit Ordnern, Pakete per Hand oder per Generator mit Sperren und Neu-Würfeln, Gruppen (Standard 1, A, B, C …) gegen Abschreiben, Drucken als PDF mit Lösungsblatt, zentrales Zuweisen mit Klassenbaum, Abgabedatum und Überprüfen, Versionen bei geänderten Aufgaben, Paket-Codes zum Teilen. Welcher Bereich erscheint, entscheidet die Testperson beim Start. Konzept: *Design Document; Lehrpersonen-Ansicht.md* im Tuto-Vault.

Das hier ist ein **Teststand**: kein echter Login, kein Supabase, keine Verbindung zur App.

## Demo

https://jonajozefzeichen.github.io/TutoDidaktikPrototyping/

Jeder Push auf `main` baut die Demo und veröffentlicht sie (`.github/workflows/pages.yml`). Sie läuft ohne Server direkt im Browser, enthält nur 12 Beispielaufgaben und merkt sich Änderungen nur im jeweiligen Browser. Lokal bauen: `flutter build web --dart-define=DEMO=true`.

## Daten: Was öffentlich ist und was nicht

Dieses Repo ist öffentlich.

- `seed/privat/` ist **in Git ignoriert** und liegt nur lokal: Manuels Aufgaben und der volle Lernplan. Fehlt der Ordner, nutzen Server und Tests die Beispiele.
- `app/assets/beispiel/` ist öffentlich und wird mit `python3 tools/beispiele_erzeugen.py` aus `seed/privat/` erzeugt.
- `app/test/bilder/` und `app/test/failures/` sind ignoriert, weil die Bilder Aufgabentexte zeigen.
- Die Klassen im Bereich für Lehrende sind **erfundene Testdaten** (`testklassen.dart`), keine echten Personen; auch die Antworten pro Person sind erfunden.
- `app/assets/fonts/DejaVuSans*.ttf` (freie Lizenz, `DejaVuSans-LICENSE.txt`) dient nur dem PDF-Druck, weil sie Mathe-Zeichen wie ℕ, ∈ und ≤ enthält.

Vor jedem Commit darauf achten, dass keine weiteren Aufgaben in andere Dateien geraten.

## Lokal starten

```
./start.sh
```

Baut die Web-App bei Bedarf, startet den Server und öffnet http://127.0.0.1:8787. Beim ersten Start werden Manuels 258 Aufgaben als Entwürfe importiert.

| Befehl | Wirkung |
|---|---|
| `./start.sh --dev` | mit `flutter run` auf http://localhost:8788, Hot Reload mit `r` |
| `./start.sh --reset` | sichert die Testdaten nach `server/data/` und beginnt neu |

**Zwei Approvals testen:** zwei Fenster öffnen und verschiedene Testpersonen wählen. Beim Neuladen der Seite wählt man die Person neu.

**Bereich für Lehrende testen:** beim Start "Test-Lehrperson Schule" oder "Test-Nachhilfe Mindlink" wählen. Lehrpersonen sehen später nur freigegebene Aufgaben; im Teststand zeigt der Schalter "Entwürfe zeigen" auch Entwürfe, sonst wäre der Store leer. Merkliste und Pakete speichert der Server nach `server/data/lehrbereich.json` (`--reset` sichert auch diese Datei).

**Tastenkürzel im Editor:** Cmd/Strg + S speichern, Cmd/Strg + Enter Approval, Strg + `.` und Strg + `,` nächste und vorherige Aufgabe.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `packages/didaktik_kern/` | reines Dart: Feldliste, Prüfung, Freigabe-Regeln (`Bestand`), Routen (`Schnittstelle`) |
| `packages/didaktik_kern/lib/src/lehre/` | Bereich für Lehrende: Store-Zeilen und Filter, Generator und Gruppen A/B/C (`paket.dart`), Ablage pro Person (`Lehrbereich`), Testklassen |
| `server/` | lokaler Server (shelf), hört nur auf 127.0.0.1, speichert nach `server/data/bestand.json` und `lehrbereich.json` |
| `app/` | Flutter Web: Übersicht, Aufgaben, Editor, Import, Hilfe; `lib/lehre/` für den Bereich der Lehrenden |
| `seed/privat/` | nur lokal: Startbestand und Listen aus dem Prototyp und Vault |
| `tools/hilfe_sync.py` | holt Bauplan und Matura-Themen aus dem Vault |
| `tools/beispiele_erzeugen.py` | erzeugt die öffentlichen Beispiele |

Alle Regeln liegen in `Bestand`, die Routen in `Schnittstelle`. Der lokale Server und die Demo (`app/lib/demo.dart`) rufen beide dasselbe auf. Lokal gelten die Regeln auch bei direkten Anfragen an den Server; in der Demo laufen sie im Browser und sind dort nicht geschützt.

**Kopien aus dem Prototyp** (TutoPrototyping, Commit `c4d4e8d`), jeweils mit Kopfkommentar:

- `packages/didaktik_kern/lib/src/aus_prototyp/`: `content`, `answer_checker`, `term`; Änderungen: `zurueckgezogen` gilt als Status, und `answer_checker` liefert Fehlerbilder auch für `mc_2aus5`, `lueckentext`, `zuordnung`, Terme und Mehrfeld-Werte.
- `app/lib/vorschau/`: Antwort-Widgets, Medien und Design System; `design_system_controller.dart` ist vereinfacht, weil das Original `dart:io` nutzt.

Sie werden ersetzt, sobald Tool und App ein gemeinsames Paket bekommen (Phase 5). Bis dahin Änderungen am Prototyp bei Bedarf von Hand nachziehen.

## Testen

```
(cd packages/didaktik_kern && dart test)
(cd server && dart test)
(cd app && flutter test)
```

`app/test/bilder/` enthält gerenderte Bilder der Seiten. Nach sichtbaren Änderungen neu erzeugen: `flutter test test/bilder_test.dart --update-goldens`.

Texte und den Leitfaden (PDF) aus dem Vault aktualisieren: `python3 tools/hilfe_sync.py`.

## Noch nicht drin

Echter Login, Supabase und Hosting, Anbindung der App, Meldungen und Urgent, Kommentare, Levels bearbeiten, SRDP-Import-Seite, Medien-Upload. Im Bereich für Lehrende: echte Klassen und Lernstände, Verschicken an Schüler\*innen, Ergebnisse, Melden, SRDP-Aufgaben im Store, PDF-Export eines Pakets. Änderungen im Browser werden erst beim Speichern gesichert; Neuladen der Seite verwirft ungespeicherte Änderungen ohne Nachfrage.
