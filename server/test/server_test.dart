import 'dart:convert';
import 'dart:io';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:didaktik_server/server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

/// Kompletter Ablauf über HTTP, auch verbotene Anfragen direkt gegen den Server.
void main() {
  late Directory tmp;
  late HttpServer server;
  late String basis;
  late File datei;
  const id = 'tuto-ag5-01-a01';

  Future<HttpServer> starte() async {
    final ordner = datenOrdner(Directory('..').absolute);
    final daten = listenAusOrdner(ordner);
    final s = Speicher(datei, kontext: daten.kontext);
    if (s.bestand.eintraege.isEmpty) {
      s.bestand.importiere(File('${ordner.path}/aufgaben.json').readAsStringSync(), null);
      s.sichern();
    }
    return io.serve((Router()..mount('/api/', baueApi(s, daten))).call, InternetAddress.loopbackIPv4, 0);
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('didaktik');
    datei = File('${tmp.path}/bestand.json');
    server = await starte();
    basis = 'http://127.0.0.1:${server.port}/api';
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  Future<(int, dynamic)> post(String pfad, Object body, {String? person = 'didaktik-a'}) async {
    final r = await http.post(
      Uri.parse('$basis$pfad'),
      headers: {'x-person': ?person, 'content-type': 'application/json'},
      body: body is String ? body : jsonEncode(body),
    );
    return (r.statusCode, jsonDecode(utf8.decode(r.bodyBytes)));
  }

  Future<dynamic> get(String pfad, {String? person = 'didaktik-a'}) async {
    final r = await http.get(Uri.parse('$basis$pfad'), headers: {'x-person': ?person});
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  test('Liste enthält den Startbestand', () async {
    final liste = await get('/aufgaben') as List;
    final ordner = datenOrdner(Directory('..').absolute);
    final zahl = (jsonDecode(File('${ordner.path}/aufgaben.json').readAsStringSync()) as Map)['aufgaben'] as List;
    expect(liste, hasLength(zahl.length));
    expect(liste.every((z) => z['status'] == 'entwurf'), isTrue);
    expect(liste.first['lernwelt'], 5);
  });

  test('ohne Testperson keine Daten und keine Aktionen', () async {
    final (status, _) = await post('/aufgaben/$id/approval', {'fassung': 1}, person: null);
    expect(status, 401);
    final r = await http.get(Uri.parse('$basis/aufgaben'));
    expect(r.statusCode, 401);
  });

  test('voller Ablauf: bearbeiten, zwei Approvals, Korrektur, zurückziehen', () async {
    final d = await get('/aufgaben/$id') as Map<String, dynamic>;
    final inhalt = (d['fassungen'] as List).last['inhalt'] as Map<String, dynamic>;
    var (status, antwort) = await post('/aufgaben/$id/fassungen', {
      'basis': 1,
      'inhalt': {...inhalt, 'titel': 'Geändert'},
    });
    expect(status, 200);
    expect(antwort['fassungen'], hasLength(2));

    (status, antwort) = await post('/aufgaben/$id/approval', {'fassung': 2});
    expect(antwort['status'], 'geprueft');

    (status, antwort) = await post('/aufgaben/$id/approval', {'fassung': 2});
    expect(status, 422);
    expect(antwort['code'], 'doppelt');

    (status, antwort) = await post('/aufgaben/$id/approval', {'fassung': 2}, person: 'admin');
    expect(status, 403);

    (status, antwort) = await post('/aufgaben/$id/approval', {'fassung': 2}, person: 'didaktik-b');
    expect(antwort['status'], 'live');

    (status, antwort) = await post('/aufgaben/$id/fassungen', {
      'basis': 2,
      'inhalt': {...inhalt, 'titel': 'Korrektur'},
    });
    expect(antwort['status'], 'live');
    expect(antwort['korrektur'], isTrue);
    expect(antwort['live_fassung'], 2);

    (status, antwort) = await post('/aufgaben/$id/zurueckziehen', {'grund': 'Test'}, person: 'admin');
    expect(antwort['status'], 'zurueckgezogen');

    (status, antwort) = await post('/aufgaben/$id/wiederaufnehmen', {});
    expect(antwort['status'], 'entwurf');

    (status, antwort) = await post('/aufgaben/$id/wiederherstellen', {'nr': 1});
    expect((antwort['fassungen'] as List).last['inhalt']['titel'], inhalt['titel']);
  });

  test('veralteter Stand ergibt 409, trotzdem speichert', () async {
    final d = await get('/aufgaben/$id') as Map<String, dynamic>;
    final inhalt = (d['fassungen'] as List).last['inhalt'] as Map<String, dynamic>;
    await post('/aufgaben/$id/fassungen', {
      'basis': 1,
      'inhalt': {...inhalt, 'titel': 'A'},
    });
    var (status, antwort) = await post('/aufgaben/$id/fassungen', {
      'basis': 1,
      'inhalt': {...inhalt, 'titel': 'B'},
    }, person: 'didaktik-b');
    expect(status, 409);
    expect(antwort['code'], 'konflikt');
    (status, antwort) = await post('/aufgaben/$id/fassungen', {
      'basis': 1,
      'trotzdem': true,
      'inhalt': {...inhalt, 'titel': 'B'},
    }, person: 'didaktik-b');
    expect(status, 200);
  });

  test('Status lässt sich nicht direkt setzen', () async {
    final d = await get('/aufgaben/$id') as Map<String, dynamic>;
    final inhalt = (d['fassungen'] as List).last['inhalt'] as Map<String, dynamic>;
    final (_, antwort) = await post('/aufgaben/$id/fassungen', {
      'basis': 1,
      'inhalt': {...inhalt, 'titel': 'X', 'status': 'live'},
    });
    expect(antwort['status'], 'entwurf');
    expect(antwort['live_fassung'], isNull);
  });

  test('Import über HTTP: Bericht mit Konflikt und neuer Aufgabe', () async {
    final (status, bericht) = await post(
      '/import',
      jsonEncode({
        'quelle': 'Test',
        'aufgaben': [
          {'id': id},
          {'id': 'neu-1', 'titel': 'Neu'},
          {'titel': 'ohne id'},
        ],
      }),
    );
    expect(status, 200);
    expect(bericht['konflikte'], [id]);
    expect(bericht['uebernommen'], hasLength(1));
    expect(bericht['abgelehnt'], hasLength(1));
  });

  test('kaputte Anfragen ergeben klare Fehler', () async {
    var (status, antwort) = await post('/import', '{kaputt');
    expect(status, 400);
    (status, antwort) = await post('/aufgaben/$id/approval', '[]');
    expect(status, 400);
    (status, antwort) = await post('/aufgaben/gibtsnicht/approval', {'fassung': 1});
    expect(status, 404);
    expect(antwort['code'], 'nicht_gefunden');
  });

  test('Daten überstehen einen Neustart', () async {
    await post('/aufgaben/$id/approval', {'fassung': 1});
    await server.close(force: true);
    server = await starte();
    basis = 'http://127.0.0.1:${server.port}/api';
    final d = await get('/aufgaben/$id') as Map<String, dynamic>;
    expect(d['status'], 'geprueft');
    expect(Eintrag.fromJson(d).aktuell.approvals.single.person, 'didaktik-a');
  });

  test('Bereich für Lehrende: Store, Ablage, Rechte und Neustart', () async {
    expect((await get('/lehre/aufgaben', person: 'didaktik-a') as Map)['code'], 'keine_rechte');
    expect(await get('/lehre/aufgaben', person: 'lehrperson-schule'), isEmpty);
    final test = await get('/lehre/aufgaben/test', person: 'lehrperson-schule') as List;
    expect(test, isNotEmpty);
    expect((test.first as Map).keys, containsAll(['id', 'fassung', 'status', 'inhalt']));

    final daten = await get('/lehre/daten', person: 'lehrperson-schule') as Map<String, dynamic>;
    final d = LehrDaten.fromJson(daten);
    d.ordnerMit(standardOrdner)!.aufgaben.add((test.first as Map)['id'] as String);
    d.pakete.add(Paket(id: 'p1', titel: 'Wiederholung', erstellt: DateTime(2026, 11, 9)));
    final (status, neu) = await post('/lehre/daten', d.toJson(), person: 'lehrperson-schule');
    expect(status, 200);
    expect((neu as Map)['version'], 1);
    // Alter Stand aus einem zweiten Fenster.
    final (konflikt, _) = await post('/lehre/daten', daten, person: 'lehrperson-schule');
    expect(konflikt, 409);
    // Didaktik darf nicht schreiben, Lehrpersonen keine Aufgaben speichern.
    expect((await post('/lehre/daten', daten)).$1, 403);
    expect((await post('/aufgaben/${(test.first as Map)['id']}/approval', {'fassung': 1}, person: 'lehrperson-schule')).$1, 403);

    await server.close(force: true);
    server = await starte();
    basis = 'http://127.0.0.1:${server.port}/api';
    final wieder = LehrDaten.fromJson(await get('/lehre/daten', person: 'lehrperson-schule') as Map<String, dynamic>);
    expect(wieder.pakete.single.titel, 'Wiederholung');
    expect(wieder.gemerkt, hasLength(1));
    expect(File('${tmp.path}/lehrbereich.json').existsSync(), isTrue);
  });
}
