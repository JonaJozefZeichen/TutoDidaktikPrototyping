/// Der Aufgabenbestand mit allen Regeln der Freigabe ("Design Document;
/// Didaktik-Tool", Invarianten 21 und 22). Der Server ruft nur diese Klasse
/// auf, damit die Regeln auch bei direkten Anfragen gelten.
library;

import 'dart:convert';

import 'package:didaktik_kern/src/modelle.dart';
import 'package:didaktik_kern/src/pruefung.dart';

class Bestand {
  Bestand({this.kontext = const PruefKontext(), DateTime Function()? uhr, Map<String, Eintrag>? eintraege})
    : _uhr = uhr ?? DateTime.now,
      eintraege = eintraege ?? {};

  final PruefKontext kontext;
  final DateTime Function() _uhr;
  final Map<String, Eintrag> eintraege;

  Eintrag eintrag(String id) =>
      eintraege[id] ?? (throw RegelFehler('nicht_gefunden', 'Aufgabe $id gibt es nicht', status: 404));

  List<Befund> befunde(Map<String, dynamic> inhalt) => pruefeAufgabe(inhalt, kontext: kontext);

  // --- Import ---

  /// Importiert eine Aufgabendatei (`quelle`, `aufgaben`). Alles startet als
  /// `entwurf`, bestehende IDs bleiben unberührt, unvollständige Aufgaben
  /// werden angenommen. [person] ist `null` beim Startbestand.
  ImportBericht importiere(String json, Person? person) {
    if (person != null && !person.darfBearbeiten) {
      throw const RegelFehler('keine_rechte', 'Diese Rolle darf nicht importieren', status: 403);
    }
    final Object? daten;
    try {
      daten = jsonDecode(json);
    } on FormatException catch (e) {
      throw RegelFehler('json', 'Die Datei ist kein gültiges JSON: ${e.message}', status: 400);
    }
    if (daten is! Map<String, dynamic> || daten['aufgaben'] is! List) {
      throw const RegelFehler('format', 'Die Datei braucht eine Liste "aufgaben"', status: 400);
    }
    final bericht = ImportBericht(quelle: daten['quelle'] as String?);
    final belegteItems = _alleItemIds();
    final inDatei = <String>{};
    var nr = 0;
    for (final roh in daten['aufgaben'] as List) {
      nr++;
      final id = roh is Map ? roh['id'] : null;
      if (roh is! Map<String, dynamic> || id is! String || id.trim().isEmpty) {
        bericht.abgelehnt.add({'wo': 'Eintrag $nr', 'grund': 'hat keine id'});
        continue;
      }
      if (!inDatei.add(id)) {
        bericht.abgelehnt.add({'wo': id, 'grund': 'id steht mehrfach in der Datei'});
        continue;
      }
      if (eintraege.containsKey(id)) {
        bericht.konflikte.add(id);
        continue;
      }
      final inhalt = _kopie(roh)..remove('status');
      final ergaenzt = _ergaenzeItemIds(inhalt);
      final doppelt = [
        for (final i in alleItems(inhalt))
          if (belegteItems.contains(i['item_id'])) i['item_id'],
      ];
      if (doppelt.isNotEmpty) {
        bericht.abgelehnt.add({'wo': id, 'grund': 'item_id schon vergeben: ${doppelt.join(', ')}'});
        continue;
      }
      belegteItems.addAll(alleItems(inhalt).map((i) => i['item_id'] as String));
      final am = _uhr();
      eintraege[id] = Eintrag(
        id: id,
        status: 'entwurf',
        fassungen: [Fassung(nr: 1, inhalt: inhalt, quelle: 'import', von: person?.id, am: am)],
        ereignisse: [
          Ereignis(art: 'import', person: person?.id, am: am, fassung: 1, text: bericht.quelle),
        ],
      );
      final fehler = befunde(inhalt).where((b) => b.istFehler).length;
      bericht.uebernommen.add({'id': id, 'fehler': fehler, 'item_ids_ergaenzt': ergaenzt});
    }
    return bericht;
  }

