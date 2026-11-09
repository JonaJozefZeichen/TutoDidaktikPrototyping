/// Was Lehrpersonen speichern: Merkliste mit Ordnern, gespeicherte Suchen und
/// Pakete. Getrennt vom Aufgabenbestand, eine Ablage pro Person.
library;

import 'package:didaktik_kern/src/lehre/filter.dart';
import 'package:didaktik_kern/src/lehre/paket.dart';
import 'package:didaktik_kern/src/modelle.dart';

const standardOrdner = 'gemerkt';

class MerkOrdner {
  MerkOrdner({required this.id, required this.name, List<String>? aufgaben}) : aufgaben = aufgaben ?? [];

  factory MerkOrdner.fromJson(Map<String, dynamic> j) => MerkOrdner(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Ordner',
    aufgaben: [...((j['aufgaben'] as List?) ?? const []).whereType<String>()],
  );

  final String id;
  String name;
  final List<String> aufgaben;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'aufgaben': aufgaben};
}

class GespeicherteSuche {
  GespeicherteSuche({required this.id, required this.name, required this.filter});

  factory GespeicherteSuche.fromJson(Map<String, dynamic> j) => GespeicherteSuche(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Suche',
    filter: StoreFilter.fromJson((j['filter'] as Map?)?.cast<String, dynamic>() ?? const {}),
  );

  final String id;
  String name;
  final StoreFilter filter;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'filter': filter.toJson()};
}

/// Die Ablage einer Lehrperson. [version] steigt bei jedem Speichern; wer mit
/// einer älteren Version speichert, bekommt einen Konflikt statt die
/// Änderungen eines anderen Fensters zu überschreiben.
class LehrDaten {
  LehrDaten({this.version = 0, List<MerkOrdner>? ordner, List<GespeicherteSuche>? suchen, List<Paket>? pakete})
    : ordner = ordner ?? [MerkOrdner(id: standardOrdner, name: 'Gemerkt')],
      suchen = suchen ?? [],
      pakete = pakete ?? [] {
    if (!this.ordner.any((o) => o.id == standardOrdner)) {
      this.ordner.insert(0, MerkOrdner(id: standardOrdner, name: 'Gemerkt'));
    }
  }

  factory LehrDaten.fromJson(Map<String, dynamic> j) => LehrDaten(
    version: j['version'] as int? ?? 0,
    ordner: [for (final o in (j['ordner'] as List?) ?? const []) MerkOrdner.fromJson(o as Map<String, dynamic>)],
    suchen: [for (final s in (j['suchen'] as List?) ?? const []) GespeicherteSuche.fromJson(s as Map<String, dynamic>)],
    pakete: [for (final p in (j['pakete'] as List?) ?? const []) Paket.fromJson(p as Map<String, dynamic>)],
  );

  int version;
  final List<MerkOrdner> ordner;
  final List<GespeicherteSuche> suchen;
  final List<Paket> pakete;

  /// Alle gemerkten Aufgaben, egal in welchem Ordner.
  Set<String> get gemerkt => {for (final o in ordner) ...o.aufgaben};

  MerkOrdner? ordnerMit(String id) {
    for (final o in ordner) {
      if (o.id == id) return o;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'ordner': [for (final o in ordner) o.toJson()],
    'suchen': [for (final s in suchen) s.toJson()],
    'pakete': [for (final p in pakete) p.toJson()],
  };
}

/// Alle Ablagen, nach Person.
class Lehrbereich {
  Lehrbereich({Map<String, LehrDaten>? daten}) : daten = daten ?? {};

  factory Lehrbereich.fromJson(Map<String, dynamic> j) => Lehrbereich(
    daten: {
      for (final e in ((j['personen'] as Map?) ?? const {}).entries)
        '${e.key}': LehrDaten.fromJson((e.value as Map).cast<String, dynamic>()),
    },
  );

  final Map<String, LehrDaten> daten;

  static void _pruefe(Person p) {
    if (!p.darfPaketeBauen) {
      throw const RegelFehler('keine_rechte', 'Dieser Bereich ist nur für Lehrpersonen', status: 403);
    }
  }

  LehrDaten lies(Person p) {
    _pruefe(p);
    return daten[p.id] ?? LehrDaten();
  }

  /// Ersetzt die Ablage von [p], wenn [neu] auf dem aktuellen Stand beruht.
  LehrDaten speichere(Person p, Map<String, dynamic> neu) {
    _pruefe(p);
    final alt = daten[p.id] ?? LehrDaten();
    final LehrDaten d;
    try {
      d = LehrDaten.fromJson(neu);
    } catch (e) {
      throw RegelFehler('format', 'Die Daten sind unvollständig: $e', status: 400);
    }
    if (d.version != alt.version) {
      throw const RegelFehler(
        'konflikt',
        'In einem anderen Fenster wurde inzwischen etwas geändert. Bitte die Seite neu laden.',
        status: 409,
      );
    }
    final ids = <String>{};
    for (final p in d.pakete) {
      if (!ids.add(p.id)) throw RegelFehler('format', 'Paket ${p.id} steht doppelt', status: 400);
      if (p.titel.trim().isEmpty) throw const RegelFehler('format', 'Ein Paket braucht einen Titel', status: 400);
    }
    d.version = alt.version + 1;
    daten[p.id] = d;
    return d;
  }

  Map<String, dynamic> toJson() => {
    'personen': {for (final e in daten.entries) e.key: e.value.toJson()},
  };
}
