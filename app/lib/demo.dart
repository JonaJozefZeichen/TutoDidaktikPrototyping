import 'dart:async';
import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Demo ohne Server für GitHub Pages: Dieselbe `Schnittstelle` wie im Server
/// läuft direkt im Browser, mit den öffentlichen Beispielaufgaben. Änderungen
/// bleiben nur in diesem Browser.
class DemoClient extends http.BaseClient {
  DemoClient._(this._startbestand, this._listen, this._speicher) {
    _neu();
    final stand = _speicherLesen();
    if (stand != null) _schnittstelle = _baue(Bestand.eintraegeAusJson(stand), _lehreLesen());
  }

  static const _schluessel = 'didaktik_demo_stand';
  static const _schluesselLehre = 'didaktik_demo_lehrbereich';

  final String _startbestand;
  final Stammlisten _listen;
  final SharedPreferences? _speicher;
  late Schnittstelle _schnittstelle;

  static Future<DemoClient> lade() async {
    final listen = Stammlisten.ausJson(
      levels: await rootBundle.loadString('assets/beispiel/levels.json'),
      kompetenzKeys: await rootBundle.loadString('assets/beispiel/kompetenz_keys.json'),
      maturaThemen: await rootBundle.loadString('assets/beispiel/matura_themen.json'),
    );
    SharedPreferences? speicher;
    try {
      speicher = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Browser-Speicher nicht verfügbar, die Demo merkt sich nichts: $e');
    }
    return DemoClient._(await rootBundle.loadString('assets/beispiel/aufgaben.json'), listen, speicher);
  }

  Schnittstelle _baue(Map<String, Eintrag> eintraege, [Lehrbereich? lehre]) => Schnittstelle(
    Bestand(kontext: _listen.kontext, eintraege: eintraege),
    _listen,
    lehre: lehre,
    nachAenderung: _speichern,
  );

  void _neu() {
    _schnittstelle = _baue({});
    _schnittstelle.bestand.importiere(_startbestand, null);
  }

  /// Unlesbarer Stand gilt als leer, statt die Demo zu blockieren.
  Map<String, dynamic>? _speicherLesen() {
    try {
      final text = _speicher?.getString(_schluessel);
      if (text == null) return null;
      final d = jsonDecode(text) as Map<String, dynamic>;
      Bestand.eintraegeAusJson(d);
      return d;
    } catch (e) {
      debugPrint('Gespeicherter Demo-Stand unlesbar: $e');
      return null;
    }
  }

  Lehrbereich? _lehreLesen() {
    try {
      final text = _speicher?.getString(_schluesselLehre);
      return text == null ? null : Lehrbereich.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Gespeicherte Daten der Lehrpersonen unlesbar: $e');
      return null;
    }
  }

  void _speichern() {
    try {
      unawaited(_speicher?.setString(_schluessel, jsonEncode(_schnittstelle.bestand.toJson())));
      unawaited(_speicher?.setString(_schluesselLehre, jsonEncode(_schnittstelle.lehre.toJson())));
    } catch (e) {
      debugPrint('Demo-Stand nicht gespeichert: $e');
    }
  }

  /// Zurück zu den unveränderten Beispielaufgaben.
  Future<void> zuruecksetzen() async {
    _neu();
    try {
      await _speicher?.remove(_schluessel);
      await _speicher?.remove(_schluesselLehre);
    } catch (e) {
      debugPrint('Demo-Stand nicht gelöscht: $e');
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final inhalt = utf8.decode(await request.finalize().toBytes());
    final segmente = request.url.pathSegments;
    final pfad = segmente.isNotEmpty && segmente.first == 'api' ? segmente.sublist(1) : segmente;
    final SchnittstellenAntwort a;
    try {
      a = _schnittstelle.verarbeite(request.method, pfad, person: request.headers['x-person'], inhalt: inhalt);
    } catch (e) {
      return _antwort(500, {'code': 'demo', 'text': 'Fehler in der Demo: $e'}, request);
    }
    return _antwort(a.status, a.daten, request);
  }

  http.StreamedResponse _antwort(int status, Object? daten, http.BaseRequest request) {
    final bytes = utf8.encode(jsonEncode(daten));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
