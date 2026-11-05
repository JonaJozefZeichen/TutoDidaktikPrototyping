# Bauplan Aufgabenerstellung

Anleitung für das Didaktik-Team: wie Levels, Aufgaben und Items in Tuto aufgebaut sind und wie man sie so erfasst, dass die App sie anzeigen, automatisch korrigieren und für Lernstand, Wiederholungen und Belohnungen nutzen kann. Warum das Modell so aufgebaut ist und was die App mit den Angaben macht, erklärt das Aufgaben-Datenmodell & App-Logik.


## Kernbegriffe

| Begriff | Bedeutung |
|---|---|
| **Aufgabe** | eine Rechnung oder Frage, die Punkte wert ist. Meist eine Einzelaufgabe mit genau einem Item; Kontextaufgaben mit mehreren verbundenen Fragen gibt es im Matura-Bereich, in Tuto-Schularbeit und Mini-Matura und im Lernpfad, wenn das Didaktik-Team sie dafür freigibt. |
| **Level** | eine Sammlung mehrerer ähnlicher Aufgaben zu einem Lernziel, mit fester ID wie `AG5-13`; festgelegt über Plätze |
| **Kapitel** | eine Sammlung von Levels zum gleichen Thema, meist fünf, z. B. `AG5-11` bis `AG5-15` "Gleichungen und Gleichungssysteme" |
| **Kreuzung** | ein Level (`X5-01` …), das von mehreren Levels aus verschiedenen Kapiteln und Kompetenzen abhängt, meist aus zwei oder drei Themenbereichen |
| **Lernwelt** | der Stoff einer Klasse (5.-8. Klasse, Schulstufe 9-12) |
| **Themenbereich** | AG (Algebra und Geometrie), FA (Funktionale Abhängigkeiten), AN (Analysis), WS (Wahrscheinlichkeit und Statistik) |
| **Lernpfad** | genau einer pro Lernwelt und Themenbereich; die vier Lernpfade einer Klasse laufen parallel |
| **Item** | die kleinste bewertbare Einheit: eine Antwort mit 0, ½ oder 1 Punkt |
| **Kompetenz** | das, was gemessen wird; jedes Item gehört zu einer Kompetenz, an der der Lernstand hängt |

## Aufbau

```
Lernwelt          eine Klasse, z. B. "5. Klasse: Das Fundament"
 > Themenbereich  AG, FA, AN oder WS
  > Lernpfad      genau einer pro Lernwelt und Themenbereich
   > Kapitel      Levels zum gleichen Thema
    > Level       ein Lernziel mit fester ID, z. B. AG5-13 "Quadratische Lösungsformel"
     > Aufgabenpaket  4-5 Plätze: feste Aufgaben oder Vorgaben aus Kompetenz und Format
      > Aufgabe   eine Rechnung oder Frage mit Stamm (Einleitung, Medien)
       > Item     die bewertbare Antwort
```

Neben den Levels aus dem Lernplan gibt es drei besondere Level-Arten, die keine festen Aufgaben brauchen: **Wiederholungs-Levels** (`AG5-W03`) fragen früheren Stoff erneut ab, die **Tuto-Schularbeit** (`AG5-S`) ist das letzte Level jedes Lernpfads, und die **Tuto-Mini-Matura** wird frei, sobald alle vier Lernpfade einer Klasse abgeschlossen sind. Die App stellt ihre Aufgaben beim Öffnen aus dem Bestand der Levels zusammen.

**Umfang:** 4-7 Levels pro Thema (Kapitel) mit je 4-5 Aufgaben, also etwa 20-30 Aufgaben pro Thema. Dazu kommen Varianten, damit Wiederholungen nicht dieselben Aufgaben zeigen.

## Dateiaufbau

Levels und Aufgaben kommen als zwei getrennte JSON-Dateien in die App:

- **Level-Datei:** `lernwelten` (Klasse, Name, Schulstufe) und `levels` (alle Levels mit ihren Feldern). Das Aufgabenpaket eines Levels verweist auf Aufgaben-IDs.
- **Aufgaben-Datei:** `quelle` (Herkunft als Text) und `aufgaben` (alle Aufgaben mit ihren Items). Jede Aufgabe nennt in `level`, in welchen Levels sie vorkommt.

Feldnamen sind deutsch und ohne Umlaute (`aufgabenstellung`, `loesungsweg`). Eine Aufgabe kann in mehreren Levels und zusätzlich im Matura-Bereich stehen.

