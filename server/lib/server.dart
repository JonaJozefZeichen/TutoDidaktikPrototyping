/// HTTP-Hülle des lokalen Testservers. Regeln und Routen liegen in
/// `Schnittstelle` und `Bestand`; hier wird nur übersetzt und gespeichert.
library;

import 'dart:convert';
import 'dart:io';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:shelf/shelf.dart';

/// Hält den Bestand und die Ablagen der Lehrpersonen und schreibt beide nach
/// jeder Änderung atomar in je eine Datei (`bestand.json`, `lehrbereich.json`).
class Speicher {
  Speicher(this.datei, {required PruefKontext kontext})
    : bestand = Bestand(
        kontext: kontext,
        eintraege: datei.existsSync()
            ? Bestand.eintraegeAusJson(jsonDecode(datei.readAsStringSync()) as Map<String, dynamic>)
            : null,
      ),
      lehre = _lehreLaden(File('${datei.parent.path}/lehrbereich.json'));

  final File datei;
  final Bestand bestand;
  final Lehrbereich lehre;

  File get lehreDatei => File('${datei.parent.path}/lehrbereich.json');

  static Lehrbereich _lehreLaden(File f) =>
      f.existsSync() ? Lehrbereich.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>) : Lehrbereich();

  void sichern() {
    _schreibe(datei, bestand.toJson());
    _schreibe(lehreDatei, lehre.toJson());
  }

  static void _schreibe(File ziel, Object daten) {
    ziel.parent.createSync(recursive: true);
    final tmp = File('${ziel.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(daten), flush: true);
    tmp.renameSync(ziel.path);
  }
}

/// `seed/privat/` (nur lokal) oder sonst die öffentlichen Beispiele.
Directory datenOrdner(Directory wurzel) {
  final privat = Directory('${wurzel.path}/seed/privat');
  return privat.existsSync() ? privat : Directory('${wurzel.path}/app/assets/beispiel');
}

Stammlisten listenAusOrdner(Directory ordner) {
  final themen = File('${ordner.path}/matura_themen.json');
  return Stammlisten.ausJson(
    levels: File('${ordner.path}/levels.json').readAsStringSync(),
    kompetenzKeys: File('${ordner.path}/kompetenz_keys.json').readAsStringSync(),
    maturaThemen: themen.existsSync() ? themen.readAsStringSync() : null,
  );
}

Response _json(Object? daten, {int status = 200}) =>
    Response(status, body: jsonEncode(daten), headers: {'content-type': 'application/json; charset=utf-8'});

/// Unerwartete Fehler werden protokolliert und einheitlich beantwortet.
Middleware _fehlerAlsJson() => (inner) => (request) async {
  try {
    return await inner(request);
  } catch (e, s) {
    stderr.writeln('Fehler bei ${request.method} ${request.url}: $e\n$s');
    return _json({'code': 'server', 'text': 'Interner Fehler: $e'}, status: 500);
  }
};

/// Erlaubt nur die Entwicklungsansicht von `flutter run` auf Port 8788.
Middleware _nurLokaleHerkunft() => (inner) => (request) async {
  final origin = request.headers['origin'];
  final erlaubt = origin == 'http://localhost:8788' || origin == 'http://127.0.0.1:8788';
  final kopf = erlaubt
      ? {
          'access-control-allow-origin': origin!,
          'access-control-allow-headers': 'content-type, x-person',
          'access-control-allow-methods': 'GET, POST, PUT, OPTIONS',
        }
      : const <String, String>{};
  if (request.method == 'OPTIONS') return Response.ok('', headers: kopf);
  return (await inner(request)).change(headers: kopf);
};

Handler baueApi(Speicher s, Stammlisten listen) {
  final schnittstelle = Schnittstelle(s.bestand, listen, lehre: s.lehre, nachAenderung: s.sichern);
  Future<Response> handler(Request q) async {
    final a = schnittstelle.verarbeite(
      q.method,
      q.url.pathSegments,
      person: q.headers['x-person'],
      inhalt: await q.readAsString(),
    );
    return _json(a.daten, status: a.status);
  }

  return const Pipeline().addMiddleware(_nurLokaleHerkunft()).addMiddleware(_fehlerAlsJson()).addHandler(handler);
}
