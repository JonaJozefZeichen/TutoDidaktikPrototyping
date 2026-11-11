/// Die Testklasse jeder Lehrperson: drei Testkonten, mit denen sie in der
/// Schüler\*innen-Ansicht ausprobiert, wie Lernende Pakete bekommen und
/// lösen. Lernstand und Abgaben kommen aus diesen echten Versuchen; erfundene
/// Daten gibt es nicht mehr.
library;

import 'package:didaktik_kern/src/lehre/paket.dart';

/// iKM-Skala (Lern-Engine, "Zustände und Stufen").
const ikmStufen = ['unter Stufe 1', 'Stufe 1', 'Stufe 2', 'Stufe 3'];
const ikmBedeutung = ['nicht erreicht', 'teilweise erreicht', 'erreicht', 'übertroffen'];

class TestSchuelerin {
  TestSchuelerin({required this.id, required this.name, Map<String, int>? stufen, this.aufgabenWoche = 0})
    : stufen = stufen ?? {};

  final String id;
  final String name;

  /// Kompetenz-Key → iKM-Stufe 0-3, nur Kompetenzen mit Antworten.
  final Map<String, int> stufen;
  final int aufgabenWoche;

  double get mittel => stufen.isEmpty ? 0 : stufen.values.reduce((a, b) => a + b) / stufen.length;

  /// Gesamteindruck für die Klassenliste; ohne Antworten "noch offen".
  String get gesamt =>
      stufen.isEmpty ? 'noch offen' : (mittel >= 1.9 ? 'sicher' : (mittel >= 1.2 ? 'teils sicher' : 'unsicher'));

  MapEntry<String, int>? get beste => _extrem((a, b) => a > b);
  MapEntry<String, int>? get schwaechste => _extrem((a, b) => a < b);

  MapEntry<String, int>? _extrem(bool Function(int, int) besser) {
    MapEntry<String, int>? x;
    for (final e in stufen.entries) {
      if (x == null || besser(e.value, x.value)) x = e;
    }
    return x;
  }
}

class TestKlasse {
  TestKlasse({required this.id, required this.name, required this.lernwelt, required this.schueler});

  final String id;
  final String name;
  final int lernwelt;
  final List<TestSchuelerin> schueler;
}

/// Namen der Testkonten; "du" ist die Lehrperson selbst.
const testKonten = {'du': 'Du (Testkonto)', 'b': 'Test-Konto B', 'c': 'Test-Konto C'};

/// Die Klasse von [personId], mit den Stufen und Aktivitäten aus [versuche].
/// Ohne weitere Angaben ist es die Testklasse mit den drei Testkonten.
TestKlasse testKlasse(
  String personId, {
  List<SchuelerVersuch> versuche = const [],
  Map<String, String> itemKompetenz = const {},
  DateTime? jetzt,
  String kuerzel = 'testklasse',
  String name = 'Testklasse',
  Map<String, String> konten = testKonten,
}) {
  final klasse = '$personId-$kuerzel';
  final seit = (jetzt ?? DateTime.now()).subtract(const Duration(days: 7));
  return TestKlasse(
    id: klasse,
    name: name,
    lernwelt: 5,
    schueler: [
      for (final e in konten.entries)
        () {
          final id = '$personId-${e.key}';
          final eigene = [
            for (final v in versuche)
              if (v.konto == id) v,
          ];
          return TestSchuelerin(
            id: id,
            name: e.value,
            stufen: kompetenzStufen(eigene, itemKompetenz),
            aufgabenWoche: {
              for (final v in eigene)
                if (v.am.isAfter(seit)) v.itemId,
            }.length,
          );
        }(),
    ],
  );
}

/// Eine Antwort eines Testkontos auf ein Item eines zugewiesenen Pakets.
class SchuelerVersuch {
  const SchuelerVersuch({
    required this.konto,
    required this.paket,
    required this.zuweisung,
    required this.aufgabe,
    required this.itemId,
    required this.antwort,
    required this.r,
    required this.hilfen,
    required this.sekunden,
    required this.am,
    this.fehlerbild,
    this.selbstBewertet = false,
  });

