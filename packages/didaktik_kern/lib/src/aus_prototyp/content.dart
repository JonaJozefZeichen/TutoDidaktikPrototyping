// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/features/learning_engine/content.dart
// Bis zum gemeinsamen Paket hier nicht weiterentwickeln, siehe README.

/// Inhalt der Lern-Engine: Levels und Aufgaben im Format von "Aufgaben
/// Struktur" (Vault), geladen aus JSON. Reines Dart, damit die Engine ohne
/// Gerät testbar und für andere Fächer wiederverwendbar bleibt.
///
/// Die Engine liest nur Tags (Kompetenz, Format, Schwierigkeit, Fehlerbilder,
/// Hilfen …), nie Aufgabentexte. [ContentLoader] prüft das Schema beim Laden
/// und meldet Fehler, statt still mit Standardwerten weiterzumachen;
/// fehlerhafte Aufgaben kommen nicht in die Auswahl.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:didaktik_kern/src/aus_prototyp/term.dart';

const antwortformate = {
  'mc_1aus5',
  'mc_1aus6',
  'mc_2aus5',
  'lueckentext',
  'zuordnung',
  'halboffen',
  'offen_zahl',
  'offen_term',
  'offen_text',
  'konstruktion',
};

/// Formate, die die Test-Version automatisch prüft; der Rest wird selbst bewertet.
const automatischGepruefteFormate = {
  'mc_1aus5',
  'mc_1aus6',
  'mc_2aus5',
  'lueckentext',
  'zuordnung',
  'halboffen',
  'offen_zahl',
  'offen_term',
};

const levelTypen = {'grundlagen', 'uebung', 'transfer', 'kreuzung', 'wiederholung', 'schularbeit'};

/// Prüfregeln für Aufgaben mit mehreren richtigen Antworten ("Aufgaben Struktur").
const pruefregeln = {'orthogonal_zu', 'parallel_zu', 'laenge', 'erfuellt_gleichung'};

/// Platzhalter für Eingabefelder in `vorlage` (in dieser Reihenfolge).
/// Parameter parametrisierter Aufgaben dürfen nicht so heißen.
const eingabeFeldNamen = ['x', 'y', 'z'];

/// Eingabefelder einer Vorlage, z. B. `x1 = {x}, x2 = {y}` → `[x, y]`.
List<String> eingabeFelder(String vorlage) => [for (final m in RegExp(r'\{([xyz])\}').allMatches(vorlage)) m.group(1)!];

/// Zahl in deutscher Schreibweise (Komma, echtes Minus, ganze Zahlen ohne Nachkomma).
String zahlText(num v) {
  final gerundet = (v * 1e9).round() / 1e9;
  final s = gerundet == gerundet.roundToDouble() ? gerundet.round().toString() : gerundet.toString();
  return s.replaceAll('.', ',').replaceAll('-', '−');
}

/// Setzt Parameterwerte in einen Text ein (`{grund}` → `8`).
String fuelleParameter(String text, Map<String, num> werte) {
  if (werte.isEmpty) return text;
  var t = text;
  for (final e in werte.entries) {
    t = t.replaceAll('{${e.key}}', zahlText(e.value));
  }
  return t;
}

/// Ein Zufallswert einer parametrisierten Aufgabe.
class Parameter {
  const Parameter({required this.name, required this.min, required this.max, required this.schritt});
  final String name;
  final num min;
  final num max;
  final num schritt;

  /// Zufälliger Wert aus min, min + schritt, … , max.
  num ziehe(math.Random rng) {
    final stufen = ((max - min) / schritt).floor();
    final v = min + rng.nextInt(stufen + 1) * schritt;
    return v == v.roundToDouble() && min is int && schritt is int ? v.round() : (v * 1e9).round() / 1e9;
  }
}

/// Richtiger Wert eines Zahl-Items: `wert` (Zahl oder Liste) oder aus der
/// `formel` mit den Parameterwerten berechnet.
Object? loesungsWert(Item item, [Map<String, num> werte = const {}]) {
  final a = item.antwort;
  final formel = a['formel'];
  if (formel is String) {
    final t = Term.parse(formel, namen: werte.keys.toSet());
    final v = t?.wert({for (final e in werte.entries) e.key: e.value.toDouble()});
    return v == null || !v.isFinite ? null : v;
  }
  return a['wert'];
}