  /// Items ohne `item_id` bekommen eine, weil das Feld im Tool nur lesbar ist.
  int _ergaenzeItemIds(Map<String, dynamic> inhalt) {
    var n = 0;
    var laufend = 0;
    for (final i in alleItems(inhalt)) {
      laufend++;
      final v = i['item_id'];
      if (v is! String || v.trim().isEmpty) {
        i['item_id'] = '${inhalt['id']}-i$laufend';
        n++;
      }
    }
    return n;
  }

  Set<String> _alleItemIds({String? ausser}) => {
    for (final e in eintraege.values)
      if (e.id != ausser)
        for (final f in e.fassungen)
          for (final i in alleItems(f.inhalt))
            if (i['item_id'] case final String s) s,
  };

  // --- Bearbeiten ---

  /// Speichert eine neue Fassung ohne Approvals. Liegt [basis] hinter der
  /// aktuellen Fassung, gibt es einen Konflikt, außer bei [trotzdem]
  /// (Warnung statt Sperre). Ohne Änderung entsteht keine Fassung.
  Eintrag speichere(
    String id,
    Map<String, dynamic> inhalt,
    Person person, {
    required int basis,
    bool trotzdem = false,
    String quelle = 'bearbeitung',
  }) {
    if (!person.darfBearbeiten) {
      throw const RegelFehler('keine_rechte', 'Diese Rolle darf nicht bearbeiten', status: 403);
    }
    final e = eintrag(id);
    if (basis != e.aktuell.nr && !trotzdem) {
      throw RegelFehler(
        'konflikt',
        'Jemand hat diese Aufgabe inzwischen geändert (Fassung ${e.aktuell.nr} von ${e.aktuell.von ?? 'Import'}).',
        status: 409,
      );
    }
    final neu = _kopie(inhalt)..remove('status');
    _pruefeIdSchutz(e, neu);
    if (jsonEncode(neu) == jsonEncode(e.aktuell.inhalt)) return e;
    _neueFassung(e, neu, quelle, person);
    return e;
  }

  void _pruefeIdSchutz(Eintrag e, Map<String, dynamic> neu) {
    if (neu['id'] != e.id) {
      throw const RegelFehler('id_schutz', 'Die Aufgaben-ID darf sich nicht ändern');
    }
    final ids = <String>[];
    for (final i in alleItems(neu)) {
      final v = i['item_id'];
      if (v is! String || v.isEmpty) throw const RegelFehler('id_schutz', 'Jedes Item braucht eine item_id');
      ids.add(v);
    }
    if (ids.toSet().length != ids.length) {
      throw const RegelFehler('id_schutz', 'Eine item_id kommt doppelt vor');
    }
    final fehlend = e.geschuetzteItems.difference(ids.toSet());
    if (fehlend.isNotEmpty) {
      throw RegelFehler(
        'id_schutz',
        'Diese Items waren schon live und dürfen nicht entfernt werden: ${fehlend.join(', ')}',
      );
    }
    final vorher = {
      for (final f in e.fassungen)
        for (final i in alleItems(f.inhalt)) i['item_id'],
    };
    final belegt = _alleItemIds(ausser: e.id);
    for (final v in ids) {
      if (!vorher.contains(v) && belegt.contains(v)) {
        throw RegelFehler('id_schutz', 'Die item_id $v gehört zu einer anderen Aufgabe');
      }
    }
  }

  void _neueFassung(Eintrag e, Map<String, dynamic> inhalt, String quelle, Person person, {String? text}) {
    final am = _uhr();
    final nr = e.aktuell.nr + 1;
    e.fassungen.add(Fassung(nr: nr, inhalt: inhalt, quelle: quelle, von: person.id, am: am));
    e.ereignisse.add(Ereignis(art: quelle, person: person.id, am: am, fassung: nr, text: text));
    // Eine freigegebene Aufgabe bleibt live, bis die Korrektur zwei Approvals hat.
    if (e.status != 'live') e.status = 'entwurf';
  }

