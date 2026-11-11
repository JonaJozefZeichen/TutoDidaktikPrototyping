/// Die Schnittstelle des Tools, unabhängig vom Transport: Der lokale Server und
/// die Demo im Browser rufen beide diese Klasse auf und können deshalb nicht
/// auseinanderlaufen.
library;

import 'dart:convert';

import 'package:didaktik_kern/src/bestand.dart';
import 'package:didaktik_kern/src/lehre/lehrbereich.dart';
import 'package:didaktik_kern/src/modelle.dart';
import 'package:didaktik_kern/src/pruefung.dart';

/// Testpersonen statt echtem Login.
const testPersonen = [
  Person(id: 'didaktik-a', name: 'Test-Didaktik A', didaktik: true),
  Person(id: 'didaktik-b', name: 'Test-Didaktik B', didaktik: true),
  Person(id: 'admin', name: 'Test-Admin', admin: true),
  Person(id: 'lehrperson-schule', name: 'Test-Lehrperson Schule', lehrperson: true),
  Person(id: 'lehrperson-nachhilfe', name: 'Test-Nachhilfe Mindlink', lehrperson: true),
];

/// Listen für Dropdowns und Prüfung.
class Stammlisten {
  Stammlisten(this.levels, this.kompetenzen, this.maturaThemen);

  /// Aus den Dateien `levels.json`, `kompetenz_keys.json` und `matura_themen.json`.
  factory Stammlisten.ausJson({required String levels, required String kompetenzKeys, String? maturaThemen}) {
    final rohLevels = ((jsonDecode(levels) as Map<String, dynamic>)['levels'] as List).cast<Map<String, dynamic>>();
    final keys = jsonDecode(kompetenzKeys) as Map<String, dynamic>;
    return Stammlisten(
      [
        for (final l in rohLevels)
          {
            'id': l['level_id'],
            'titel': l['titel'],
            'themenbereich': l['themenbereich'],
            'lernwelt': l['lernwelt'],
            'kompetenzen': l['kompetenzen'] ?? const [],
          },
      ],
      <String>{
        ...keys.values.cast<String>(),
        for (final l in rohLevels) ...((l['kompetenzen'] as List?) ?? const []).cast<String>(),
      }.toList()..sort(),
      maturaThemen == null ? const [] : jsonDecode(maturaThemen) as List,
    );
  }

  final List<Map<String, dynamic>> levels;
  final List<String> kompetenzen;
  final List<dynamic> maturaThemen;

  PruefKontext get kontext =>
      PruefKontext(levels: {for (final l in levels) l['id'] as String}, kompetenzen: kompetenzen.toSet());

  Map<String, dynamic> toJson() => {'levels': levels, 'kompetenzen': kompetenzen, 'matura_themen': maturaThemen};
}

class SchnittstellenAntwort {
  const SchnittstellenAntwort(this.status, this.daten);
  final int status;
  final Object? daten;
}

class Schnittstelle {
  Schnittstelle(this.bestand, this.listen, {Lehrbereich? lehre, this.nachAenderung}) : lehre = lehre ?? Lehrbereich();

  final Bestand bestand;
  final Stammlisten listen;

  /// Ablagen der Lehrpersonen (Merkliste, Suchen, Pakete).
  final Lehrbereich lehre;

  /// Wird nach jeder Änderung aufgerufen, zum Speichern.
  final void Function()? nachAenderung;

  /// [pfad] sind die Teile nach `/api`, z. B. `['aufgaben', 'x', 'approval']`.
  /// Regelverstöße werden zur Antwort; andere Fehler bleiben Ausnahmen.
  SchnittstellenAntwort verarbeite(String methode, List<String> pfad, {String? person, String inhalt = ''}) {
    try {
      return SchnittstellenAntwort(200, _route(methode, pfad, person, inhalt));
    } on RegelFehler catch (e) {
      return SchnittstellenAntwort(e.status, {'code': e.code, 'text': e.text});
    }
  }

