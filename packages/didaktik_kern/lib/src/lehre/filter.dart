/// Filter des Aufgaben-Stores. Wie bei bekannten Such-Portalen: Mehrfachauswahl
/// pro Gruppe (oder), Gruppen untereinander verknüpft (und), Trefferzahl pro
/// Wert unter Berücksichtigung aller anderen Gruppen.
library;

import 'package:didaktik_kern/src/lehre/store.dart';

/// Eine Filtergruppe mit festen oder aus den Daten gesammelten Werten.
class Facette {
  const Facette(this.schluessel, this.titel, this._werte, {this.namen = const {}, this.suche = false});

  final String schluessel;
  final String titel;
  final Iterable<String> Function(StoreAufgabe a) _werte;

  /// Anzeigenamen; fehlt ein Wert, wird er selbst gezeigt.
  final Map<String, String> namen;

  /// Lange Listen bekommen ein Suchfeld statt aller Häkchen.
  final bool suche;

  Iterable<String> werte(StoreAufgabe a) => _werte(a);
  String name(String wert) => namen[wert] ?? wert;
}

final facetten = <Facette>[
  Facette(
    'klasse',
    'Klasse',
    (a) => [if (a.klasse != null) '${a.klasse}'],
    namen: {
      for (final k in [5, 6, 7, 8]) '$k': '$k. Klasse',
    },
  ),
  Facette('themenbereich', 'Themenbereich', (a) => a.themenbereiche, namen: themenbereichNamen),
  Facette('format', 'Aufgabentyp', (a) => a.formatGruppenSet, namen: formatGruppen),
  Facette('kompetenz', 'Kompetenz', (a) => a.kompetenzen, suche: true),
  Facette('level', 'Lernziel (Level)', (a) => a.levels, suche: true),
  Facette('grundkompetenz', 'Grundkompetenz', (a) => a.grundkompetenzen, suche: true),
  Facette('handlungsbereich', 'Handlungsbereich', (a) => a.handlungsbereiche, namen: handlungsbereichNamen),
  Facette('kontext', 'Kontext', (a) => [?a.kontext], namen: kontextNamen),
  Facette('technologie', 'Technologie', (a) => [?a.technologie], namen: technologieNamen),
  Facette('zusammenstellung', 'Aufbau', (a) => [?a.zusammenstellung], namen: zusammenstellungNamen),
  Facette('matura_niveau', 'Niveau', (a) => [?a.maturaNiveau], namen: maturaNiveauNamen),
];

Facette facette(String schluessel) => facetten.firstWhere((f) => f.schluessel == schluessel);

enum Sortierung {
  passend('Reihenfolge im Lernplan'),
  leichteZuerst('Leichte zuerst'),
  schwereZuerst('Schwere zuerst'),
  kurzeZuerst('Kurze zuerst'),
  titel('Titel A-Z');

  const Sortierung(this.bezeichnung);
  final String bezeichnung;
}

class StoreFilter {
  StoreFilter({
    this.text = '',
    Map<String, Set<String>>? auswahl,
    this.schwierigkeitVon = 1,
    this.schwierigkeitBis = 5,
    this.maxMinuten,
    this.nurMitVarianten = false,
    this.nurMitGrafik = false,
    this.sortierung = Sortierung.passend,
  }) : auswahl = auswahl ?? {};

  factory StoreFilter.fromJson(Map<String, dynamic> j) => StoreFilter(
    text: j['text'] as String? ?? '',
    auswahl: {
      for (final e in ((j['auswahl'] as Map?) ?? const {}).entries)
        if (e.value is List && (e.value as List).isNotEmpty) '${e.key}': {...(e.value as List).map((v) => '$v')},
    },
    schwierigkeitVon: j['schwierigkeit_von'] as int? ?? 1,
    schwierigkeitBis: j['schwierigkeit_bis'] as int? ?? 5,
    maxMinuten: j['max_minuten'] as int?,
    nurMitVarianten: j['nur_mit_varianten'] == true,
    nurMitGrafik: j['nur_mit_grafik'] == true,
    sortierung: Sortierung.values.asNameMap()[j['sortierung']] ?? Sortierung.passend,
  );

  String text;
  final Map<String, Set<String>> auswahl;
  int schwierigkeitVon;
  int schwierigkeitBis;

  /// Höchstdauer einer Aufgabe in Minuten; `null` = egal.
  int? maxMinuten;
  bool nurMitVarianten;
  bool nurMitGrafik;
  Sortierung sortierung;

