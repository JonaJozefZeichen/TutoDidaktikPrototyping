import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:test/test.dart';

import 'bestand_test.dart' show gueltigeAufgabe, startbestand;

const lehrerin = Person(id: 'lehrperson-schule', name: 'L', lehrperson: true);
const didaktik = Person(id: 'didaktik-a', name: 'D', didaktik: true);

/// Testaufgabe mit gezielt gesetzten Werten.
StoreAufgabe aufgabe(
  String id, {
  String kompetenz = 'ag-test',
  String format = 'offen_zahl',
  int schwierigkeit = 3,
  int sekunden = 120,
  String? variantengruppe,
  bool parameter = false,
  String kontext = 'alltag',
}) {
  final inhalt = gueltigeAufgabe(id);
  inhalt['kontext'] = kontext;
  if (variantengruppe != null) inhalt['variantengruppe'] = variantengruppe;
  if (parameter) {
    inhalt['parametrisierbar'] = 'ja';
    inhalt['parameter'] = [
      {'name': 'a', 'min': 1, 'max': 9, 'schritt': 1},
    ];
  }
  final item = (inhalt['items'] as List).first as Map<String, dynamic>;
  item['kompetenz'] = kompetenz;
  item['antwortformat'] = format;
  item['schwierigkeit_start'] = schwierigkeit;
  item['erwartete_sekunden'] = sekunden;
  return StoreAufgabe.aus(id, inhalt, fassung: 1, status: 'live');
}