## Ein Level anlegen

Für jedes Level aus dem Lernplan wird einmal festgelegt, was es ist und welche Aufgaben an welcher Stelle vorkommen.

| Feld | Pflicht | Bedeutung und erlaubte Werte |
|---|---|---|
| `level_id` | ja | ID aus dem Lernplan: Themenbereich + Klasse + Nummer (`AG5-13`), Kreuzung `X5-01`, Wiederholungs-Level `AG5-W03`, Schularbeit `AG5-S`. Wird nie geändert oder neu vergeben. |
| `titel` | ja | kurzer Name, z. B. "Quadratische Lösungsformel" |
| `schulstufe` | ja | 9-12 (= 5.-8. Klasse) |
| `themenbereich` | ja | AG / FA / AN / WS; bei Kreuzungen der Lernpfad, in dem das Level steht |
| `kapitel` | ja | Nummer und Titel, z. B. 3 "Gleichungen und Gleichungssysteme" |
| `reihenfolge` | ja | Position im Lernpfad, Kreuzungen und besondere Levels mitgezählt |
| `level_typ` | – | `grundlagen` neue Kompetenz aufbauen · `uebung` sicher anwenden · `transfer` zwischen Darstellungen und Kontexten wechseln · `kreuzung` Voraussetzungen aus verschiedenen Kapiteln und Kompetenzen · `wiederholung` früheren Stoff erneut abfragen · `schularbeit` Tuto-Schularbeit |
| `kennzeichnung` | – | `kern` Lehrplan-Kern · `bruecke` Wiederholung/Brücke · `vertiefung` Vertiefung |
| `fix` | – | `ja`: Einstiegs-Level eines Kapitels mit festen Aufgaben und Erklärung, für alle gleich · `nein` (Standard): die App füllt die Plätze aus dem Bestand |
| `erklaerung` | bei fixen Levels | Erklärung von Thema und Methode (Text mit Formeln), wird vor den Aufgaben gezeigt und lässt sich jederzeit wieder aufrufen |
| `lernziel` | – | ein Satz: was man nach dem Level kann; fehlt es, zeigt die App den Titel |
| `kompetenzen` | ja | Kompetenz-Keys, die das Level trainiert |
| `voraussetzungen` | – | Levels, die vorher dran sein sollten. Fehlt eines, fragt die App nach, sperrt aber nicht. |
| `kreuzung_mit` | – | nur bei Kreuzungen: beteiligte Themenbereiche, z. B. `["AG", "FA"]` |
| `aufgabenpaket` | ja | **Plätze** in aufsteigender Reihenfolge (Grundlage → Anwendung → Transfer): feste Aufgabe oder Vorgabe aus Kompetenz, Format und Schwierigkeit (siehe unten). Entfällt bei Wiederholungs-Levels und Schularbeiten. |
| `wiederholung_aus` | – | nur bei Wiederholungs-Levels und Schularbeiten: aus welchen Levels abgefragt wird |

### Das Aufgabenpaket: Plätze

Ein Level besteht aus **Plätzen**, meist 4-5, in aufsteigender Reihenfolge. Jeder Platz ist eines von beidem:

| Platz | Aufbau | Wofür |
|---|---|---|
| **fest** | `{"platz": 1, "aufgabe": "tuto-ag5-normal-001"}` | fixe Levels: alle bekommen dieselbe Aufgabe |
| **Vorgabe** | `{"platz": 2, "kompetenz": "ag-normalvektoren", "format": "halboffen", "schwierigkeit": "mittel"}` | alle anderen Levels: die App wählt bei jedem Durchgang eine passende Aufgabe aus dem Bestand |

- `format` ist ein Antwortformat oder `beliebig`; `schwierigkeit` ist `leicht` (Startschwierigkeit 1-2), `mittel` (3), `schwer` (4-5) oder leer.
- Für einen Vorgabe-Platz kommen alle geprüften Aufgaben mit dieser Kompetenz, diesem Format und dieser Schwierigkeit in Frage, die zur Klasse passen. Die Aufgaben müssen deshalb nicht einzeln im Level stehen; es genügt, dass sie die richtige Kompetenz haben.
- Die App nimmt zuerst Aufgaben, die die Person noch nie gesehen hat, dann die am längsten nicht gesehenen. So erschöpft sich der Bestand auch nicht, wenn jemand ein Level oft wiederholt. Pro Platz sollten mindestens drei passende Aufgaben im Bestand sein; Vorlagen mit Zufallszahlen zählen wie unbegrenzt viele.
- **Fixe Levels** stehen am Anfang jedes Kapitels: feste Plätze und eine `erklaerung`, damit alle gleich in ein neues Thema starten. Beim Wiederholen kommen dieselben Aufgaben als Erinnerung.
- Aufgaben für "Kapitel vertiefen" stehen zusätzlich im Paket mit der Rolle `vertiefung`: `{"aufgabe": "…", "rolle": "vertiefung"}`.


