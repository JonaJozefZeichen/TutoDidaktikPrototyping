import 'dart:convert';
import 'dart:io';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:test/test.dart';

/// Manuels volle Datei gibt es nur lokal; sonst gelten die öffentlichen Beispiele.
File get startbestand {
  final privat = File('../../seed/privat/aufgaben.json');
  return privat.existsSync() ? privat : File('../../app/assets/beispiel/aufgaben.json');
}

const anna = Person(id: 'anna', name: 'Anna', didaktik: true);
const ben = Person(id: 'ben', name: 'Ben', didaktik: true);
const admin = Person(id: 'admin', name: 'Admin', admin: true);
const gast = Person(id: 'gast', name: 'Gast');

Map<String, dynamic> gueltigeAufgabe(String id) => {
  'id': id,
  'titel': 'Titel',
  'herkunft': 'team',
  'zusammenstellung': 'einzel',
  'matura_niveau': 'einstieg',
  'schultyp': 'AHS',
  'schulstufe': 9,
  'kontext': 'alltag',
  'stamm': '',
  'technologie': 'ohne',
  'parametrisierbar': 'nein',
  'items': [
    {
      ...leeresItem('$id-i1'),
      'aufgabenstellung': 'Berechne.',
      'operator': 'berechnen',
      'handlungsbereich': 'H2',
      'inhaltsbereich': 'AG',
      'kompetenz': 'ag-test',
      'antwortformat': 'offen_zahl',
      'antwort': {'wert': 8, 'toleranz': 0, 'einheit': null, 'einheit_pflicht': 'nein', 'rundung': null},
      'loesungsweg': ['So geht es.'],
      'hilfen': [
        for (final s in [1, 2, 3])
          {
            'stufe': s,
            'text': 'Hilfe $s',
            'freigabe': {'nach_sekunden': 10},
          },
      ],
    },
  ],
};

Bestand mitAufgabe(String id) {
  final b = Bestand();
  b.importiere(
    jsonEncode({
      'quelle': 'Test',
      'aufgaben': [gueltigeAufgabe(id)],
    }),
    anna,
  );
  return b;
}

