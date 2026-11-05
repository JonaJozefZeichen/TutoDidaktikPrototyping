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