  /// Macht eine frühere Fassung als neue Fassung wieder aktuell.
  Eintrag wiederherstellen(String id, int nr, Person person) {
    final e = eintrag(id);
    final alt = e.fassungen.where((f) => f.nr == nr).firstOrNull;
    if (alt == null) throw RegelFehler('nicht_gefunden', 'Fassung $nr gibt es nicht', status: 404);
    return speichere(id, alt.inhalt, person, basis: e.aktuell.nr, quelle: 'wiederherstellung');
  }

  // --- Freigabe ---

  /// Gibt ein Approval auf [fassung]. Das erste setzt `geprueft`, das zweite
  /// von einer anderen Person `live`.
  Eintrag approval(String id, int fassung, Person person) {
    if (!person.darfFreigeben) {
      throw const RegelFehler('keine_rechte', 'Nur das Didaktik-Team gibt Approvals', status: 403);
    }
    final e = eintrag(id);
    if (e.status == 'zurueckgezogen') {
      throw const RegelFehler('zurueckgezogen', 'Die Aufgabe ist zurückgezogen. Erst wieder aufnehmen.');
    }
    if (fassung != e.aktuell.nr) {
      throw const RegelFehler(
        'konflikt',
        'Die Aufgabe wurde inzwischen geändert. Bitte die aktuelle Fassung ansehen.',
        status: 409,
      );
    }
    if (e.status == 'live' && !e.hatKorrektur) {
      throw const RegelFehler('schon_live', 'Diese Fassung ist schon freigegeben');
    }
    final f = e.aktuell;
    if (f.approvals.any((a) => a.person == person.id)) {
      throw const RegelFehler('doppelt', 'Das zweite Approval muss von einer anderen Person kommen');
    }
    final fehler = befunde(f.inhalt).where((b) => b.istFehler).toList();
    if (fehler.isNotEmpty) {
      throw RegelFehler('pruefung', 'Vor einem Approval sind noch ${fehler.length} Fehler zu beheben');
    }
    final am = _uhr();
    f.approvals.add(Approval(person: person.id, am: am));
    e.ereignisse.add(Ereignis(art: 'approval', person: person.id, am: am, fassung: f.nr));
    if (f.approvals.length >= 2) {
      e.status = 'live';
      e.liveFassung = f.nr;
      e.geschuetzteItems.addAll(alleItems(f.inhalt).map((i) => i['item_id'] as String));
      e.ereignisse.add(Ereignis(art: 'live', person: person.id, am: am, fassung: f.nr));
    } else if (e.status == 'entwurf') {
      e.status = 'geprueft';
    }
    return e;
  }

  /// Nimmt das eigene Approval auf [fassung] zurück, solange die Fassung
  /// noch nicht durch zwei Approvals live ist. Ohne verbleibendes Approval
  /// wird `geprueft` wieder `entwurf`; eine Live-Aufgabe mit Korrektur bleibt live.
  Eintrag approvalZuruecknehmen(String id, int fassung, Person person) {
    if (!person.darfFreigeben) {
      throw const RegelFehler('keine_rechte', 'Nur das Didaktik-Team gibt Approvals', status: 403);
    }
    final e = eintrag(id);
    if (fassung != e.aktuell.nr) {
      throw const RegelFehler(
        'konflikt',
        'Die Aufgabe wurde inzwischen geändert. Bitte die aktuelle Fassung ansehen.',
        status: 409,
      );
    }
    final f = e.aktuell;
    if (e.liveFassung == f.nr) {
      throw const RegelFehler('schon_live', 'Diese Fassung ist schon live; zurücknehmen geht nicht mehr');
    }
    final eigenes = f.approvals.where((a) => a.person == person.id).firstOrNull;
    if (eigenes == null) {
      throw const RegelFehler('kein_approval', 'Auf dieser Fassung gibt es kein Approval von dir');
    }
    f.approvals.remove(eigenes);
    e.ereignisse.add(Ereignis(art: 'approval_zurueck', person: person.id, am: _uhr(), fassung: f.nr));
    if (e.status == 'geprueft' && f.approvals.isEmpty) e.status = 'entwurf';
    return e;
  }