  StoreFilter kopie() => StoreFilter.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'text': text,
    'auswahl': {
      for (final e in auswahl.entries)
        if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
    },
    'schwierigkeit_von': schwierigkeitVon,
    'schwierigkeit_bis': schwierigkeitBis,
    'max_minuten': maxMinuten,
    'nur_mit_varianten': nurMitVarianten,
    'nur_mit_grafik': nurMitGrafik,
    'sortierung': sortierung.name,
  };

  bool get istLeer =>
      text.trim().isEmpty &&
      auswahl.values.every((s) => s.isEmpty) &&
      schwierigkeitVon <= 1 &&
      schwierigkeitBis >= 5 &&
      maxMinuten == null &&
      !nurMitVarianten &&
      !nurMitGrafik;

  /// Anzahl gesetzter Einschränkungen, für "Filter (3)".
  int get anzahl =>
      auswahl.values.fold(0, (n, s) => n + s.length) +
      (text.trim().isEmpty ? 0 : 1) +
      (schwierigkeitVon > 1 || schwierigkeitBis < 5 ? 1 : 0) +
      (maxMinuten == null ? 0 : 1) +
      (nurMitVarianten ? 1 : 0) +
      (nurMitGrafik ? 1 : 0);

  void umschalten(String facette, String wert) {
    final s = auswahl.putIfAbsent(facette, () => {});
    if (!s.remove(wert)) s.add(wert);
    if (s.isEmpty) auswahl.remove(facette);
  }

  void zuruecksetzen() {
    text = '';
    auswahl.clear();
    schwierigkeitVon = 1;
    schwierigkeitBis = 5;
    maxMinuten = null;
    nurMitVarianten = false;
    nurMitGrafik = false;
  }

  /// [ohne] lässt eine Facette weg (für die Trefferzahlen dieser Facette).
  /// [varianten] zählt Aufgaben pro Variantengruppe (siehe `variantenZahlen`).
  bool passt(StoreAufgabe a, {String? ohne, Map<String, int> varianten = const {}}) {
    for (final e in auswahl.entries) {
      if (e.key == ohne || e.value.isEmpty) continue;
      if (!facette(e.key).werte(a).any(e.value.contains)) return false;
    }
    final s = a.schwierigkeitGerundet;
    if ((schwierigkeitVon > 1 || schwierigkeitBis < 5) && (s == null || s < schwierigkeitVon || s > schwierigkeitBis)) {
      return false;
    }
    if (maxMinuten != null && a.minuten > maxMinuten!) return false;
    if (nurMitGrafik && !a.hatMedien) return false;
    if (nurMitVarianten && !hatVarianten(a, varianten)) return false;
    final woerter = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (woerter.isNotEmpty) {
      final heu = [
        a.id,
        a.titel,
        a.vorschauText,
        ...a.kompetenzen,
        ...a.levels,
        ...a.grundkompetenzen,
      ].join(' ').toLowerCase();
      if (!woerter.every(heu.contains)) return false;
    }
    return true;
  }

  List<StoreAufgabe> treffer(List<StoreAufgabe> alle, {Map<String, int>? varianten}) {
    final v = varianten ?? variantenZahlen(alle);
    final t = [
      for (final a in alle)
        if (passt(a, varianten: v)) a,
    ];
    int schwer(StoreAufgabe a) => a.schwierigkeitGerundet ?? 3;
    switch (sortierung) {
      case Sortierung.passend:
        t.sort((a, b) {
          final la = a.levels.isEmpty ? '~' : a.levels.first;
          final lb = b.levels.isEmpty ? '~' : b.levels.first;
          final c = la.compareTo(lb);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      case Sortierung.leichteZuerst:
        t.sort((a, b) => schwer(a).compareTo(schwer(b)));
      case Sortierung.schwereZuerst:
        t.sort((a, b) => schwer(b).compareTo(schwer(a)));
      case Sortierung.kurzeZuerst:
        t.sort((a, b) => a.sekunden.compareTo(b.sekunden));
      case Sortierung.titel:
        t.sort((a, b) => a.titel.toLowerCase().compareTo(b.titel.toLowerCase()));
    }
    return t;
  }

  /// Trefferzahl pro Wert der Facette, wenn man diesen Wert dazunimmt.
  Map<String, int> zaehle(Facette f, List<StoreAufgabe> alle, {Map<String, int>? varianten}) {
    final v = varianten ?? variantenZahlen(alle);
    final z = <String, int>{};
    for (final a in alle) {
      if (!passt(a, ohne: f.schluessel, varianten: v)) continue;
      for (final w in f.werte(a)) {
        z[w] = (z[w] ?? 0) + 1;
      }
    }
    return z;
  }
}

/// Eine Aufgabe hat Varianten, wenn sie parametrisiert ist oder ihre Gruppe
/// mehr als eine Aufgabe enthält.
bool hatVarianten(StoreAufgabe a, Map<String, int> varianten) =>
    a.parametrisierbar || (a.variantengruppe != null && (varianten[a.variantengruppe] ?? 0) > 1);