void main() {
  group('Import', () {
    test('alles startet als entwurf, auch mit anderem Status in der Datei', () {
      final b = Bestand();
      final a = {...gueltigeAufgabe('a1'), 'status': 'live'};
      b.importiere(
        jsonEncode({
          'aufgaben': [a],
        }),
        anna,
      );
      expect(b.eintrag('a1').status, 'entwurf');
      expect(b.eintrag('a1').aktuell.inhalt.containsKey('status'), isFalse);
    });

    test('bestehende IDs werden nicht überschrieben', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, anna, basis: 1);
      final bericht = b.importiere(
        jsonEncode({
          'aufgaben': [gueltigeAufgabe('a1')],
        }),
        anna,
      );
      expect(bericht.konflikte, ['a1']);
      expect(b.eintrag('a1').aktuell.inhalt['titel'], 'Neu');
    });

    test('unvollständige Aufgaben werden als Entwurf mit Fehlern angenommen', () {
      final b = Bestand();
      final bericht = b.importiere(
        jsonEncode({
          'aufgaben': [
            {
              'id': 'roh',
              'items': [
                {'aufgabenstellung': 'x'},
              ],
            },
          ],
        }),
        anna,
      );
      expect(bericht.uebernommen.single['fehler'], greaterThan(0));
      expect(bericht.uebernommen.single['item_ids_ergaenzt'], 1);
      expect(alleItems(b.eintrag('roh').aktuell.inhalt).single['item_id'], 'roh-i1');
    });

    test('kaputte Einträge werden abgelehnt, doppelte IDs auch', () {
      final b = Bestand();
      final bericht = b.importiere(
        jsonEncode({
          'aufgaben': [
            {'titel': 'ohne id'},
            gueltigeAufgabe('x'),
            gueltigeAufgabe('x'),
          ],
        }),
        anna,
      );
      expect(bericht.abgelehnt, hasLength(2));
      expect(bericht.uebernommen, hasLength(1));
    });

    test('kein JSON ergibt einen klaren Fehler', () {
      expect(
        () => Bestand().importiere('{kaputt', anna),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'json')),
      );
    });

    test('item_id einer anderen Aufgabe wird abgelehnt', () {
      final b = mitAufgabe('a1');
      final fremd = gueltigeAufgabe('a2');
      (fremd['items'] as List).first['item_id'] = 'a1-i1';
      final bericht = b.importiere(
        jsonEncode({
          'aufgaben': [fremd],
        }),
        anna,
      );
      expect(bericht.abgelehnt, hasLength(1));
    });
  });

  group('Freigabe', () {
    test('erstes Approval geprueft, zweites von anderer Person live', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      expect(b.eintrag('a1').status, 'geprueft');
      b.approval('a1', 1, ben);
      expect(b.eintrag('a1').status, 'live');
      expect(b.eintrag('a1').liveFassung, 1);
    });

    test('dieselbe Person zählt nicht zweimal', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      expect(() => b.approval('a1', 1, anna), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'doppelt')));
      expect(b.eintrag('a1').status, 'geprueft');
    });

    test('eigenes Approval zurücknehmen macht aus geprueft wieder entwurf', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approvalZuruecknehmen('a1', 1, anna);
      expect(b.eintrag('a1').status, 'entwurf');
      expect(b.eintrag('a1').aktuell.approvals, isEmpty);
      expect(b.eintrag('a1').ereignisse.last.art, 'approval_zurueck');
      // Danach darf dieselbe Person wieder freigeben.
      b.approval('a1', 1, anna);
      expect(b.eintrag('a1').status, 'geprueft');
    });

    test('fremdes Approval und Live-Fassung lassen sich nicht zurücknehmen', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      expect(
        () => b.approvalZuruecknehmen('a1', 1, ben),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'kein_approval')),
      );
      b.approval('a1', 1, ben);
      expect(
        () => b.approvalZuruecknehmen('a1', 1, anna),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'schon_live')),
      );
      expect(b.eintrag('a1').status, 'live');
    });

    test('Approval auf eine Korrektur zurücknehmen: Aufgabe bleibt live', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Korrektur'}, anna, basis: 1);
      b.approval('a1', 2, anna);
      b.approvalZuruecknehmen('a1', 2, anna);
      expect(b.eintrag('a1').status, 'live');
      expect(b.eintrag('a1').liveFassung, 1);
      expect(b.eintrag('a1').aktuell.approvals, isEmpty);
    });

    test('bearbeitende Person darf eines der Approvals geben', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, anna, basis: 1);
      b.approval('a1', 2, anna);
      b.approval('a1', 2, ben);
      expect(b.eintrag('a1').status, 'live');
    });

    test('Admin ohne Didaktik-Rolle gibt kein Approval, mit Rolle schon', () {
      final b = mitAufgabe('a1');
      expect(() => b.approval('a1', 1, admin), throwsA(isA<RegelFehler>()));
      b.approval('a1', 1, const Person(id: 'beides', name: 'B', didaktik: true, admin: true));
      expect(b.eintrag('a1').status, 'geprueft');
    });

    test('Fehler verhindern ein Approval', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': ''}, anna, basis: 1);
      expect(() => b.approval('a1', 2, anna), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'pruefung')));
    });

    test('ungeklärte Bildrechte verhindern ein Approval', () {
      final b = mitAufgabe('a1');
      b.speichere(
        'a1',
        {
          ...b.eintrag('a1').aktuell.inhalt,
          'medien': [
            {'typ': 'bild', 'datei': 'x.png', 'rechte_geklaert': 'nein'},
          ],
        },
        anna,
        basis: 1,
      );
      expect(() => b.approval('a1', 2, anna), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'pruefung')));
    });

    test('Approval auf eine alte Fassung geht nicht', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, anna, basis: 1);
      expect(() => b.approval('a1', 1, ben), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'konflikt')));
    });

    test('Änderung setzt Approvals zurück und geprueft wird entwurf', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, ben, basis: 1);
      expect(b.eintrag('a1').status, 'entwurf');
      expect(b.eintrag('a1').aktuell.approvals, isEmpty);
    });

    test('Entfernen einer Abhängigkeit setzt Approvals zurück', () {
      final b = Bestand();
      final a = gueltigeAufgabe('a1');
      final erstes = (a['items'] as List).first as Map<String, dynamic>;
      a['items'] = [
        erstes,
        {...erstes, 'item_id': 'a1-i2', 'abhaengig_von': 'a1-i1', 'folgefehler': 'ja'},
      ];
      b.importiere(
        jsonEncode({
          'aufgaben': [a],
        }),
        anna,
      );
      b.approval('a1', 1, anna);
      final inhalt = jsonDecode(jsonEncode(b.eintrag('a1').aktuell.inhalt)) as Map<String, dynamic>;
      (inhalt['items'] as List)[1]['abhaengig_von'] = null;
      (inhalt['items'] as List)[1]['folgefehler'] = null;
      b.speichere('a1', inhalt, anna, basis: 1);
      expect(b.eintrag('a1').aktuell.approvals, isEmpty);
      expect(b.eintrag('a1').status, 'entwurf');
    });

    test('Live-Aufgabe bleibt live, bis die Korrektur zwei Approvals hat', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Korrektur'}, anna, basis: 1);
      final e = b.eintrag('a1');
      expect(e.status, 'live');
      expect(e.hatKorrektur, isTrue);
      expect(e.liveInhalt!['titel'], 'Titel');
      b.approval('a1', 2, anna);
      expect(e.status, 'live');
      expect(e.liveInhalt!['titel'], 'Titel');
      b.approval('a1', 2, ben);
      expect(e.liveInhalt!['titel'], 'Korrektur');
      expect(e.hatKorrektur, isFalse);
    });

    test('Approval auf die schon freigegebene Fassung geht nicht', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      const dritte = Person(id: 'c', name: 'C', didaktik: true);
      expect(() => b.approval('a1', 1, dritte), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'schon_live')));
    });
  });

  group('Zurückziehen', () {
    test('eine Person nimmt die Aufgabe sofort aus der App', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      b.zurueckziehen('a1', admin, grund: 'falsche Lösung');
      final e = b.eintrag('a1');
      expect(e.status, 'zurueckgezogen');
      expect(e.liveInhalt, isNull);
      expect(e.ereignisse.last.text, 'falsche Lösung');
    });

    test('geht nur bei Live-Aufgaben', () {
      final b = mitAufgabe('a1');
      expect(() => b.zurueckziehen('a1', anna), throwsA(isA<RegelFehler>()));
    });

    test('zurück in die App nur mit zwei neuen Approvals', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      b.zurueckziehen('a1', anna);
      expect(
        () => b.approval('a1', 1, ben),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'zurueckgezogen')),
      );
      b.wiederaufnehmen('a1', anna);
      final e = b.eintrag('a1');
      expect(e.status, 'entwurf');
      expect(e.aktuell.nr, 2);
      expect(e.aktuell.approvals, isEmpty);
      b.approval('a1', 2, anna);
      expect(e.status, 'geprueft');
      b.approval('a1', 2, ben);
      expect(e.status, 'live');
    });

    test('Bearbeiten einer zurückgezogenen Aufgabe macht sie zum Entwurf', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      b.zurueckziehen('a1', anna);
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, anna, basis: 1);
      expect(b.eintrag('a1').status, 'entwurf');
    });
  });

  group('Bearbeiten', () {
    test('veralteter Stand ergibt einen Konflikt, trotzdem speichert', () {
      final b = mitAufgabe('a1');
      final alt = b.eintrag('a1').aktuell.inhalt;
      b.speichere('a1', {...alt, 'titel': 'Von Anna'}, anna, basis: 1);
      expect(
        () => b.speichere('a1', {...alt, 'titel': 'Von Ben'}, ben, basis: 1),
        throwsA(isA<RegelFehler>().having((e) => e.status, 'status', 409)),
      );
      b.speichere('a1', {...alt, 'titel': 'Von Ben'}, ben, basis: 1, trotzdem: true);
      expect(b.eintrag('a1').aktuell.inhalt['titel'], 'Von Ben');
    });

    test('ohne Änderung entsteht keine Fassung', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.speichere('a1', b.eintrag('a1').aktuell.inhalt, ben, basis: 1);
      expect(b.eintrag('a1').aktuell.nr, 1);
      expect(b.eintrag('a1').aktuell.approvals, hasLength(1));
    });

    test('Aufgaben-ID lässt sich nicht ändern', () {
      final b = mitAufgabe('a1');
      expect(
        () => b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'id': 'b1'}, anna, basis: 1),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'id_schutz')),
      );
    });

    test('Status im Inhalt wird ignoriert', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'N', 'status': 'live'}, anna, basis: 1);
      expect(b.eintrag('a1').status, 'entwurf');
    });

    test('Items, die live waren, lassen sich nicht entfernen', () {
      final b = mitAufgabe('a1');
      b.approval('a1', 1, anna);
      b.approval('a1', 1, ben);
      expect(
        () => b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'items': []}, anna, basis: 1),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'id_schutz')),
      );
    });

    test('item_id einer anderen Aufgabe lässt sich nicht übernehmen', () {
      final b = mitAufgabe('a1');
      b.importiere(
        jsonEncode({
          'aufgaben': [gueltigeAufgabe('a2')],
        }),
        anna,
      );
      final inhalt = jsonDecode(jsonEncode(b.eintrag('a2').aktuell.inhalt)) as Map<String, dynamic>;
      (inhalt['items'] as List).first['item_id'] = 'a1-i1';
      expect(
        () => b.speichere('a2', inhalt, anna, basis: 1),
        throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'id_schutz')),
      );
    });

    test('frühere Fassung wiederherstellen ergibt eine neue Fassung ohne Approvals', () {
      final b = mitAufgabe('a1');
      b.speichere('a1', {...b.eintrag('a1').aktuell.inhalt, 'titel': 'Neu'}, anna, basis: 1);
      b.approval('a1', 2, anna);
      b.wiederherstellen('a1', 1, ben);
      final e = b.eintrag('a1');
      expect(e.aktuell.nr, 3);
      expect(e.aktuell.inhalt['titel'], 'Titel');
      expect(e.aktuell.approvals, isEmpty);
      expect(e.status, 'entwurf');
    });

    test('Person ohne Rolle darf nichts ändern', () {
      final b = mitAufgabe('a1');
      expect(() => b.speichere('a1', b.eintrag('a1').aktuell.inhalt, gast, basis: 1), throwsA(isA<RegelFehler>()));
      expect(() => b.approval('a1', 1, gast), throwsA(isA<RegelFehler>()));
    });
  });

  test('Verlauf und Speichern überstehen JSON', () {
    final b = mitAufgabe('a1');
    b.approval('a1', 1, anna);
    final neu = Bestand(eintraege: Bestand.eintraegeAusJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>));
    expect(neu.eintrag('a1').status, 'geprueft');
    expect(neu.eintrag('a1').aktuell.approvals.single.person, 'anna');
    expect(neu.eintrag('a1').ereignisse, hasLength(2));
  });

  group('Prüfung', () {
    test('gültige Aufgabe hat keine Fehler', () {
      expect(pruefeAufgabe(gueltigeAufgabe('a1')).where((b) => b.istFehler), isEmpty);
    });

    test('Fehler zeigen auf das Feld', () {
      final a = gueltigeAufgabe('a1');
      (a['items'] as List).first['operator'] = 'interpretieren';
      final b = pruefeAufgabe(a);
      expect(b.single.pfad, 'items/0/operator');
    });

    test('Abhängigkeit muss auf ein früheres Item zeigen', () {
      final a = gueltigeAufgabe('a1');
      (a['items'] as List).first['abhaengig_von'] = 'a1-i9';
      (a['items'] as List).first['folgefehler'] = 'ja';
      expect(pruefeAufgabe(a).map((b) => b.pfad), contains('items/0/abhaengig_von'));
    });

    test('Struktur der Antwort wird wie in der App geprüft', () {
      final a = gueltigeAufgabe('a1');
      final item = (a['items'] as List).first as Map<String, dynamic>;
      item['antwortformat'] = 'mc_1aus5';
      item['antwort'] = {
        'optionen': ['a'],
        'richtig': 0,
      };
      expect(pruefeAufgabe(a).map((b) => b.pfad), contains('items/0/antwort'));
    });

    test('Hilfe als KI-Entwurf ist nur ein Hinweis', () {
      final a = gueltigeAufgabe('a1');
      ((a['items'] as List).first['hilfen'] as List)[1]['entwurf'] = 'ki';
      final b = pruefeAufgabe(a);
      expect(b.single.istFehler, isFalse);
    });

    test('Unlesbare Typen führen zu Befunden statt zum Absturz', () {
      final a = gueltigeAufgabe('a1');
      a['titel'] = 5;
      a['items'] = 'kaputt';
      expect(pruefeAufgabe(a), isNotEmpty);
    });
  });

  group('Antworten markieren', () {
    Map<String, dynamic> ankreuzen(String format, List<String> optionen, Object? richtig) {
      final a = gueltigeAufgabe('a1');
      final i = (a['items'] as List).first as Map<String, dynamic>;
      i['antwortformat'] = format;
      i['antwort'] = {'optionen': optionen, 'richtig': richtig};
      return a;
    }

    List<String> antwortFehler(Map<String, dynamic> a) => [
      for (final b in pruefeAufgabe(a))
        if (b.pfad == 'items/0/antwort') b.text,
    ];

    const fuenf = ['a', 'b', 'c', 'd', 'e'];
    const sechs = ['a', 'b', 'c', 'd', 'e', 'f'];

    test('passende Markierungen haben keine Fehler', () {
      expect(antwortFehler(ankreuzen('mc_1aus5', fuenf, 1)), isEmpty);
      expect(antwortFehler(ankreuzen('mc_1aus6', sechs, 1)), isEmpty);
      expect(antwortFehler(ankreuzen('mc_2aus5', fuenf, [0, 1])), isEmpty);
    });

    test('zu viele richtige, genau eine verständliche Meldung', () {
      expect(antwortFehler(ankreuzen('mc_1aus6', sechs, [0, 1])), [
        'Zu viele richtige Antworten: 2 markiert, dieses Format hat genau 1',
      ]);
    });

    test('zu wenige richtige, genau eine verständliche Meldung', () {
      expect(antwortFehler(ankreuzen('mc_2aus5', fuenf, 2)), [
        'Zu wenige richtige Antworten: 1 markiert, dieses Format hat genau 2',
      ]);
      expect(antwortFehler(ankreuzen('mc_1aus5', fuenf, const [])), [
        'Zu wenige richtige Antworten: 0 markiert, dieses Format hat genau 1',
      ]);
    });

    test('zu viele und leere Antworten', () {
      expect(antwortFehler(ankreuzen('mc_1aus5', sechs, 1)), ['Zu viele Antworten: 6, dieses Format hat genau 5']);
      expect(antwortFehler(ankreuzen('mc_1aus6', fuenf, 1)), ['Antwort 6 ist leer']);
      expect(antwortFehler(ankreuzen('mc_1aus5', ['a', ' ', 'c', 'd', 'e'], 1)), ['Antwort 2 ist leer']);
    });

    test('solche Fehler sperren das Approval', () {
      final b = Bestand();
      b.importiere(
        jsonEncode({
          'aufgaben': [ankreuzen('mc_1aus6', sechs, [0, 1])],
        }),
        anna,
      );
      expect(() => b.approval('a1', 1, anna), throwsA(isA<RegelFehler>().having((e) => e.code, 'code', 'pruefung')));
    });

    test('Fehlerbild an einer überzähligen Antwort bleibt gültig', () {
      final a = ankreuzen('mc_1aus5', sechs, 1);
      ((a['items'] as List).first as Map)['fehlerbilder'] = {'5': 'x'};
      expect(pruefeAufgabe(a).where((b) => b.pfad.endsWith('fehlerbilder')), isEmpty);
    });

    test('Lückentext und Zuordnung melden Leeres verständlich', () {
      final a = gueltigeAufgabe('a1');
      final i = (a['items'] as List).first as Map<String, dynamic>;
      i['antwortformat'] = 'lueckentext';
      i['antwort'] = leereAntwort('lueckentext');
      expect(antwortFehler(a), hasLength(6));
      i['antwortformat'] = 'zuordnung';
      i['antwort'] = {
        'elemente': ['1', '2', '3', '4'],
        'optionen': ['a', 'b', 'c', 'd', 'e', ''],
        'richtig': {'0': 'A', '1': 'B', '2': 'C'},
      };
      expect(antwortFehler(a), ['Element 4 hat keine richtige Option', 'Option F ist leer']);
    });

    group('Formatwechsel', () {
      test('zwischen Ankreuzformaten bleibt alles stehen', () {
        final neu = antwortFuerFormat('mc_1aus6', {
          'optionen': fuenf,
          'richtig': [0, 1],
        });
        expect(neu['optionen'], fuenf);
        expect(neu['richtig'], [0, 1]);
      });

      test('eine Markierung wird zur Zahl oder Liste, wie das Format es braucht', () {
        expect(antwortFuerFormat('mc_2aus5', {'optionen': fuenf, 'richtig': 2})['richtig'], [2]);
        expect(
          antwortFuerFormat('mc_1aus5', {
            'optionen': fuenf,
            'richtig': [2],
          })['richtig'],
          2,
        );
      });

      test('leere Plätze über der Formatgröße fallen weg, gefüllte bleiben', () {
        expect(antwortFuerFormat('mc_1aus5', {'optionen': ['a', 'b', 'c', 'd', 'e', ''], 'richtig': 1})['optionen'], fuenf);
        expect(antwortFuerFormat('mc_1aus5', {'optionen': sechs, 'richtig': 1})['optionen'], sechs);
      });

      test('zwischen anderen Formaten bleiben gemeinsame Felder gleichen Typs', () {
        final neu = antwortFuerFormat('halboffen', {'wert': 8, 'toleranz': 0.5, 'einheit': 'km'});
        expect(neu['wert'], 8);
        expect(neu['toleranz'], 0.5);
        expect(neu['einheit'], 'km');
        expect(neu['vorlage'], 'x = {x}');
        final term = antwortFuerFormat('offen_zahl', {'optionen': fuenf, 'richtig': 1, 'wert': 'kaputt'});
        expect(term['wert'], 0);
        expect(term.containsKey('optionen'), isFalse);
      });
    });
  });

  group('Fehlerbilder', () {
    Map<String, dynamic> mit(String format, Map<String, dynamic> antwort, Map<String, dynamic> fb) {
      final a = gueltigeAufgabe('a1');
      final i = (a['items'] as List).first as Map<String, dynamic>;
      i['antwortformat'] = format;
      i['antwort'] = antwort;
      i['fehlerbilder'] = fb;
      return a;
    }

    final mc = {
      'optionen': ['a', 'b', 'c', 'd', 'e'],
      'richtig': 1,
    };
    final luecke = {
      'satz': '{1} {2}',
      'luecke_1': ['a', 'b', 'c'],
      'luecke_2': ['d', 'e', 'f'],
      'richtig': [0, 1],
    };
    final zuordnung = {
      'elemente': ['1', '2', '3', '4'],
      'optionen': ['a', 'b', 'c', 'd', 'e', 'f'],
      'richtig': {'0': 'A', '1': 'B', '2': 'C', '3': 'D'},
    };
    final zahl = {'wert': 8, 'toleranz': 0, 'einheit': null, 'einheit_pflicht': 'nein', 'rundung': null};

    List<Befund> befunde(Map<String, dynamic> a) =>
        pruefeAufgabe(a).where((b) => b.pfad == 'items/0/fehlerbilder').toList();

    test('gültige Schlüssel je Format haben keine Befunde', () {
      expect(befunde(mit('mc_1aus5', mc, {'2': 'vorzeichenfehler'})), isEmpty);
      expect(befunde(mit('lueckentext', luecke, {'1:2': 'x', '2:0': 'y'})), isEmpty);
      expect(befunde(mit('zuordnung', zuordnung, {'E': 'x'})), isEmpty);
      expect(befunde(mit('offen_zahl', zahl, {'16': 'x', '6,25': 'y'})), isEmpty);
      expect(befunde(mit('offen_term', {'term': '2*x'}, {'x+2': 'plus_statt_mal'})), isEmpty);
    });

    test('Fehlerbild an einer richtigen Antwort ist ein Fehler', () {
      for (final a in [
        mit('mc_1aus5', mc, {'1': 'x'}),
        mit('lueckentext', luecke, {'1:0': 'x'}),
        mit('zuordnung', zuordnung, {'A': 'x'}),
        mit('offen_zahl', zahl, {'8': 'x'}),
        mit('offen_term', {'term': '2*x'}, {'x*2': 'x'}),
      ]) {
        expect(befunde(a).single.istFehler, isTrue, reason: '${a['items']}');
      }
    });

    test('Name muss dem Schema folgen', () {
      expect(befunde(mit('mc_1aus5', mc, {'2': 'Vorzeichen Fehler'})).single.istFehler, isTrue);
    });

    test('unpassender Schlüssel ist nur ein Hinweis', () {
      expect(befunde(mit('mc_1aus5', mc, {'9': 'x'})).single.istFehler, isFalse);
      expect(befunde(mit('offen_text', {'musterloesung': 'a'}, {'1': 'x'})).single.istFehler, isFalse);
    });

    Item ladeItem(Map<String, dynamic> a) => ladeZurVorschau(a).aufgabe!.items.first;
    const pruefer = AnswerChecker();

    test('Prüfung liefert das Fehlerbild je Format', () {
      expect(pruefer.check(ladeItem(mit('mc_1aus5', mc, {'2': 'x'})), 2).fehlerbild, 'x');
      final mc2 = {
        'optionen': ['a', 'b', 'c', 'd', 'e'],
        'richtig': [0, 1],
      };
      expect(pruefer.check(ladeItem(mit('mc_2aus5', mc2, {'3': 'x'})), <int>{0, 3}).fehlerbild, 'x');
      expect(pruefer.check(ladeItem(mit('lueckentext', luecke, {'2:2': 'x'})), <int?>[0, 2]).fehlerbild, 'x');
      expect(pruefer.check(ladeItem(mit('zuordnung', zuordnung, {'E': 'x'})), <int, String>{0: 'E', 1: 'B', 2: 'C', 3: 'D'}).fehlerbild, 'x');
      expect(pruefer.check(ladeItem(mit('offen_zahl', zahl, {'16': 'x'})), '16').fehlerbild, 'x');
      expect(pruefer.check(ladeItem(mit('offen_term', {'term': '2*x'}, {'x+2': 'x'})), '2+x').fehlerbild, 'x');
      final paar = {
        'vorlage': '{x} {y}',
        'art': 'zahl',
        'wert': [2, 3],
        'toleranz': 0,
      };
      expect(pruefer.check(ladeItem(mit('halboffen', paar, {'4; 5': 'x'})), <String>['4', '5']).fehlerbild, 'x');
    });

    test('richtige Antworten bleiben richtig, andere falsche ohne Fehlerbild', () {
      expect(pruefer.check(ladeItem(mit('mc_1aus5', mc, {'2': 'x'})), 1).richtig, isTrue);
      expect(pruefer.check(ladeItem(mit('offen_zahl', zahl, {'16': 'x'})), '7').fehlerbild, isNull);
    });
  });

  test('alle Felder der Feldliste sind abgedeckt', () {
    final aufgaben = (jsonDecode(startbestand.readAsStringSync()) as Map<String, dynamic>)['aufgaben'] as List;
    final bekannt = {for (final f in aufgabeFelder) f.key, 'items', 'verwendung'};
    final bekannteItems = {for (final f in itemFelder) f.key};
    for (final a in aufgaben.cast<Map<String, dynamic>>()) {
      expect(a.keys.toSet().difference(bekannt), isEmpty, reason: a['id'] as String);
      for (final i in (a['items'] as List).cast<Map<String, dynamic>>()) {
        expect(i.keys.toSet().difference(bekannteItems), isEmpty, reason: i['item_id'] as String);
      }
    }
  });

  test('der Startbestand lässt sich importieren, nur als Entwurf und ohne Fehler', () {
    final b = Bestand();
    final text = startbestand.readAsStringSync();
    final zahl = ((jsonDecode(text) as Map<String, dynamic>)['aufgaben'] as List).length;
    final bericht = b.importiere(text, null);
    expect(bericht.uebernommen, hasLength(zahl));
    expect(bericht.abgelehnt, isEmpty);
    expect(b.eintraege.values.every((e) => e.status == 'entwurf'), isTrue);
    expect(bericht.uebernommen.every((u) => u['fehler'] == 0), isTrue);
  });
}