class Lernwelt {
  const Lernwelt({required this.klasse, required this.name});
  final int klasse;
  final String name;
}

class Kapitel {
  const Kapitel({required this.nummer, required this.titel});
  final int nummer;
  final String titel;
}

/// Ein Platz im Aufgabenpaket eines Levels: entweder eine feste Aufgabe
/// (fixe Levels) oder eine Vorgabe aus Kompetenz, Format und Schwierigkeit,
/// die die App bei jedem Durchgang aus dem Bestand füllt (Jona, 03.11.2026).
class Platz {
  const Platz({required this.nummer, this.aufgabeId, this.kompetenz, this.format, this.schwierigkeit});
  final int nummer;
  final String? aufgabeId;
  final String? kompetenz;

  /// Antwortformat oder `null` (= beliebig).
  final String? format;

  /// `leicht` (Startschwierigkeit 1-2), `mittel` (3), `schwer` (4-5) oder `null`.
  final String? schwierigkeit;

  bool get fest => aufgabeId != null;
}

const platzSchwierigkeiten = {'leicht', 'mittel', 'schwer'};

class Level {
  Level({
    required this.id,
    required this.titel,
    required this.lernwelt,
    required this.themenbereich,
    required this.kapitel,
    required this.reihenfolge,
    required this.typ,
    required this.fix,
    required this.lernziel,
    required this.kompetenzen,
    required this.voraussetzungen,
    required this.plaetze,
    this.vertiefung = const [],
    this.erklaerung = '',
    required this.wiederholungAus,
    required this.kreuzungMit,
  });

  final String id;
  final String titel;
  final int lernwelt;
  final String themenbereich;
  final Kapitel kapitel;
  final int reihenfolge;
  final String typ;
  final bool fix;
  final String lernziel;
  final List<String> kompetenzen;
  final List<String> voraussetzungen;

  /// Aufgabenpaket als Plätze in aufsteigender Reihenfolge.
  final List<Platz> plaetze;

  /// Aufgaben-IDs für "Kapitel vertiefen" (nicht Teil des Level-Durchgangs).
  final List<String> vertiefung;

  /// Erklärung von Thema und Methode, vor den Aufgaben fixer Levels gezeigt.
  final String erklaerung;
  final List<String> wiederholungAus;
  final List<String> kreuzungMit;

  bool get istKreuzung => typ == 'kreuzung';
  bool get istWiederholung => typ == 'wiederholung';
  bool get istSchularbeit => typ == 'schularbeit';

  /// Paket wird beim Öffnen zusammengestellt (Wiederholungs-Level, Schularbeit).
  bool get istDynamisch => istWiederholung || istSchularbeit;

  /// Schlüssel des Lernpfads, z. B. `5|AG`.
  String get lernpfad => '$lernwelt|$themenbereich';

  /// Schlüssel des Kapitels für den Growth-Points-Pool, z. B. `5|AG|1`.
  String get kapitelKey => '$lernpfad|${kapitel.nummer}';
}

class Hilfe {
  const Hilfe({required this.stufe, required this.text, this.nachSekunden, this.nachFehlversuchen});
  final int stufe;
  final String text;
  final int? nachSekunden;
  final int? nachFehlversuchen;
}

/// Ein einzeln bewertbares Item. [aufgabe] verweist auf die Aufgabe mit
/// Stamm, Medien und Tags der Aufgabe.
class Item {
  Item({
    required this.id,
    required this.aufgabenstellung,
    required this.kompetenz,
    required this.kompetenzSekundaer,
    required this.format,
    required this.antwort,
    required this.punkteschema,
    required this.fehlerbilder,
    required this.hilfen,
    required this.loesungsweg,
    required this.schwierigkeitStart,
    required this.erwarteteSekunden,
    required this.abhaengigVon,
  });

  final String id;
  final String aufgabenstellung;
  final String kompetenz;
  final List<String> kompetenzSekundaer;
  final String format;
  final Map<String, dynamic> antwort;
  final String punkteschema;
  final Map<String, String> fehlerbilder;
  final List<Hilfe> hilfen;
  final List<String> loesungsweg;
  final int schwierigkeitStart;
  final int erwarteteSekunden;
  final String? abhaengigVon;
  late final Aufgabe aufgabe;

  bool get automatischGeprueft => automatischGepruefteFormate.contains(format);
}