void main() {
  group('Store und Filter', () {
    final alle = [
      aufgabe('a1', kompetenz: 'ag-terme', format: 'mc_1aus6', schwierigkeit: 2, kontext: 'sport'),
      aufgabe('a2', kompetenz: 'ag-terme', format: 'offen_zahl', schwierigkeit: 4),
      aufgabe('a3', kompetenz: 'fa-steigung', format: 'mc_2aus5', schwierigkeit: 3, sekunden: 600),
    ];

    test('Mehrfachauswahl innerhalb einer Gruppe ist oder, zwischen Gruppen und', () {
      final f = StoreFilter()
        ..umschalten('format', 'ankreuzen')
        ..umschalten('kompetenz', 'ag-terme');
      expect(f.treffer(alle).map((a) => a.id), ['a1']);
      f.umschalten('format', 'zahl_term');
      expect(f.treffer(alle).map((a) => a.id), unorderedEquals(['a1', 'a2']));
    });

    test('Trefferzahl einer Gruppe berücksichtigt nur die anderen Gruppen', () {
      final f = StoreFilter()..umschalten('format', 'ankreuzen');
      expect(f.zaehle(facette('format'), alle), {'ankreuzen': 2, 'zahl_term': 1});
      expect(f.zaehle(facette('kompetenz'), alle), {'ag-terme': 1, 'fa-steigung': 1});
    });

    test('Schwierigkeit, Dauer und Text', () {
      expect((StoreFilter()..schwierigkeitBis = 3).treffer(alle).map((a) => a.id), unorderedEquals(['a1', 'a3']));
      expect((StoreFilter()..maxMinuten = 5).treffer(alle).map((a) => a.id), unorderedEquals(['a1', 'a2']));
      expect((StoreFilter()..text = 'STEIGUNG').treffer(alle).map((a) => a.id), ['a3']);
    });

    test('Filter übersteht JSON (gespeicherte Suche)', () {
      final f = StoreFilter(maxMinuten: 4, nurMitVarianten: true)..umschalten('kontext', 'sport');
      final zurueck = StoreFilter.fromJson(jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>);
      expect(zurueck.toJson(), f.toJson());
      expect(zurueck.anzahl, 3);
    });

    test('Lehrpersonen sehen nur freigegebene Aufgaben, im Test auf Wunsch alle außer zurückgezogenen', () {
      final b = Bestand()
        ..importiere(
          jsonEncode({
            'aufgaben': [gueltigeAufgabe('x1'), gueltigeAufgabe('x2')],
          }),
          null,
        );
      b.eintraege['x2']!.status = 'zurueckgezogen';
      expect(storeAufgaben(b.eintraege.values), isEmpty);
      expect(storeAufgaben(b.eintraege.values, auchUnfreigegebene: true).map((a) => a.id), ['x1']);
    });
  });

  group('Generator', () {
    final pool = [
      for (var i = 0; i < 12; i++)
        aufgabe('g$i', kompetenz: 'k${i % 4}', format: i.isEven ? 'mc_1aus6' : 'offen_zahl', schwierigkeit: 1 + i % 5),
    ];
    final gen = PaketGenerator(pool);

    test('gleicher Seed, gleiches Paket; keine Doppelten; aufsteigend', () {
      final e = GeneratorEinstellung(anzahl: 5);
      final a = gen.fuelle([], e, 7);
      final b = gen.fuelle([], e, 7);
      expect(a.map((p) => p.aufgabe), b.map((p) => p.aufgabe));
      expect(a.map((p) => p.aufgabe).toSet().length, 5);
      final stufen = [for (final p in a) pool.firstWhere((x) => x.id == p.aufgabe).schwierigkeit!];
      expect(stufen, [...stufen]..sort());
    });

    test('Kompetenzen werden gestreut', () {
      final p = gen.fuelle([], GeneratorEinstellung(anzahl: 4), 3);
      final k = {for (final x in p) pool.firstWhere((a) => a.id == x.aufgabe).hauptkompetenz};
      expect(k.length, 4);
    });

    test('gesperrte Plätze bleiben an ihrer Stelle, der Rest wird neu gewürfelt', () {
      final e = GeneratorEinstellung(anzahl: 5);
      final erst = gen.fuelle([], e, 1);
      erst[2].gesperrt = true;
      for (var seed = 2; seed < 12; seed++) {
        final neu = gen.fuelle(erst, e, seed);
        expect(neu.length, 5);
        expect(neu[2].aufgabe, erst[2].aufgabe);
        expect(neu[2].gesperrt, isTrue);
        expect(neu.map((p) => p.aufgabe).toSet().length, 5);
      }
    });

    test('Neu würfeln ändert nur einen Platz', () {
      final e = GeneratorEinstellung(anzahl: 4);
      final p = gen.fuelle([], e, 5);
      final neu = gen.neuWuerfeln(p, 1, e, 99)!;
      expect(neu.aufgabe, isNot(p[1].aufgabe));
      expect([p[0], p[2], p[3]].map((x) => x.aufgabe), isNot(contains(neu.aufgabe)));
    });

    test('Zielminuten füllen bis zur Dauer', () {
      final p = gen.fuelle([], GeneratorEinstellung(zielMinuten: 9), 4);
      final minuten = p.fold<double>(0, (s, x) => s + pool.firstWhere((a) => a.id == x.aufgabe).minuten);
      expect(minuten, greaterThanOrEqualTo(9));
      expect(p.length, 5);
    });

    test('Vorschläge zum Austauschen: gleiche Kompetenz und gemerkte zuerst', () {
      final g = PaketGenerator(pool, gemerkt: {'g9'});
      final p = [PaketPlatz.von(pool[0]), PaketPlatz.von(pool[1])];
      final v = g.vorschlaege(p, 0);
      expect(v.first.hauptkompetenz, 'k0');
      expect(v.map((a) => a.id), isNot(contains('g1')));
    });

    test('kleiner Pool: Paket wird so groß wie möglich', () {
      final p = PaketGenerator(pool.take(3).toList()).fuelle([], GeneratorEinstellung(anzahl: 8), 1);
      expect(p.length, 3);
    });
  });

  group('Gruppen A/B/C', () {
    test('Reihenfolge: Variante, andere Zahlen, Ersatz, fehlt', () {
      final alle = {
        for (final a in [
          aufgabe('v1', variantengruppe: 'G1', kompetenz: 'k1'),
          aufgabe('v2', variantengruppe: 'G1', kompetenz: 'k1'),
          aufgabe('p1', parameter: true, kompetenz: 'k2'),
          aufgabe('e1', kompetenz: 'k3', schwierigkeit: 3),
          aufgabe('e2', kompetenz: 'k3', schwierigkeit: 3),
          aufgabe('e3', kompetenz: 'k3', schwierigkeit: 3),
          aufgabe('x1', kompetenz: 'k4'),
        ])
          a.id: a,
      };
      final plaetze = [
        for (final id in ['v1', 'p1', 'e1', 'x1']) PaketPlatz.von(alle[id]!),
      ];
      final g = bildeGruppen(plaetze, 3, alle);
      expect(
        [for (final p in g['B']!) p.art],
        [GruppenArt.variante, GruppenArt.parameter, GruppenArt.ersatz, GruppenArt.fehlt],
      );
      expect(g['B']![0].aufgabe, 'v2');
      expect(g['B']![1].seed, 1);
      expect(g['C']![1].seed, 2);
      // C bekommt einen anderen Ersatz als B; die Variante ist verbraucht.
      expect(g['C']![2].aufgabe, isNot(g['B']![2].aufgabe));
      expect(g['C']![2].art, GruppenArt.ersatz);
      expect(g['C']![0].art, GruppenArt.fehlt);
    });

    test('Ersatz: gleiche Kompetenz und ähnliche Schwierigkeit, gleicher Typ zuerst', () {
      final o = aufgabe('o', kompetenz: 'k', format: 'mc_1aus6', schwierigkeit: 2);
      final alle = {
        for (final a in [
          o,
          aufgabe('gut', kompetenz: 'k', format: 'mc_1aus5', schwierigkeit: 2),
          aufgabe('anderer-typ', kompetenz: 'k', format: 'offen_zahl', schwierigkeit: 2),
          aufgabe('zu-schwer', kompetenz: 'k', format: 'mc_1aus6', schwierigkeit: 5),
        ])
          a.id: a,
      };
      expect(ersatzKandidaten(o, alle, {'o'}).map((a) => a.id), ['gut', 'anderer-typ']);
    });

    test('Antworten mischen: richtige Antwort und Fehlerbilder ziehen mit', () {
      final inhalt = gueltigeAufgabe('m');
      final item = (inhalt['items'] as List).first as Map<String, dynamic>;
      item['antwortformat'] = 'mc_1aus6';
      item['antwort'] = {
        'optionen': ['a', 'b', 'c', 'd', 'e', 'f'],
        'richtig': 2,
      };
      item['fehlerbilder'] = {'4': 'vorzeichen'};
      final m = mischeAntworten(inhalt, 3);
      final a = ((m['items'] as List).first as Map)['antwort'] as Map;
      final fb = ((m['items'] as List).first as Map)['fehlerbilder'] as Map;
      expect((a['optionen'] as List)[a['richtig'] as int], 'c');
      expect(a['optionen'], isNot(['a', 'b', 'c', 'd', 'e', 'f']));
      final schluessel = int.parse(fb.keys.single as String);
      expect((a['optionen'] as List)[schluessel], 'e');
      // Das Original bleibt unverändert.
      expect((item['antwort'] as Map)['richtig'], 2);
    });

    test('Lückentext und Zuordnung', () {
      final inhalt = gueltigeAufgabe('l');
      final item = (inhalt['items'] as List).first as Map<String, dynamic>;
      item['antwortformat'] = 'lueckentext';
      item['antwort'] = {
        'satz': '{1} {2}',
        'luecke_1': ['x', 'y', 'z'],
        'luecke_2': ['p', 'q', 'r'],
        'richtig': [1, 2],
      };
      item['fehlerbilder'] = {'1:0': 'falsch_x'};
      final m = mischeAntworten(inhalt, 5);
      final i2 = (m['items'] as List).first as Map;
      final a = i2['antwort'] as Map;
      expect((a['luecke_1'] as List)[(a['richtig'] as List)[0] as int], 'y');
      expect((a['luecke_2'] as List)[(a['richtig'] as List)[1] as int], 'r');
      final k = (i2['fehlerbilder'] as Map).keys.single as String;
      expect((a['luecke_1'] as List)[int.parse(k.split(':')[1])], 'x');

      item['antwortformat'] = 'zuordnung';
      item['antwort'] = {
        'elemente': ['e0', 'e1', 'e2', 'e3'],
        'optionen': ['A', 'B', 'C', 'D', 'E', 'F'],
        'richtig': {'0': 'A', '1': 'B', '2': 'C', '3': 'D'},
      };
      final z = ((mischeAntworten(inhalt, 2)['items'] as List).first as Map)['antwort'] as Map;
      for (var i = 0; i < 4; i++) {
        final element = (z['elemente'] as List)[i] as String;
        expect((z['richtig'] as Map)['$i'], 'ABCD'[int.parse(element.substring(1))]);
      }
    });
  });

  group('Ablage der Lehrpersonen', () {
    test('nur Lehrpersonen, Version schützt vor Überschreiben', () {
      final l = Lehrbereich();
      expect(() => l.lies(didaktik), throwsA(isA<RegelFehler>()));
      final d = l.lies(lehrerin);
      expect(d.ordner.single.id, standardOrdner);
      d.ordnerMit(standardOrdner)!.aufgaben.add('a1');
      final gespeichert = l.speichere(lehrerin, d.toJson());
      expect(gespeichert.version, 1);
      expect(l.lies(lehrerin).gemerkt, {'a1'});
      // Ein zweites Fenster mit altem Stand.
      expect(
        () => l.speichere(lehrerin, LehrDaten().toJson()),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'konflikt')),
      );
    });

    test('Paket übersteht JSON', () {
      final p = Paket(id: 'p1', titel: 'Test', erstellt: DateTime(2026, 11, 9), gruppen: 2)
        ..plaetze.add(PaketPlatz(aufgabe: 'a', fassung: 3, gesperrt: true))
        ..gruppenPlaetze['B'] = [const GruppenPlatz(aufgabe: 'b', fassung: 1, art: GruppenArt.ersatz)];
      final zurueck = Paket.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(zurueck.toJson(), p.toJson());
    });

    test('Lehrpersonen dürfen keine Aufgaben bearbeiten oder freigeben', () {
      final b = Bestand()
        ..importiere(
          jsonEncode({
            'aufgaben': [gueltigeAufgabe('x1')],
          }),
          null,
        );
      expect(() => b.speichere('x1', gueltigeAufgabe('x1'), lehrerin, basis: 1), throwsA(isA<RegelFehler>()));
      expect(() => b.approval('x1', 1, lehrerin), throwsA(isA<RegelFehler>()));
      expect(() => b.importiere('{"aufgaben": []}', lehrerin), throwsA(isA<RegelFehler>()));
    });

    test('Schnittstelle: Store und Ablage nur für Lehrpersonen', () {
      final b = Bestand()..importiere(startbestand.readAsStringSync(), null);
      final s = Schnittstelle(b, Stammlisten(const [], const [], const []));
      expect(s.verarbeite('GET', ['lehre', 'aufgaben'], person: 'didaktik-a').status, 403);
      expect(s.verarbeite('GET', ['lehre', 'aufgaben'], person: 'lehrperson-schule').daten, isEmpty);
      final test = s.verarbeite('GET', ['lehre', 'aufgaben', 'test'], person: 'lehrperson-schule');
      expect((test.daten as List).length, b.eintraege.length);
      final d = s.verarbeite('GET', ['lehre', 'daten'], person: 'lehrperson-nachhilfe').daten as Map<String, dynamic>;
      final neu = s.verarbeite('POST', ['lehre', 'daten'], person: 'lehrperson-nachhilfe', inhalt: jsonEncode(d));
      expect((neu.daten as Map)['version'], 1);
    });
  });

  test('Testklassen sind reproduzierbar und je nach Person verschieden', () {
    final k = {
      5: ['ag-a', 'ag-b', 'fa-c'],
      6: ['an-d'],
    };
    final a = testKlassen('lehrperson-schule', k);
    expect(a.map((x) => x.toJson()), testKlassen('lehrperson-schule', k).map((x) => x.toJson()));
    expect(a.first.schueler.length, 20);
    expect(a.first.schueler.first.stufen.keys, unorderedEquals(['ag-a', 'ag-b', 'fa-c']));
    expect(testKlassen('lehrperson-nachhilfe', k).first.art, 'nachhilfe');
  });

  group('Gruppen und Förderung', () {
    test('Gruppen heißen nach dem Alphabet, beliebig viele, Standard 2', () {
      expect(gruppenNamenBis(4), ['A', 'B', 'C', 'D']);
      expect(gruppenName(25), 'Z');
      expect(Paket(id: 'p', titel: 't', erstellt: DateTime(2026)).gruppen, 2);
      final alle = {for (var i = 0; i < 8; i++) 'e$i': aufgabe('e$i', kompetenz: 'k', schwierigkeit: 3)};
      final g = bildeGruppen([PaketPlatz.von(alle['e0']!)], 5, alle);
      expect(g.keys, ['B', 'C', 'D', 'E']);
      expect({for (final l in g.values) l.single.aufgabe}.length, 4);
    });

    test('Verteilung abwechselnd, auch für eine Teilmenge', () {
      expect(verteileGruppen(['a', 'b', 'c', 'd', 'e'], 2), {'a': 'A', 'b': 'B', 'c': 'A', 'd': 'B', 'e': 'A'});
      expect(verteileGruppen(['x'], 3), {'x': 'A'});
    });

    test('Förderung übersteht JSON', () {
      final p = Paket(id: 'p', titel: 't', erstellt: DateTime(2026))
        ..foerderung = const Foerderung(klasse: 'k1', kompetenz: 'ag-x', schueler: ['s1', 's2']);
      final z = Paket.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(z.foerderung!.schueler, ['s1', 's2']);
      expect(z.toJson(), p.toJson());
    });

    test('Testantworten: reproduzierbar, falsche haben eine gegebene Antwort', () {
      final person = testKlassen('lehrperson-schule', {
        5: ['ag-test'],
      }).first.schueler.first;
      final inhalt = gueltigeAufgabe('t1');
      final item = (inhalt['items'] as List).first as Map<String, dynamic>;
      item['antwortformat'] = 'mc_1aus6';
      item['antwort'] = {
        'optionen': ['a', 'b', 'c', 'd', 'e', 'f'],
        'richtig': 0,
      };
      final aufgaben = {'t1': inhalt};
      final ergebnisse = [
        for (var i = 0; i < 40; i++) ...testAntworten(person, 'paket-$i', ['t1'], aufgaben),
      ];
      expect(ergebnisse, hasLength(40));
      expect(testAntworten(person, 'paket-1', ['t1'], aufgaben).single.richtig, ergebnisse[1].richtig);
      for (final e in ergebnisse) {
        expect(e.gegeben.isEmpty, e.richtig);
        if (!e.richtig) expect(['b', 'c', 'd', 'e', 'f'], contains(e.gegeben));
      }
    });
  });
}
