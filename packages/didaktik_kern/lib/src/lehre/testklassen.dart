/// Erfundene Klassen und Lernstände für den Teststand. Es gibt noch keine
/// echten Schüler\*innen-Daten; die Werte entstehen reproduzierbar aus der
/// Person und den Kompetenzen des Lernplans und sind überall als Testdaten
/// gekennzeichnet.
library;

import 'dart:math';

/// iKM-Skala (Lern-Engine, "Zustände und Stufen").
const ikmStufen = ['unter Stufe 1', 'Stufe 1', 'Stufe 2', 'Stufe 3'];
const ikmBedeutung = ['nicht erreicht', 'teilweise erreicht', 'erreicht', 'übertroffen'];

const _vornamen = [
  'Alex', 'Ben', 'Clara', 'Deniz', 'Elif', 'Felix', 'Greta', 'Hannah', 'Ilias', 'Jana', 'Kim', 'Lea', //
  'Luca', 'Mara', 'Noah', 'Olivia', 'Paul', 'Rosa', 'Samuel', 'Tara', 'Uma', 'Valentin', 'Yara', 'Zoe',
];
const _nachnamen = 'ABCDEFGHKLMNPRSTWZ';

int streuwert(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

class TestSchuelerin {
  TestSchuelerin({required this.id, required this.name, required this.stufen, required this.aufgabenWoche});

  final String id;
  final String name;

  /// Kompetenz-Key → iKM-Stufe 0-3.
  final Map<String, int> stufen;
  final int aufgabenWoche;

  double get mittel => stufen.isEmpty ? 0 : stufen.values.reduce((a, b) => a + b) / stufen.length;

  /// Gesamteindruck für die Klassenliste.
  String get gesamt => mittel >= 1.9 ? 'sicher' : (mittel >= 1.2 ? 'teils sicher' : 'unsicher');

  MapEntry<String, int>? get beste => _extrem((a, b) => a > b);
  MapEntry<String, int>? get schwaechste => _extrem((a, b) => a < b);

  MapEntry<String, int>? _extrem(bool Function(int, int) besser) {
    MapEntry<String, int>? x;
    for (final e in stufen.entries) {
      if (x == null || besser(e.value, x.value)) x = e;
    }
    return x;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'stufen': stufen, 'aufgaben_woche': aufgabenWoche};
}

class TestKlasse {
  TestKlasse({required this.id, required this.name, required this.lernwelt, required this.schueler, required this.art});

  final String id;
  final String name;
  final int lernwelt;

  /// `schule` oder `nachhilfe`.
  final String art;
  final List<TestSchuelerin> schueler;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lernwelt': lernwelt,
    'art': art,
    'schueler': [for (final s in schueler) s.toJson()],
  };
}

/// Klassen für die Testperson [personId]. [kompetenzenProLernwelt] kommt aus
/// den Levels des Lernplans.
List<TestKlasse> testKlassen(String personId, Map<int, List<String>> kompetenzenProLernwelt) {
  final nachhilfe = personId.contains('nachhilfe');
  final vorlagen = nachhilfe
      ? [('Gruppe Montag', 5, 6), ('Gruppe Donnerstag', 6, 4), ('Einzelstunde Mara', 5, 1)]
      : [('5A', 5, 20), ('5C', 5, 16), ('6B', 6, 18)];
  return [
    for (final (name, lernwelt, zahl) in vorlagen)
      _klasse(
        personId,
        name,
        lernwelt,
        zahl,
        kompetenzenProLernwelt[lernwelt] ?? const [],
        nachhilfe ? 'nachhilfe' : 'schule',
      ),
  ];
}

TestKlasse _klasse(String personId, String name, int lernwelt, int zahl, List<String> kompetenzen, String art) {
  final id = '$personId-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
  final random = Random(streuwert(id));
  final namen = [..._vornamen]..shuffle(random);
  final liste = <TestSchuelerin>[];
  for (var i = 0; i < zahl; i++) {
    // Jede Person hat ein Grundniveau, einzelne Kompetenzen weichen davon ab.
    final niveau = random.nextDouble() * 2.6 + 0.2;
    final stufen = <String, int>{
      for (final k in kompetenzen) k: (niveau + (random.nextDouble() - 0.5) * 2.2).round().clamp(0, 3),
    };
    final vorname = zahl == 1 && name.startsWith('Einzelstunde') ? name.split(' ').last : namen[i % namen.length];
    liste.add(
      TestSchuelerin(
        id: '$id-$i',
        name: '$vorname ${_nachnamen[random.nextInt(_nachnamen.length)]}.',
        stufen: stufen,
        aufgabenWoche: random.nextInt(40),
      ),
    );
  }
  liste.sort((a, b) => a.name.compareTo(b.name));
  return TestKlasse(id: id, name: name, lernwelt: lernwelt, schueler: liste, art: art);
}

/// Erfundenes Ergebnis einer Person in einem zugewiesenen Paket (0-1).
double testErgebnis(String schuelerId, String paketId, double niveau) {
  final r = Random(streuwert('$schuelerId/$paketId')).nextDouble();
  return (0.25 + niveau / 3 * 0.6 + (r - 0.5) * 0.3).clamp(0.0, 1.0);
}