class Aufgabe {
  Aufgabe({
    required this.id,
    required this.titel,
    required this.levels,
    required this.kontext,
    required this.stamm,
    required this.medien,
    required this.technologie,
    required this.zusammenstellung,
    required this.variantengruppe,
    required this.status,
    required this.unterwegs,
    required this.items,
    this.parameter = const [],
    this.lernpfadGeeignet = true,
    this.verwendung,
    this.schulstufe,
  }) {
    for (final i in items) {
      i.aufgabe = this;
    }
  }

  final String id;
  final String titel;
  final List<String> levels;
  final String kontext;
  final String stamm;
  final List<Map<String, dynamic>> medien;
  final String technologie;
  final String zusammenstellung;
  final String variantengruppe;
  final String status;
  final bool unterwegs;
  final List<Item> items;

  /// Zufallswerte parametrisierter Aufgaben (leer = feste Aufgabe).
  final List<Parameter> parameter;

  /// Darf im Lernpfad vorkommen (Standard: Einzelaufgaben ja, Kontextaufgaben
  /// nur nach Freigabe durch das Didaktik-Team).
  final bool lernpfadGeeignet;

  /// Sonderverwendung, z. B. `mini_matura` (Manuels Finale- und Boss-Aufgaben);
  /// `null` = normale Aufgabe.
  final String? verwendung;

  /// Schulstufe 9-13, ab der die Aufgabe passt (`null` = aus dem Level).
  final int? schulstufe;
}

/// Geladener, geprüfter Inhalt mit Nachschlage-Tabellen.
class EngineContent {
  EngineContent({required this.lernwelten, required this.levels, required this.aufgaben, this.fehler = const []}) {
    for (final l in levels) {
      levelById[l.id] = l;
      lernpfade.putIfAbsent(l.lernpfad, () => []).add(l);
    }
    for (final p in lernpfade.values) {
      p.sort((a, b) => a.reihenfolge.compareTo(b.reihenfolge));
    }
    for (final a in aufgaben) {
      aufgabeById[a.id] = a;
      for (final i in a.items) {
        itemById[i.id] = i;
        itemsByKompetenz.putIfAbsent(i.kompetenz, () => []).add(i);
      }
    }
    for (final l in levels) {
      for (final k in l.kompetenzen) {
        levelsByKompetenz.putIfAbsent(k, () => []).add(l);
        for (final v in l.voraussetzungen) {
          final vl = levelById[v];
          if (vl == null) continue;
          for (final vk in vl.kompetenzen) {
            if (vk != k) {
              (voraussetzungen[k] ??= {}).add(vk);
              (abhaengige[vk] ??= {}).add(k);
            }
          }
        }
      }
    }
  }

  final List<Lernwelt> lernwelten;
  final List<Level> levels;
  final List<Aufgabe> aufgaben;

  /// Meldungen der Schema-Prüfung (leer = alles in Ordnung).
  final List<String> fehler;

  final levelById = <String, Level>{};
  final lernpfade = <String, List<Level>>{};
  final aufgabeById = <String, Aufgabe>{};
  final itemById = <String, Item>{};
  final itemsByKompetenz = <String, List<Item>>{};
  final levelsByKompetenz = <String, List<Level>>{};

  /// Kompetenz → Kompetenzen, die sie voraussetzt (aus den Level-Voraussetzungen).
  final voraussetzungen = <String, Set<String>>{};

  /// Kompetenz → Kompetenzen, die auf ihr aufbauen.
  final abhaengige = <String, Set<String>>{};

  List<Level> lernpfad(int lernwelt, String themenbereich) => lernpfade['$lernwelt|$themenbereich'] ?? const [];

  /// Items eines Levels in Paket-Reihenfolge, nur live.
  /// Passende Items für einen Platz: die feste Aufgabe oder alle live-Items
  /// der Kompetenz (mit Format und Schwierigkeit), die zur Lernwelt passen
  /// und für den Lernpfad freigegeben sind.
  List<Item> kandidaten(Level level, Platz p) {
    if (p.fest) {
      final a = aufgabeById[p.aufgabeId];
      return a == null || a.status != 'live' ? const [] : a.items;
    }
    bool schwierigkeitPasst(Item i) => switch (p.schwierigkeit) {
      'leicht' => i.schwierigkeitStart <= 2,
      'mittel' => i.schwierigkeitStart == 3,
      'schwer' => i.schwierigkeitStart >= 4,
      _ => true,
    };
    bool lernweltPasst(Aufgabe a) =>
        a.levels.isEmpty || a.levels.any((id) => (levelById[id]?.lernwelt ?? 99) <= level.lernwelt);
    return [
      for (final i in itemsByKompetenz[p.kompetenz] ?? const <Item>[])
        if (i.aufgabe.status == 'live' &&
            (p.format == null || i.format == p.format) &&
            schwierigkeitPasst(i) &&
            i.aufgabe.lernpfadGeeignet &&
            lernweltPasst(i.aufgabe))
          i,
    ];
  }