## Eine Aufgabe anlegen

| `zusammenstellung` | Aufbau | Einsatz |
|---|---|---|
| `einzel` | Stamm + genau 1 Item | Lernpfad, Daily Challenge, Matura Typ 1 |
| `kontext` | Stamm + 2-3 Teilaufgaben mit je 1-3 Items (meist 4); Items dürfen aufeinander aufbauen | Matura Typ 2, Schularbeit, Mini-Matura |
| `kontext_reduziert` | wie `kontext`, alle Items unabhängig voneinander lösbar | Matura Typ 2 rk, Schularbeit, Mini-Matura |

| Feld | Pflicht | Bedeutung und erlaubte Werte |
|---|---|---|
| `id` | ja | Tuto-ID, z. B. `tuto-ag5-loesungsformel-001` (tuto-, Themenbereich und Klasse, Stichwort, laufende Nummer) |
| `titel` | ja | kurzer Titel |
| `herkunft` | ja | `team` (selbst geschrieben) / `srdp` (aus der Matura) |
| `externe_referenzen` | – | nur bei übernommenen Aufgaben: Quelle, Nummer, Termin, Pflicht-Quellenangabe |
| `level` | – | Levels, in deren Aufgabenpaket die Aufgabe steht |
| `matura_thema` | – | Thema im Matura-Bereich, z. B. `MFA-15` |
| `zusammenstellung` | ja | siehe oben |
| `matura_typ` | – | `typ1` / `typ2` / `typ2_rk`; nur bei Matura- oder bewusst matura-artigen Aufgaben |
| `matura_niveau` | ja | `einstieg` / `uebung` / `matura` |
| `schultyp`**, **`schulstufe` | ja | `AHS` / `BHS`; 9-13 (bei Aufgaben mit Level aus dem Level) |
| `kontext` | ja | `innermathematisch`, `alltag`, `naturwissenschaft`, `technik`, `wirtschaft`, `sport`, `gesundheit`, `gesellschaft`: das Umfeld der Aufgabe, nicht der Stoff. Lehrpersonen filtern damit, z. B. alle Sport-Aufgaben einer Kompetenz. |
| `stamm` | ja | Einleitungstext, Formeln in LaTeX (`$x^2$`); bei Vorlagen mit Platzhaltern `{name}` |
| `medien` | – | Bilder, Graphen, Tabellen, Diagramme mit Datei und "Rechte geklärt ja/nein" |
| `technologie` | ja | `ohne` / `taschenrechner` / `cas` |
| `parametrisierbar` | ja | `ja` / `nein`; bei `ja` in `parameter` Name, min, max, Schritt (siehe Varianten und Vorlagen) |
| `variantengruppe` | – | gemeinsamer Schlüssel gleichwertiger Varianten, z. B. `AG5-13-A`; in einem Durchgang kommt höchstens eine Aufgabe pro Gruppe |
| `lernpfad_geeignet` | – | `ja` / `nein`: darf im Lernpfad vorkommen. Standard: Einzelaufgaben `ja`, Kontextaufgaben `nein`; das Didaktik-Team gibt Kontextaufgaben frei, die in den Lernpfad passen |
| `unterwegs` | – | leer lassen, die App leitet es ab (kurze Einzelaufgaben ohne CAS); nur zum Überschreiben setzen |
| `teilaufgaben` | – | nur bei Kontextaufgaben: Teil a/b/c mit Zusatztext und Items |
| `items` | ja | bei Einzelaufgaben direkt hier, sonst in den Teilaufgaben |
| `status` | ja | `entwurf` → `geprueft` → `live`, außerdem `zurueckgezogen`; nur `live` ist für Lernende sichtbar |

## Ein Item anlegen

