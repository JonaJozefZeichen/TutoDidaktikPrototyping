import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:http/http.dart' as http;

class ApiFehler implements Exception {
  const ApiFehler(this.status, this.code, this.text);
  final int status;
  final String code;
  final String text;

  @override
  String toString() => text;
}

/// Zugriff auf den Server. Alle Regeln prüft der Server; die Oberfläche zeigt
/// nur seine Antworten.
class Api {
  Api({required this.basis, http.Client? client}) : _client = client ?? http.Client();

  /// `flutter run` läuft auf Port 8788, der Server auf 8787; sonst liefert der
  /// Server die Seite selbst aus.
  factory Api.ausAdresse(Uri seite) {
    final port = seite.port == 8788 ? 8787 : seite.port;
    return Api(basis: '${seite.scheme}://${seite.host}:$port/api');
  }

  final String basis;
  final http.Client _client;
  Person? person;

  Map<String, String> get _kopf => {'content-type': 'application/json', if (person != null) 'x-person': person!.id};

  dynamic _auswerten(http.Response r) {
    final Object? daten;
    try {
      daten = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw ApiFehler(r.statusCode, 'antwort', 'Unerwartete Antwort vom Server (${r.statusCode})');
    }
    if (r.statusCode >= 400) {
      final m = daten is Map ? daten : const {};
      throw ApiFehler(r.statusCode, '${m['code'] ?? 'server'}', '${m['text'] ?? 'Fehler ${r.statusCode}'}');
    }
    return daten;
  }

  Future<dynamic> _get(String pfad) async {
    try {
      return _auswerten(await _client.get(Uri.parse('$basis$pfad'), headers: _kopf));
    } on http.ClientException catch (e) {
      throw ApiFehler(0, 'netz', 'Der Server antwortet nicht. Läuft ./start.sh? (${e.message})');
    }
  }

  Future<dynamic> _post(String pfad, Object? body) async {
    try {
      return _auswerten(
        await _client.post(Uri.parse('$basis$pfad'), headers: _kopf, body: body is String ? body : jsonEncode(body)),
      );
    } on http.ClientException catch (e) {
      throw ApiFehler(0, 'netz', 'Der Server antwortet nicht. Läuft ./start.sh? (${e.message})');
    }
  }

  String _id(String id) => Uri.encodeComponent(id);

  Future<List<Person>> personen() async => [
    for (final p in await _get('/personen') as List) Person.fromJson(p as Map<String, dynamic>),
  ];

  Future<Stammdaten> stammdaten() async => Stammdaten.fromJson(await _get('/stammdaten') as Map<String, dynamic>);

  Future<List<Map<String, dynamic>>> aufgaben() async => (await _get('/aufgaben') as List).cast<Map<String, dynamic>>();

  Future<AufgabeDetail> aufgabe(String id) async =>
      AufgabeDetail.fromJson(await _get('/aufgaben/${_id(id)}') as Map<String, dynamic>);

  Future<AufgabeDetail> speichere(
    String id,
    Map<String, dynamic> inhalt, {
    required int basis,
    bool trotzdem = false,
  }) async => AufgabeDetail.fromJson(
    await _post('/aufgaben/${_id(id)}/fassungen', {'basis': basis, 'inhalt': inhalt, 'trotzdem': trotzdem})
        as Map<String, dynamic>,
  );

  Future<AufgabeDetail> approval(String id, int fassung) async => AufgabeDetail.fromJson(
    await _post('/aufgaben/${_id(id)}/approval', {'fassung': fassung}) as Map<String, dynamic>,
  );

  Future<AufgabeDetail> zurueckziehen(String id, String? grund) async => AufgabeDetail.fromJson(
    await _post('/aufgaben/${_id(id)}/zurueckziehen', {'grund': grund}) as Map<String, dynamic>,
  );

  Future<AufgabeDetail> wiederaufnehmen(String id) async =>
      AufgabeDetail.fromJson(await _post('/aufgaben/${_id(id)}/wiederaufnehmen', const {}) as Map<String, dynamic>);

  Future<AufgabeDetail> wiederherstellen(String id, int nr) async =>
      AufgabeDetail.fromJson(await _post('/aufgaben/${_id(id)}/wiederherstellen', {'nr': nr}) as Map<String, dynamic>);

  Future<Map<String, dynamic>> importiere(String json) async => await _post('/import', json) as Map<String, dynamic>;

  // --- Bereich für Lehrende ---

  /// Aufgaben für den Store; [auchUnfreigegebene] nur im Teststand.
  Future<List<StoreAufgabe>> storeAufgaben({bool auchUnfreigegebene = false}) async => [
    for (final z in await _get(auchUnfreigegebene ? '/lehre/aufgaben/test' : '/lehre/aufgaben') as List)
      StoreAufgabe.aus(
        (z as Map)['id'] as String,
        (z['inhalt'] as Map).cast<String, dynamic>(),
        fassung: z['fassung'] as int,
        status: z['status'] as String,
      ),
  ];

  Future<Paket> geteiltesPaket(String code) async =>
      Paket.fromJson(await _get('/lehre/code/${_id(code)}') as Map<String, dynamic>);

  Future<LehrDaten> lehrDaten() async => LehrDaten.fromJson(await _get('/lehre/daten') as Map<String, dynamic>);

  Future<LehrDaten> speichereLehrDaten(LehrDaten d) async =>
      LehrDaten.fromJson(await _post('/lehre/daten', d.toJson()) as Map<String, dynamic>);
}

class Stammdaten {
  const Stammdaten({
    required this.levels,
    required this.kompetenzen,
    required this.maturaThemen,
    this.fehlerbilder = const [],
  });

  factory Stammdaten.fromJson(Map<String, dynamic> j) => Stammdaten(
    levels: (j['levels'] as List).cast<Map<String, dynamic>>(),
    kompetenzen: (j['kompetenzen'] as List).cast<String>(),
    maturaThemen: (j['matura_themen'] as List).cast<Map<String, dynamic>>(),
    fehlerbilder: ((j['fehlerbilder'] as List?) ?? const []).cast<String>(),
  );

  final List<Map<String, dynamic>> levels;
  final List<String> kompetenzen;
  final List<Map<String, dynamic>> maturaThemen;

  /// Schon verwendete Fehlerbild-Namen, als Vorschläge.
  final List<String> fehlerbilder;

  PruefKontext get kontext =>
      PruefKontext(levels: {for (final l in levels) l['id'] as String}, kompetenzen: kompetenzen.toSet());
}

class AufgabeDetail {
  AufgabeDetail({required this.eintrag, required this.befunde});

  factory AufgabeDetail.fromJson(Map<String, dynamic> j) => AufgabeDetail(
    eintrag: Eintrag.fromJson(j),
    befunde: [for (final b in j['befunde'] as List) Befund.fromJson(b as Map<String, dynamic>)],
  );

  final Eintrag eintrag;
  final List<Befund> befunde;
}