  factory SchuelerVersuch.fromJson(Map<String, dynamic> j) => SchuelerVersuch(
    konto: j['konto'] as String,
    paket: j['paket'] as String,
    zuweisung: j['zuweisung'] as String,
    aufgabe: j['aufgabe'] as String,
    itemId: j['item'] as String,
    antwort: j['antwort'] as String? ?? '',
    r: (j['r'] as num? ?? 0).toDouble(),
    hilfen: j['hilfen'] as int? ?? 0,
    sekunden: j['sekunden'] as int? ?? 0,
    am: DateTime.parse(j['am'] as String),
    fehlerbild: j['fehlerbild'] as String?,
    selbstBewertet: j['selbst'] == true,
  );

  final String konto;
  final String paket;
  final String zuweisung;
  final String aufgabe;
  final String itemId;

  /// Die gegebene Antwort als Text; leer bei "Weiß ich nicht".
  final String antwort;

  /// Punktanteil 0-1 nach `AnswerChecker`.
  final double r;
  final String? fehlerbild;
  final int hilfen;
  final int sekunden;
  final DateTime am;
  final bool selbstBewertet;

  bool get richtig => r >= 1;

  Map<String, dynamic> toJson() => {
    'konto': konto,
    'paket': paket,
    'zuweisung': zuweisung,
    'aufgabe': aufgabe,
    'item': itemId,
    'antwort': antwort,
    'r': r,
    'hilfen': hilfen,
    'sekunden': sekunden,
    'am': am.toIso8601String(),
    'fehlerbild': fehlerbild,
    'selbst': selbstBewertet,
  };
}

/// Ein Testkonto hat ein zugewiesenes Paket abgegeben.
class Abgabe {
  const Abgabe({required this.konto, required this.zuweisung, required this.am});

  factory Abgabe.fromJson(Map<String, dynamic> j) =>
      Abgabe(konto: j['konto'] as String, zuweisung: j['zuweisung'] as String, am: DateTime.parse(j['am'] as String));

  final String konto;
  final String zuweisung;
  final DateTime am;

  Map<String, dynamic> toJson() => {'konto': konto, 'zuweisung': zuweisung, 'am': am.toIso8601String()};
}

/// Vereinfachte iKM-Stufe pro Kompetenz aus dem Anteil richtiger Antworten
/// (nur Teststand; die echte Stufe kommt aus der Lern-Engine).
Map<String, int> kompetenzStufen(List<SchuelerVersuch> versuche, Map<String, String> itemKompetenz) {
  final summe = <String, double>{};
  final zahl = <String, int>{};
  for (final v in versuche) {
    if (v.selbstBewertet) continue;
    final k = itemKompetenz[v.itemId];
    if (k == null) continue;
    summe[k] = (summe[k] ?? 0) + v.r;
    zahl[k] = (zahl[k] ?? 0) + 1;
  }
  return {
    for (final k in summe.keys)
      k: switch (summe[k]! / zahl[k]!) {
        >= 0.85 => 3,
        >= 0.6 => 2,
        >= 0.3 => 1,
        _ => 0,
      },
  };
}

/// Stand eines Kontos in einer Zuweisung: fertig (mit Datum, ggf. zu spät),
/// offen, oder nicht abgegeben nach dem Abgabedatum.
({bool fertig, DateTime? am, bool zuSpaet}) abgabeStand(
  String konto,
  Zuweisung z,
  List<Abgabe> abgaben,
  DateTime jetzt,
) {
  for (final a in abgaben) {
    if (a.konto == konto && a.zuweisung == z.id) {
      return (fertig: true, am: a.am, zuSpaet: z.abgabe != null && a.am.isAfter(z.abgabe!));
    }
  }
  return (fertig: false, am: null, zuSpaet: z.abgabe != null && jetzt.isAfter(z.abgabe!));
}