| Feld | Pflicht | Bedeutung und erlaubte Werte |
|---|---|---|
| `item_id` | ja | `<aufgaben-id>-1` bei Einzelaufgaben, sonst `-a1`, `-a2`, `-b1` … |
| `aufgabenstellung` | ja | Text + LaTeX, beginnt mit dem Operator ("Berechne …") |
| `operator`**, **`handlungsbereich` | ja | aus der Operatorenliste; H1 Darstellen/Modellbilden · H2 Rechnen/Operieren · H3 Interpretieren · H4 Argumentieren/Begründen |
| `inhaltsbereich` | ja | AG / FA / AN / WS |
| `kompetenz` | ja | Kompetenz-Key aus Themenbereich und Stichwort, z. B. `ag-allgemeine-loesungsformel`; aus der Kompetenzliste übernehmen |
| `kompetenz_sekundaer` | – | weitere Kompetenzen, z. B. bei Kreuzungen |
| `grundkompetenz` | – | z. B. `AG2.3` nach dem Grundkompetenzkatalog vom November 2024; nur zur Kontrolle |
| `antwortformat`**, **`antwort` | ja | eines der zehn Formate mit der Lösung (siehe Antwortformate) |
| `punkteschema` | ja | `0/1` oder `0/½/1`; bei `0/½/1` dazu `halbpunkt_regel` (`je_luecke` · `je_wert` · `zuordnung_2_bis_3`) |
| `loesungsweg` | ja | Lösungsschritte, werden nach der Abgabe gezeigt |
| `fehlerbilder` | – | typische falsche Antwort → Name, z. B. `"-2": "vorzeichenfehler"`. Schlüssel je Format: Ankreuzformate der Index der Option (`"2"`), `lueckentext` Lücke und Option (`"1:2"`), `zuordnung` der Buchstabe (`"E"`), offene Zahlen der Wert (`"6.25"`, mehrere Felder `"2; 3"`), Terme der Term; Name nur aus Kleinbuchstaben, Ziffern und `_`; nicht bei selbst bewerteten Formaten. Im Didaktik-Tool trägt man sie direkt bei den falschen Antworten ein |
| `hilfen` | ja | drei Hilfen (Stufe 1-3) mit Text und Freigabe-Regel |
| `abhaengig_von`, `folgefehler` | – | nur bei Kontextaufgaben: früheres Item, auf dem dieses aufbaut; `ja` = gegen die eigene frühere Antwort werten |
| `schwierigkeit_start` | ja | 1-5, eigene Schätzung (siehe unten) |
| `erwartete_sekunden` | – | geschätzte Bearbeitungszeit |

| `schwierigkeit_start` | Bedeutung |
|---|---|
| 1 | sehr leicht: Brücke aus der Unterstufe, für schwache Lernende |
| 2 | leicht: Grundaufgabe, direkt nach der Erklärung lösbar |
| 3 | mittel: Anwendung in einem kleinen Kontext |
| 4 | schwer: Transfer, mehrere Schritte oder ungewohnte Darstellung |
| 5 | sehr schwer: für "Kapitel vertiefen" |

Standard beim Erfassen ist 2-4. Die App lernt die echte Schwierigkeit aus den Antworten.

## Antwortformate

| `antwortformat` | Aufbau von `antwort` | Prüfung |
|---|---|---|
| `mc_1aus5`, `mc_1aus6` | `optionen` (5 bzw. 6 Texte), `richtig` (Index) | automatisch |
| `mc_2aus5` | `optionen` (5 Texte), `richtig` (2 Indizes); genau zwei Kreuze möglich | automatisch |
| `lueckentext` | `satz` mit `{1}` und `{2}`, `luecke_1` und `luecke_2` mit je 3 Optionen, `richtig` (je ein Index) | automatisch |
| `zuordnung` | `elemente` (4), `optionen` (6, A-F), `richtig` (Element → Buchstabe) | automatisch |
| `halboffen` | `vorlage` mit Eingabefeld `{x}` (bei mehreren Zahlen `{x}`, `{y}`, `{z}`), `art` (`zahl` / `term`), `wert` (Zahl oder Liste), `reihenfolge_egal`, `toleranz`, `einheit`, `einheit_pflicht`, `rundung`; statt `wert` auch `formel` (Vorlagen) oder `pruefregel` mit `beispiel` (eine richtige Antwort als Liste, die nach der Abgabe als Lösung gezeigt wird) | automatisch |
| `offen_zahl` | `wert`, `toleranz`, `einheit`, `einheit_pflicht`, `rundung`; bei Vorlagen `formel` statt `wert` | automatisch |
| `offen_term` | `term`; geprüft wird Gleichwertigkeit, nicht die Schreibweise | automatisch |
| `offen_text` | `musterloesung` (Text oder Liste von Musterantworten), `bewertungskriterium` | Selbstvergleich |
| `konstruktion` | `zeichenflaeche`, `bereich`, `ziel` (`punkt` / `vektor` / `gerade` / `graph` / `flaeche` / `saeule`), `geometrie`, `toleranz` | Selbstvergleich |