  /// Alle Items, die in einem Level vorkommen können (alle Plätze).
  List<Item> levelItems(Level level) => {for (final p in level.plaetze) ...kandidaten(level, p)}.toList();

  bool hatInhalt(Level level) => level.istDynamisch
      ? level.wiederholungAus.any((id) => levelById[id] != null && hatInhalt(levelById[id]!))
      : level.plaetze.any((p) => kandidaten(level, p).isNotEmpty);

  /// Hinweise für das Didaktik-Team: Vorgabe-Plätze mit zu kleinem Bestand
  /// (Wiederholungen würden sonst schnell dieselben Aufgaben zeigen).
  List<String> get hinweise => [
    for (final l in levels)
      for (final p in l.plaetze)
        if (!p.fest)
          if (kandidaten(l, p).map((i) => i.aufgabe).toSet().length case final n when n < 3)
            '${l.id} Platz ${p.nummer}: nur $n passende Aufgabe${n == 1 ? '' : 'n'} '
                '(${p.kompetenz}${p.format == null ? '' : ', ${p.format}'})',
  ];
}

/// Lädt und prüft Levels und Aufgaben.
class ContentLoader {
  final _fehler = <String>[];

  EngineContent load({required String levelsJson, required List<String> aufgabenJsons}) {
    _fehler.clear();
    final levelsData = jsonDecode(levelsJson) as Map<String, dynamic>;
    final lernwelten = [
      for (final w in levelsData['lernwelten'] as List) Lernwelt(klasse: w['klasse'] as int, name: w['name'] as String),
    ];
    final aufgaben = <Aufgabe>[];
    final ids = <String>{};
    final itemIds = <String>{};
    for (final json in aufgabenJsons) {
      for (final raw in (jsonDecode(json) as Map<String, dynamic>)['aufgaben'] as List) {
        final a = _aufgabe(raw as Map<String, dynamic>, ids, itemIds);
        if (a != null) aufgaben.add(a);
      }
    }
    final levels = <Level>[];
    final levelIds = <String>{};
    for (final raw in levelsData['levels'] as List) {
      final l = _level(raw as Map<String, dynamic>, levelIds, ids);
      if (l != null) levels.add(l);
    }
    for (final l in levels) {
      for (final v in [...l.voraussetzungen, ...l.wiederholungAus]) {
        if (!levelIds.contains(v)) _fehler.add('${l.id}: Voraussetzung $v existiert nicht');
      }
    }
    for (final a in aufgaben) {
      for (final i in a.items) {
        if (i.abhaengigVon != null && !itemIds.contains(i.abhaengigVon)) {
          _fehler.add('${i.id}: abhaengig_von ${i.abhaengigVon} existiert nicht');
        }
      }
    }
    return EngineContent(lernwelten: lernwelten, levels: levels, aufgaben: aufgaben, fehler: List.of(_fehler));
  }

  T? _pflicht<T>(Map<String, dynamic> m, String key, String wo) {
    final v = m[key];
    if (v is T) return v;
    _fehler.add('$wo: Pflichtfeld "$key" fehlt oder hat den falschen Typ');
    return null;
  }