  /// Nimmt eine Live-Aufgabe sofort aus der App. Eine einzelne Person darf das.
  Eintrag zurueckziehen(String id, Person person, {String? grund}) {
    if (!person.darfZurueckziehen) {
      throw const RegelFehler('keine_rechte', 'Diese Rolle darf nicht zurückziehen', status: 403);
    }
    final e = eintrag(id);
    if (e.status != 'live') {
      throw const RegelFehler('nicht_live', 'Zurückziehen geht nur bei Aufgaben, die live sind');
    }
    e.status = 'zurueckgezogen';
    e.liveFassung = null;
    e.ereignisse.add(
      Ereignis(art: 'zurueckgezogen', person: person.id, am: _uhr(), fassung: e.aktuell.nr, text: grund),
    );
    return e;
  }

  /// Holt eine zurückgezogene Aufgabe als neue Fassung und `entwurf` zurück.
  /// In die App kommt sie nur wieder mit zwei neuen Approvals.
  Eintrag wiederaufnehmen(String id, Person person) {
    if (!person.darfBearbeiten) {
      throw const RegelFehler('keine_rechte', 'Diese Rolle darf nicht bearbeiten', status: 403);
    }
    final e = eintrag(id);
    if (e.status != 'zurueckgezogen') {
      throw const RegelFehler('nicht_zurueckgezogen', 'Die Aufgabe ist nicht zurückgezogen');
    }
    _neueFassung(e, _kopie(e.aktuell.inhalt), 'wiederaufnahme', person);
    return e;
  }

  // --- Ansichten ---

  /// Kurzfassung für Listen und Übersicht.
  Map<String, dynamic> zeile(Eintrag e) {
    final inhalt = e.aktuell.inhalt;
    final items = alleItems(inhalt);
    final alle = befunde(inhalt);
    final stufe = inhalt['schulstufe'];
    return {
      'id': e.id,
      'titel': inhalt['titel'],
      'status': e.status,
      'korrektur': e.hatKorrektur,
      'approvals': e.aktuell.approvals.length,
      'approval_von': [for (final a in e.aktuell.approvals) a.person],
      'fassung': e.aktuell.nr,
      'fehler': alle.where((b) => b.istFehler).length,
      'hinweise': alle.where((b) => !b.istFehler).length,
      'lernwelt': stufe is int ? stufe - 4 : null,
      'herkunft': inhalt['herkunft'],
      'level': inhalt['level'] is List ? inhalt['level'] : const [],
      'themenbereiche': {for (final i in items) ?i['inhaltsbereich']}.toList(),
      'kompetenzen': {for (final i in items) ?i['kompetenz']}.toList(),
      'formate': {for (final i in items) ?i['antwortformat']}.toList(),
      'aufgabenstellung': items.isEmpty ? '' : items.first['aufgabenstellung'],
      'bearbeitet_von': {for (final f in e.fassungen) ?f.von}.toList(),
      'zuletzt_am': e.ereignisse.last.am.toIso8601String(),
    };
  }

  /// Volle Sicht für den Editor.
  Map<String, dynamic> detail(Eintrag e) => {
    ...e.toJson(),
    'korrektur': e.hatKorrektur,
    'befunde': [for (final b in befunde(e.aktuell.inhalt)) b.toJson()],
  };

  Map<String, dynamic> toJson() => {
    'eintraege': [for (final e in eintraege.values) e.toJson()],
  };

  static Map<String, Eintrag> eintraegeAusJson(Map<String, dynamic> j) => {
    for (final e in j['eintraege'] as List)
      (e as Map<String, dynamic>)['id'] as String: Eintrag.fromJson(e),
  };

  static Map<String, dynamic> _kopie(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
}