### Zahlenpaare und Lösungslisten

Mehrere Zahlen bekommen **immer ein Eingabefeld pro Zahl**, nie ein Textfeld für "1;3": Mit deutschem Dezimalkomma wäre "1,3" eins Komma drei. In der `vorlage` steht pro Zahl ein Platzhalter, in `wert` die Liste der Lösungen. `reihenfolge_egal: ja` erlaubt die Lösungen in beliebiger Reihenfolge (z. B. zwei Nullstellen), `nein` verlangt sie wie angegeben (z. B. Koordinaten eines Punktes).

```json
"antwort": { "vorlage": "x₁ = {x}   x₂ = {y}", "art": "zahl", "wert": [2, 3], "reihenfolge_egal": "ja", "toleranz": 0 }
```

### Prüfregeln

Hat eine Aufgabe mehrere richtige Antworten (ein Normalvektor, ein Punkt auf einer Geraden), steht statt `wert` eine `pruefregel`: eine Liste von Regeln aus einer festen Sammlung, die alle stimmen müssen. Dazu kommt das Feld **`beispiel`**: eine richtige Antwort als Liste mit einer Zahl pro Eingabefeld, z. B. `"beispiel": [-2, 3]`. Die App zeigt sie nach der Abgabe als Lösung ("Zum Beispiel: n = (−2 | 3)") und weist darauf hin, dass es mehrere richtige Antworten gibt.

| `regel` | richtig, wenn … | Eintrag |
|---|---|---|
| `orthogonal_zu` | der Vektor normal auf den angegebenen steht und nicht der Nullvektor ist | `{"regel": "orthogonal_zu", "vektor": [3, 2]}` |
| `parallel_zu` | der Vektor ein Vielfaches des angegebenen ist (nicht der Nullvektor) | `{"regel": "parallel_zu", "vektor": [3, 4]}` |
| `laenge` | der Vektor die angegebene Länge hat | `{"regel": "laenge", "wert": 1, "toleranz": 0.01}` |
| `erfuellt_gleichung` | die eingegebenen Werte (`x`, `y`, `z`) die Gleichung erfüllen | `{"regel": "erfuellt_gleichung", "gleichung": "y = 2x + 1"}` |

Ein Einheitsvektor in Richtung (3|4) ist `parallel_zu` [3, 4] und `laenge` 1 in einer Liste.

### Terme

Bei `offen_term` und `halboffen` mit `art: term` tippen Lernende einen Term oder eine Gleichung in ein Textfeld. Unter dem Feld steht eine **Symbolleiste** mit `x`, `y`, `²`, `^`, `√`, `π`, `(`, `)`, `·`, `/` und `−`, die das Zeichen an der Cursor-Position einfügt, weil Handy-Tastaturen diese Zeichen kaum haben. Normale Tasten funktionieren auch: `*` für mal, `^` für Hochzahlen (`x^3`), `sqrt(…)` für Wurzeln.

Die App rechnet beide Terme an mehreren Zufallsstellen aus und vergleicht die Werte; `4+1,5x`, `1,5x + 4` und `f(x) = 1,5x + 4` gelten damit gleich. Erlaubt sind Komma und Punkt, `+ − · / ^`, Hochzahlen wie `x²`, Klammern, Wurzeln, `sin`, `cos`, `tan`, `ln`, `π` und `e`.

### Weitere Hinweise

- Einheit und Rundung nur verlangen (`einheit_pflicht: ja`, `rundung`), wenn die Aufgabe es ausdrücklich fordert. Lange oder periodische Ergebnisse gelten auch richtig gerundet als richtig.
- Toleranz großzügig genug für korrekte Zwischenrundungen wählen.
- Distraktoren bei Ankreuz- und Lückentext-Aufgaben als typische Denkfehler bauen und in `fehlerbilder` benennen.
- Optionen so schreiben, dass sie in jeder Reihenfolge stimmen (kein "alle oben genannten", kein "keine der anderen"), weil die App sie später gemischt zeigt.
- Mengen und Intervalle als Multiple Choice oder als `offen_text` mit Selbstvergleich erfassen.