  Level? _level(Map<String, dynamic> m, Set<String> levelIds, Set<String> aufgabenIds) {
    final id = _pflicht<String>(m, 'level_id', 'Level');
    if (id == null) return null;
    if (!levelIds.add(id)) {
      _fehler.add('$id: level_id doppelt');
      return null;
    }
    final typ = (m['level_typ'] as String?) ?? 'uebung';
    if (!levelTypen.contains(typ)) _fehler.add('$id: unbekannter level_typ "$typ"');
    final plaetze = <Platz>[];
    final vertiefung = <String>[];
    for (final e in (m['aufgabenpaket'] as List? ?? const [])) {
      final nummer = (e['platz'] as int?) ?? plaetze.length + 1;
      final aid = e['aufgabe'] as String?;
      if (aid != null) {
        if (!aufgabenIds.contains(aid)) {
          _fehler.add('$id: Aufgabe $aid im Aufgabenpaket existiert nicht');
          continue;
        }
        switch (e['rolle'] as String?) {
          case 'vertiefung':
            vertiefung.add(aid);
          case 'variante':
            // Älteres Format: Varianten sind Teil des Bestands, kein eigener Platz.
            break;
          default:
            plaetze.add(Platz(nummer: nummer, aufgabeId: aid));
        }
        continue;
      }
      final kompetenz = e['kompetenz'] as String?;
      final format = e['format'] as String?;
      final schwierigkeit = e['schwierigkeit'] as String?;
      if (kompetenz == null) {
        _fehler.add('$id: Platz $nummer braucht aufgabe oder kompetenz');
        continue;
      }
      if (format != null && format != 'beliebig' && !antwortformate.contains(format)) {
        _fehler.add('$id: Platz $nummer hat unbekanntes format "$format"');
        continue;
      }
      if (schwierigkeit != null && !platzSchwierigkeiten.contains(schwierigkeit)) {
        _fehler.add('$id: Platz $nummer hat unbekannte schwierigkeit "$schwierigkeit"');
      }
      plaetze.add(
        Platz(
          nummer: nummer,
          kompetenz: kompetenz,
          format: format == 'beliebig' ? null : format,
          schwierigkeit: platzSchwierigkeiten.contains(schwierigkeit) ? schwierigkeit : null,
        ),
      );
    }
    plaetze.sort((a, b) => a.nummer.compareTo(b.nummer));
    final kap = m['kapitel'] as Map<String, dynamic>? ?? const {'nummer': 0, 'titel': ''};
    final titel = _pflicht<String>(m, 'titel', id);
    final tb = _pflicht<String>(m, 'themenbereich', id);
    final reihenfolge = _pflicht<int>(m, 'reihenfolge', id);
    if (titel == null || tb == null || reihenfolge == null) return null;
    return Level(
      id: id,
      titel: titel,
      lernwelt: (m['lernwelt'] as int?) ?? ((m['schulstufe'] as int) - 4),
      themenbereich: tb,
      kapitel: Kapitel(nummer: kap['nummer'] as int, titel: kap['titel'] as String),
      reihenfolge: reihenfolge,
      typ: typ,
      fix: m['fix'] == 'ja' || m['fix'] == true,
      lernziel: (m['lernziel'] as String?) ?? '',
      kompetenzen: [...?(m['kompetenzen'] as List?)?.cast<String>()],
      voraussetzungen: [...?(m['voraussetzungen'] as List?)?.cast<String>()],
      plaetze: plaetze,
      vertiefung: vertiefung,
      erklaerung: (m['erklaerung'] as String?) ?? '',
      wiederholungAus: [...?(m['wiederholung_aus'] as List?)?.cast<String>()],
      kreuzungMit: [...?(m['kreuzung_mit'] as List?)?.cast<String>()],
    );
  }

