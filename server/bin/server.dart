import 'dart:io';

import 'package:didaktik_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

/// Startet den Testserver auf http://127.0.0.1:8787. Beim ersten Start wird
/// der Startbestand importiert: `seed/privat/`, wenn vorhanden, sonst die Beispiele.
Future<void> main(List<String> args) async {
  final wurzel = Directory(args.isNotEmpty ? args.first : '..').absolute;
  final ordner = datenOrdner(wurzel);
  final listen = listenAusOrdner(ordner);
  final speicher = Speicher(File('${wurzel.path}/server/data/bestand.json'), kontext: listen.kontext);
  if (speicher.bestand.eintraege.isEmpty) {
    final bericht = speicher.bestand.importiere(File('${ordner.path}/aufgaben.json').readAsStringSync(), null);
    speicher.sichern();
    stdout.writeln('Startbestand importiert: ${bericht.uebernommen.length} Aufgaben als Entwurf.');
  }
  final api = Router()..mount('/api/', baueApi(speicher, listen));
  final web = Directory('${wurzel.path}/app/build/web');
  final handler = web.existsSync()
      ? Cascade().add(api.call).add(createStaticHandler(web.path, defaultDocument: 'index.html')).handler
      : api.call;
  final server = await io.serve(
    const Pipeline().addHandler(handler),
    InternetAddress.loopbackIPv4,
    8787,
  );
  stdout.writeln('Didaktik-Tool (Test): http://${server.address.host}:${server.port}');
}