## Varianten und Vorlagen

Ein Level braucht mehrere ähnliche Aufgaben, damit die App variieren und wiederholen kann, ohne dass jemand die Lösung auswendig lernt.

- **Parametrisierte Vorlage** für gleichwertige Varianten: `parametrisierbar: ja`, in `parameter` die Zufallswerte (`name`, `min`, `max`, `schritt`), im Text Platzhalter `{name}` und in `antwort` die Lösung als `formel`. Die App zieht bei jedem Öffnen neue Werte. Parameter dürfen nicht `x`, `y` oder `z` heißen (das sind Eingabefelder).
- Werte so wählen, dass die Lösung "schön" bleibt: erst die Lösung festlegen, dann die Angabe bauen (z. B. bei quadratischen Gleichungen die Lösungen wählen).
- **Eigene Aufgaben** für leichtere oder schwerere Varianten: andere Zahlen allein ändern die Schwierigkeit kaum.
- Begriffsfragen und Multiple Choice mit inhaltlichen Distraktoren eignen sich kaum als Vorlage.
- Entwürfe für Varianten, Zusatzaufgaben und Hilfen dürfen mit KI entstehen; der Status geht erst nach Prüfung durch das Didaktik-Team auf `geprueft`.

## Hilfen

Jede Aufgabe hat **drei Hilfen**. Sie sind anfangs gesperrt und werden nach Zeit oder nach einem Fehlversuch freigegeben.

| Stufe | Inhalt | Beispiel (2x² − 3x − 2 = 0) |
|---|---|---|
| 1 Orientierung | Was ist gefragt, worauf achten? | "Gesucht sind alle x, für die der Term null wird." |
| 2 Strategie | Welches Verfahren passt? | "Lies a, b und c ab und setze in die Lösungsformel ein." |
| 3 Lösungsansatz | konkreter erster Schritt | "a = 2, b = −3, c = −2. Unter der Wurzel steht 9 + 16." |

- Freigabe-Regel pro Stufe: `{"nach_sekunden": 40}` oder `{"nach_fehlversuchen": 1}`.
- Eine Hilfe kostet etwas Punkte und zählt etwas weniger für die Sterne, ist aber kein Fehler.
- In der App erzeugt keine KI Hilfen; alle Hilfen sind vorgefertigt und geprüft.

## Operatoren

| Handlungsbereich | Operatoren (Feldwert) |
|---|---|
| H1 Darstellen, Modellbilden | aufstellen, erstellen, einzeichnen, skizzieren, eintragen, kennzeichnen, markieren, veranschaulichen, vervollstaendigen, beschriften |
| H2 Rechnen, Operieren | berechnen, ermitteln, angeben, ablesen, abschaetzen, umformen |
| H3 Interpretieren | interpretieren, beschreiben |
| H4 Argumentieren, Begründen | begruenden, erklaeren, argumentieren, nachweisen, zeigen, ueberpruefen |
| formatgebunden | ankreuzen, ergaenzen, zuordnen |

## Beispiele

### A: Level mit Plätzen, fixes Level und Einzelaufgabe

