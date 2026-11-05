import 'dart:convert';
import 'dart:io';

import 'package:didaktik_server/server.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:tuto_didaktik/api.dart';

/// `seed/privat/` lokal, sonst die öffentlichen Beispiele.
final datenPfad = datenOrdner(Directory('..').absolute);

/// Anzahl Aufgaben im Startbestand.
int get aufgabenZahl =>
    ((jsonDecode(File('${datenPfad.path}/aufgaben.json').readAsStringSync()) as Map)['aufgaben'] as List).length;

/// Testet die Oberfläche gegen den echten Server-Code, nur ohne Netzwerk.
Api testApi() {
  final tmp = Directory.systemTemp.createTempSync('didaktik_app');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final daten = listenAusOrdner(datenPfad);
  final speicher = Speicher(File('${tmp.path}/bestand.json'), kontext: daten.kontext);
  speicher.bestand.importiere(File('${datenPfad.path}/aufgaben.json').readAsStringSync(), null);
  final router = Router()..mount('/api/', baueApi(speicher, daten));
  final client = MockClient((http.Request q) async {
    final r = await router.call(shelf.Request(q.method, q.url, headers: q.headers, body: q.bodyBytes));
    final bytes = await r.read().expand((b) => b).toList();
    return http.Response.bytes(Uint8List.fromList(bytes), r.statusCode, headers: r.headers);
  });
  return Api(basis: 'http://test.local/api', client: client);
}

/// Echte Schriften, damit die Bilder wie im Browser aussehen.
Future<void> ladeSchriften() async {
  Future<void> lade(String familie, List<String> pfade) async {
    final l = FontLoader(familie);
    for (final p in pfade) {
      l.addFont(rootBundle.load(p));
    }
    await l.load();
  }

  await lade('Open Sans', ['assets/fonts/OpenSans-Variable.ttf']);
  await lade('IBM Plex Mono', ['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-SemiBold.ttf']);
  await lade('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
}