  Aufgabe? _aufgabe(Map<String, dynamic> m, Set<String> ids, Set<String> itemIds) {
    final id = _pflicht<String>(m, 'id', 'Aufgabe');
    if (id == null) return null;
    if (!ids.add(id)) {
      _fehler.add('$id: Aufgaben-id doppelt');
      return null;
    }
    final status = (m['status'] as String?) ?? '';
    if (!{'entwurf', 'geprueft', 'live', 'zurueckgezogen'}.contains(status)) _fehler.add('$id: ungültiger status "$status"');
    final rawItems = [
      ...?(m['items'] as List?),
      for (final t in (m['teilaufgaben'] as List? ?? const [])) ...?(t['items'] as List?),
    ];
    if (rawItems.isEmpty) {
      _fehler.add('$id: keine Items');
      return null;
    }
    final items = <Item>[];
    for (final raw in rawItems) {
      final it = _item(raw as Map<String, dynamic>, id, itemIds);
      if (it == null) return null;
      items.add(it);
    }
    final parameter = <Parameter>[];
    if (m['parametrisierbar'] == 'ja' || m['parametrisierbar'] == true) {
      for (final p in (m['parameter'] as List? ?? const [])) {
        final name = p['name'];
        if (name is! String || eingabeFeldNamen.contains(name) || p['min'] is! num || p['max'] is! num) {
          _fehler.add('$id: Parameter ungültig ($name)');
          return null;
        }
        parameter.add(
          Parameter(name: name, min: p['min'] as num, max: p['max'] as num, schritt: (p['schritt'] as num?) ?? 1),
        );
      }
    }
    final probe = {for (final p in parameter) p.name: p.min};
    for (final it in items) {
      if (it.antwort['formel'] != null && loesungsWert(it, probe) is! num) {
        _fehler.add('${it.id}: formel lässt sich mit den Parametern nicht berechnen');
        return null;
      }
    }
    final technologie = (m['technologie'] as String?) ?? 'ohne';
    final zusammenstellung = (m['zusammenstellung'] as String?) ?? 'einzel';
    final unterwegsFeld = m['unterwegs'];
    return Aufgabe(
      id: id,
      titel: (m['titel'] as String?) ?? id,
      levels: [...?(m['level'] as List?)?.cast<String>()],
      kontext: (m['kontext'] as String?) ?? 'innermathematisch',
      stamm: (m['stamm'] as String?) ?? '',
      medien: [...?(m['medien'] as List?)?.cast<Map<String, dynamic>>()],
      technologie: technologie,
      zusammenstellung: zusammenstellung,
      variantengruppe: (m['variantengruppe'] as String?) ?? id,
      status: status,
      unterwegs: unterwegsFeld == null
          ? leiteUnterwegsAb(zusammenstellung, (m['teilaufgaben'] as List?)?.isNotEmpty ?? false, technologie, items)
          : unterwegsFeld == 'ja' || unterwegsFeld == true,
      items: items,
      parameter: parameter,
      verwendung: m['verwendung'] as String?,
      schulstufe: m['schulstufe'] as int?,
      lernpfadGeeignet: switch (m['lernpfad_geeignet']) {
        'ja' || true => true,
        'nein' || false => false,
        _ => zusammenstellung == 'einzel',
      },
    );
  }