```json
{ "level_id": "AG5-13", "titel": "Quadratische Lösungsformel", "schulstufe": 9,
  "themenbereich": "AG", "kapitel": { "nummer": 3, "titel": "Gleichungen und Gleichungssysteme" },
  "reihenfolge": 15, "level_typ": "uebung", "kennzeichnung": "kern", "fix": "nein",
  "lernziel": "Quadratische Gleichungen mit der Lösungsformel lösen.",
  "kompetenzen": ["ag-allgemeine-loesungsformel"], "voraussetzungen": ["AG5-12"],
  "aufgabenpaket": [ { "platz": 1, "kompetenz": "ag-allgemeine-loesungsformel", "format": "offen_zahl", "schwierigkeit": "leicht" },
                     { "platz": 2, "kompetenz": "ag-allgemeine-loesungsformel", "format": "halboffen" },
                     { "platz": 3, "kompetenz": "ag-allgemeine-loesungsformel", "format": "mc_1aus6" },
                     { "platz": 4, "kompetenz": "ag-allgemeine-loesungsformel", "format": "beliebig", "schwierigkeit": "schwer" } ] }

{ "level_id": "AG5-11", "titel": "Lineare Gleichungen", "fix": "ja", "level_typ": "grundlagen",
  "erklaerung": "Eine lineare Gleichung löst man, indem man auf beiden Seiten dasselbe rechnet, bis x allein steht …",
  "aufgabenpaket": [ { "platz": 1, "aufgabe": "tuto-ag5-lineare-gl-001" },
                     { "platz": 2, "aufgabe": "tuto-ag5-lineare-gl-002" } ] }

{ "id": "tuto-ag5-loesungsformel-001", "titel": "Größere Lösung", "herkunft": "team",
  "level": ["AG5-13"], "zusammenstellung": "einzel", "matura_niveau": "uebung",
  "schultyp": "AHS", "schulstufe": 9, "kontext": "innermathematisch", "stamm": "",
  "technologie": "ohne", "parametrisierbar": "nein", "variantengruppe": "AG5-13-A", "status": "entwurf",
  "items": [ {
    "item_id": "tuto-ag5-loesungsformel-001-1",
    "aufgabenstellung": "Berechne die größere Lösung von $x^2 - 6x + 5 = 0$.",
    "operator": "berechnen", "handlungsbereich": "H2", "inhaltsbereich": "AG",
    "kompetenz": "ag-allgemeine-loesungsformel", "grundkompetenz": "AG2.3",
    "antwortformat": "offen_zahl",
    "antwort": { "wert": 5, "toleranz": 0, "einheit": null, "einheit_pflicht": "nein", "rundung": null },
    "punkteschema": "0/1",
    "loesungsweg": ["a = 1, b = −6, c = 5", "x = (6 ± √(36 − 20)) / 2 = (6 ± 4) / 2", "x₁ = 5, x₂ = 1"],
    "fehlerbilder": { "1": "kleinere_loesung", "-1": "vorzeichen_von_b_falsch" },
    "hilfen": [
      { "stufe": 1, "text": "Gesucht sind beide x mit x² − 6x + 5 = 0; gefragt ist die größere.", "freigabe": { "nach_sekunden": 40 } },
      { "stufe": 2, "text": "Lies a, b und c ab und setze in die Lösungsformel ein.", "freigabe": { "nach_fehlversuchen": 1 } },
      { "stufe": 3, "text": "a = 1, b = −6, c = 5. Unter der Wurzel steht 36 − 20.", "freigabe": { "nach_fehlversuchen": 2 } } ],
    "schwierigkeit_start": 2, "erwartete_sekunden": 90 } ] }
```

### B: Parametrisierte Vorlage

```json
{ "id": "tuto-fa5-tarif-001", "titel": "Kosten eines Tarifs", "level": ["FA5-10"],
  "zusammenstellung": "einzel", "kontext": "alltag", "technologie": "ohne",
  "parametrisierbar": "ja",
  "parameter": [ { "name": "grund", "min": 5, "max": 20, "schritt": 1 },
                 { "name": "preis", "min": 1, "max": 5, "schritt": 1 },
                 { "name": "n", "min": 4, "max": 15, "schritt": 1 } ],
  "variantengruppe": "FA5-10-C",
  "items": [ {
    "aufgabenstellung": "Ein Tarif kostet {grund} € Grundgebühr plus {preis} € je Einheit. Berechne die Kosten für {n} Einheiten.",
    "antwortformat": "offen_zahl",
    "antwort": { "formel": "grund + preis * n", "toleranz": 0, "einheit": "€", "einheit_pflicht": "nein" },
    "loesungsweg": ["K = {grund} + {preis} · {n}"] } ] }
```

### C: Zahlenpaar und Prüfregel

```json
"antwortformat": "halboffen",
"aufgabenstellung": "Lies beide Nullstellen der dargestellten Funktion ab.",
"antwort": { "vorlage": "x₁ = {x}   x₂ = {y}", "art": "zahl", "wert": [-2, 3], "reihenfolge_egal": "ja", "toleranz": 0 }

"antwortformat": "halboffen",
"aufgabenstellung": "Gib einen Normalvektor zur Richtung (3|2) an.",
"antwort": { "vorlage": "n = ({x} | {y})", "art": "zahl",
             "pruefregel": [ { "regel": "orthogonal_zu", "vektor": [3, 2] } ], "beispiel": [-2, 3] }
```

Damit gelten (−2|3), (2|−3), (4|−6) … als richtig.

### D: Term

```json
"antwortformat": "offen_term",
"aufgabenstellung": "Eine Gerade geht durch A(0|1) und B(1|3). Gib die Funktionsgleichung f(x) an.",
"antwort": { "term": "2x + 1" }
```