  Object? _route(String methode, List<String> pfad, String? personId, String inhalt) {
    if (methode == 'GET' && pfad.length == 1 && pfad[0] == 'personen') {
      return [for (final p in testPersonen) p.toJson()];
    }
    final p = _person(personId);
    if (methode == 'GET') {
      switch (pfad) {
        case ['stammdaten']:
          return {...listen.toJson(), 'fehlerbilder': _fehlerbildNamen()};
        case ['aufgaben']:
          return [for (final e in bestand.eintraege.values) bestand.zeile(e)];
        case ['aufgaben', final id]:
          return bestand.detail(bestand.eintrag(id));
        // Bereich für Lehrende: nur freigegebene Aufgaben; `test` zeigt im
        // Teststand auch Entwürfe, damit der Store nicht leer ist.
        case ['lehre', 'aufgaben'] || ['lehre', 'aufgaben', 'test']:
          lehre.lies(p);
          return _storeZeilen(auchUnfreigegebene: pfad.length == 3);
        case ['lehre', 'daten']:
          return lehre.lies(p).toJson();
        case ['lehre', 'code', final code]:
          return lehre.geteiltesPaket(p, code).toJson();
      }
    }
    if (methode == 'POST') {
      if (pfad case ['lehre', 'daten']) {
        final d = lehre.speichere(p, _koerper(inhalt));
        nachAenderung?.call();
        return d.toJson();
      }
      if (pfad case ['import']) {
        final bericht = bestand.importiere(inhalt, p);
        nachAenderung?.call();
        return bericht.toJson();
      }
      if (pfad case ['aufgaben', final id, final aktion]) {
        final k = _koerper(inhalt);
        final Eintrag? e = switch (aktion) {
          'fassungen' => bestand.speichere(
            id,
            _pflicht<Map<String, dynamic>>(k, 'inhalt'),
            p,
            basis: _pflicht<int>(k, 'basis'),
            trotzdem: k['trotzdem'] == true,
          ),
          'approval' => bestand.approval(id, _pflicht<int>(k, 'fassung'), p),
          'approval-zuruecknehmen' => bestand.approvalZuruecknehmen(id, _pflicht<int>(k, 'fassung'), p),
          'zurueckziehen' => bestand.zurueckziehen(id, p, grund: k['grund'] as String?),
          'wiederaufnehmen' => bestand.wiederaufnehmen(id, p),
          'wiederherstellen' => bestand.wiederherstellen(id, _pflicht<int>(k, 'nr'), p),
          _ => null,
        };
        if (e != null) {
          nachAenderung?.call();
          return bestand.detail(e);
        }
      }
    }
    throw const RegelFehler('nicht_gefunden', 'Diese Anfrage gibt es nicht', status: 404);
  }

  List<Map<String, dynamic>> _storeZeilen({required bool auchUnfreigegebene}) => [
    for (final e in bestand.eintraege.values)
      if (e.status != 'zurueckgezogen')
        if (e.liveInhalt case final live?)
          {'id': e.id, 'fassung': e.liveFassung, 'status': 'live', 'inhalt': live}
        else if (auchUnfreigegebene)
          {'id': e.id, 'fassung': e.aktuell.nr, 'status': e.status, 'inhalt': e.aktuell.inhalt},
  ];

  /// Schon verwendete Namen, als Vorschläge beim Eintippen.
  List<String> _fehlerbildNamen() {
    final namen = <String>{};
    for (final e in bestand.eintraege.values) {
      for (final i in alleItems(e.aktuell.inhalt)) {
        final fb = i['fehlerbilder'];
        if (fb is Map) namen.addAll(fb.values.whereType<String>());
      }
    }
    return namen.toList()..sort();
  }

  Person _person(String? id) {
    for (final p in testPersonen) {
      if (p.id == id) return p;
    }
    throw const RegelFehler('anmeldung', 'Bitte zuerst eine Testperson wählen', status: 401);
  }

  Map<String, dynamic> _koerper(String inhalt) {
    if (inhalt.trim().isEmpty) return const {};
    final Object? d;
    try {
      d = jsonDecode(inhalt);
    } on FormatException {
      throw const RegelFehler('json', 'Die Anfrage ist kein gültiges JSON', status: 400);
    }
    if (d is! Map<String, dynamic>) throw const RegelFehler('json', 'Die Anfrage muss ein Objekt sein', status: 400);
    return d;
  }

  T _pflicht<T>(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is T) return v;
    throw RegelFehler('json', 'Feld "$key" fehlt oder hat den falschen Typ', status: 400);
  }
}