  Item? _item(Map<String, dynamic> m, String aufgabeId, Set<String> itemIds) {
    final id = _pflicht<String>(m, 'item_id', aufgabeId);
    if (id == null) return null;
    if (!itemIds.add(id)) {
      _fehler.add('$id: item_id doppelt');
      return null;
    }
    final format = _pflicht<String>(m, 'antwortformat', id);
    final kompetenz = _pflicht<String>(m, 'kompetenz', id);
    final antwort = _pflicht<Map<String, dynamic>>(m, 'antwort', id);
    if (format == null || kompetenz == null || antwort == null) return null;
    if (!antwortformate.contains(format)) {
      _fehler.add('$id: unbekanntes antwortformat "$format"');
      return null;
    }
    final strukturFehler = pruefeAntwort(format, antwort);
    if (strukturFehler != null) {
      _fehler.add('$id: $strukturFehler');
      return null;
    }
    if ((m['hilfen'] as List? ?? const []).length < 3) _fehler.add('$id: braucht drei Hilfen');
    final schwierigkeit = (m['schwierigkeit_start'] as int?) ?? 3;
    if (schwierigkeit < 1 || schwierigkeit > 5) _fehler.add('$id: schwierigkeit_start außerhalb 1-5');
    return Item(
      id: id,
      aufgabenstellung: (m['aufgabenstellung'] as String?) ?? '',
      kompetenz: kompetenz,
      kompetenzSekundaer: [...?(m['kompetenz_sekundaer'] as List?)?.cast<String>()],
      format: format,
      antwort: antwort,
      punkteschema: (m['punkteschema'] as String?) ?? '0/1',
      fehlerbilder: {for (final e in ((m['fehlerbilder'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      hilfen: [
        for (final h in (m['hilfen'] as List? ?? const []))
          Hilfe(
            stufe: h['stufe'] as int,
            text: h['text'] as String,
            nachSekunden: (h['freigabe'] as Map?)?['nach_sekunden'] as int?,
            nachFehlversuchen: (h['freigabe'] as Map?)?['nach_fehlversuchen'] as int?,
          ),
      ]..sort((a, b) => a.stufe.compareTo(b.stufe)),
      loesungsweg: [...?(m['loesungsweg'] as List?)?.cast<String>()],
      schwierigkeitStart: schwierigkeit.clamp(1, 5),
      erwarteteSekunden: (m['erwartete_sekunden'] as int?) ?? 60,
      abhaengigVon: m['abhaengig_von'] as String?,
    );
  }
}

/// Prüft den Aufbau von `antwort` je Format; `null` = in Ordnung.
String? pruefeAntwort(String format, Map<String, dynamic> a) {
  switch (format) {
    case 'mc_1aus5' || 'mc_1aus6':
      final n = format == 'mc_1aus5' ? 5 : 6;
      final o = a['optionen'];
      final r = a['richtig'];
      if (o is! List || o.length != n) return '$format braucht $n Optionen';
      if (r is! int || r < 0 || r >= n) return '$format: richtig ist kein gültiger Index';
    case 'mc_2aus5':
      final o = a['optionen'];
      final r = a['richtig'];
      if (o is! List || o.length != 5) return 'mc_2aus5 braucht 5 Optionen';
      if (r is! List || r.length != 2 || r.any((x) => x is! int || x < 0 || x > 4)) {
        return 'mc_2aus5: richtig braucht 2 Indizes';
      }
    case 'lueckentext':
      if (a['luecke_1'] is! List ||
          a['luecke_2'] is! List ||
          a['richtig'] is! List ||
          (a['richtig'] as List).length != 2) {
        return 'lueckentext unvollständig';
      }
    case 'zuordnung':
      if (a['elemente'] is! List || a['optionen'] is! List || a['richtig'] is! Map) return 'zuordnung unvollständig';
    case 'offen_zahl' || 'halboffen':
      final wert = a['wert'];
      final istTerm = a['art'] == 'term';
      final felder = format == 'halboffen'
          ? (a['vorlage'] is String ? eingabeFelder(a['vorlage'] as String).length : -1)
          : 1;
      if (felder < 1) return 'halboffen braucht eine vorlage mit {x}';
      if (istTerm) {
        final loesung = a['term'] ?? wert;
        if (loesung is! String || Term.parseAntwort(loesung) == null) return '$format: term fehlt oder ist unlesbar';
        if (felder != 1) return '$format: ein Term braucht genau ein Feld';
        return null;
      }
      final regeln = a['pruefregel'];
      if (regeln != null) {
        if (regeln is! List || regeln.isEmpty) return '$format: pruefregel muss eine Liste sein';
        for (final r in regeln) {
          if (r is! Map || !pruefregeln.contains(r['regel'])) return '$format: unbekannte pruefregel';
          if ((r['regel'] == 'orthogonal_zu' || r['regel'] == 'parallel_zu') &&
              (r['vektor'] is! List || (r['vektor'] as List).length != felder)) {
            return '$format: vektor passt nicht zu den Feldern';
          }
          if (r['regel'] == 'laenge' && r['wert'] is! num) return '$format: laenge braucht wert';
          if (r['regel'] == 'erfuellt_gleichung' &&
              (r['gleichung'] is! String || parseGleichung(r['gleichung'] as String) == null)) {
            return '$format: gleichung ist unlesbar';
          }
        }
        return null;
      }
      if (a['formel'] is String) return felder == 1 ? null : '$format: formel nur mit einem Feld';
      if (wert is num) return felder == 1 ? null : '$format: wert braucht $felder Zahlen';
      if (wert is List && wert.every((w) => w is num)) {
        return wert.length == felder ? null : '$format: ${wert.length} Werte für $felder Felder';
      }
      return '$format: wert, formel oder pruefregel fehlt';
    case 'offen_term':
      final term = a['term'];
      if (term is! String || Term.parseAntwort(term) == null) return 'offen_term: term fehlt oder ist unlesbar';
    default:
      break;
  }
  return null;
}

/// Ableitungsregel "unterwegs lösbar" aus der Lern-Engine, falls das Feld
/// im JSON fehlt (das Didaktik-Team kann es überschreiben). Abhängige Items
/// sind erlaubt; ob ihre Vorgänger freigeschaltet sind, prüft die Auswahl.
bool leiteUnterwegsAb(String zusammenstellung, bool hatTeilaufgaben, String technologie, List<Item> items) {
  const formate = {
    'mc_1aus5',
    'mc_1aus6',
    'mc_2aus5',
    'lueckentext',
    'zuordnung',
    'halboffen',
    'offen_zahl',
    'konstruktion',
  };
  return zusammenstellung == 'einzel' &&
      !hatTeilaufgaben &&
      (technologie == 'ohne' || technologie == 'taschenrechner') &&
      items.every((i) => formate.contains(i.format));
}