### E: Kreuzung und Wiederholungs-Level

```json
{ "level_id": "X5-01", "titel": "Tarifvergleich: Zwei Lieferservices", "schulstufe": 9,
  "themenbereich": "FA", "kapitel": { "nummer": 2, "titel": "Lineare Funktionen" }, "reihenfolge": 12,
  "level_typ": "kreuzung", "kreuzung_mit": ["AG", "FA"],
  "lernziel": "Zwei lineare Kostenmodelle gleichsetzen und das Ergebnis interpretieren.",
  "kompetenzen": ["ag-loesungsfaelle-unterscheiden", "fa-lineare-modelle-interpretieren"],
  "voraussetzungen": ["AG5-15", "FA5-10"],
  "aufgabenpaket": [ { "platz": 1, "kompetenz": "fa-lineare-modelle-interpretieren", "format": "offen_zahl" },
                     { "platz": 2, "kompetenz": "ag-loesungsfaelle-unterscheiden", "format": "beliebig" } ] }

{ "level_id": "AG5-W03", "titel": "Wiederholung: Gleichungen und Gleichungssysteme",
  "schulstufe": 9, "themenbereich": "AG",
  "kapitel": { "nummer": 3, "titel": "Gleichungen und Gleichungssysteme" }, "reihenfolge": 18,
  "level_typ": "wiederholung", "kompetenzen": [], "wiederholung_aus": ["AG5-11", "AG5-12", "AG5-13", "AG5-14", "AG5-15"] }
```

### F: Kontextaufgabe für die Mini-Matura

```json
{ "id": "tuto-mm5-inselarchitekt-001", "titel": "Der Inselarchitekt", "herkunft": "team",
  "zusammenstellung": "kontext_reduziert", "matura_niveau": "uebung", "schulstufe": 9,
  "kontext": "gesellschaft", "technologie": "taschenrechner",
  "stamm": "Für die Insel wird ein neuer Park geplant: Wege, Transport, Besucher und Nachfrage.",
  "teilaufgaben": [
    { "teil": "a", "items": [ { "aufgabenstellung": "Gib den Verschiebungsvektor von (1|1) nach (4|5) an.",
        "kompetenz": "ag-vektoren-darstellen", "antwortformat": "halboffen",
        "antwort": { "vorlage": "({x} | {y})", "art": "zahl", "wert": [3, 4], "reihenfolge_egal": "nein" } } ] },
    { "teil": "b", "items": [ { "aufgabenstellung": "K(x) = 30 + 4x. Berechne die Kosten bei 15 Fahrten.",
        "kompetenz": "fa-lineare-modelle-interpretieren", "antwortformat": "offen_zahl",
        "antwort": { "wert": 90, "toleranz": 0, "einheit": "€" } } ] } ] }
```

## Checkliste vor der Freigabe

- [ ] Lösung selbst nachgerechnet, Toleranz und Rundung passen zur Aufgabenstellung.
- [ ] Operator am Anfang der Aufgabenstellung und Handlungsbereich passen zusammen.
- [ ] Kompetenz-Key aus der Kompetenzliste übernommen; bei Stoff mit Grundkompetenz stimmt die GK.
- [ ] Zahlenpaare mit einem Feld pro Zahl; bei mehreren richtigen Antworten eine Prüfregel mit `beispiel`.
- [ ] Bei Kontextaufgaben: abhängige Items mit `abhaengig_von` und `folgefehler` markiert.
- [ ] Distraktoren und typische Fehlergebnisse als Fehlerbilder benannt.
- [ ] Drei Hilfen geschrieben (Stufen 1-3).
- [ ] `schwierigkeit_start` (meist 2-4) und `erwartete_sekunden` geschätzt.
- [ ] Level: 4-5 Plätze in aufsteigender Reihenfolge; fixe Levels mit festen Aufgaben und Erklärung, sonst Vorgaben mit mindestens drei passenden Aufgaben im Bestand.
- [ ] Kontextaufgaben nur mit `lernpfad_geeignet: ja` im Lernpfad.
- [ ] KI-Entwürfe inhaltlich geprüft.
- [ ] Medien: Rechte geklärt; bei Matura-Aufgaben Quellenangabe und Änderungsvermerk.
- [ ] Zwei Approvals von verschiedenen Personen: Das erste setzt `geprueft`, das zweite `live`. Jede inhaltliche Änderung setzt beide zurück.
