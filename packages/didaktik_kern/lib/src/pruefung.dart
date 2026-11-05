/// Prüfung einer Aufgabe. Fehler verhindern ein Approval, Hinweise nicht.
/// Der Import nimmt auch Aufgaben mit Fehlern als Entwurf an.
library;

import 'dart:convert';

import 'package:didaktik_kern/src/aus_prototyp/content.dart';
import 'package:didaktik_kern/src/felder.dart';

class Befund {
  const Befund(this.pfad, this.text, {this.istFehler = true});

  /// Feld, zu dem der Befund gehört: `titel` oder `items/0/kompetenz`; leer = die ganze Aufgabe.
  final String pfad;
  final String text;
  final bool istFehler;

  Map<String, dynamic> toJson() => {'pfad': pfad, 'text': text, 'fehler': istFehler};

  factory Befund.fromJson(Map<String, dynamic> j) =>
      Befund(j['pfad'] as String, j['text'] as String, istFehler: j['fehler'] as bool);
}

/// Listen, gegen die Verweise geprüft werden.
class PruefKontext {
  const PruefKontext({this.levels = const {}, this.kompetenzen = const {}});

  final Set<String> levels;
  final Set<String> kompetenzen;
}

/// Alle Items einer Aufgabe, auch die in Teilaufgaben.
List<Map<String, dynamic>> alleItems(Map<String, dynamic> inhalt) => [
  for (final i in (inhalt['items'] is List ? inhalt['items'] as List : const [])) ?(i is Map<String, dynamic> ? i : null),
  for (final t in (inhalt['teilaufgaben'] is List ? inhalt['teilaufgaben'] as List : const []))
    if (t is Map && t['items'] is List)
      for (final i in t['items'] as List) ?(i is Map<String, dynamic> ? i : null),
];

bool _leer(Object? v) => v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

final _gkMuster = RegExp(r'^(AG|FA|AN|WS)\s?\d+\.\d+$');
final _kompetenzMuster = RegExp(r'^(ag|fa|an|ws)-[a-z0-9-]+$');
final _maturaThemaMuster = RegExp(r'^M(AG|FA|AN|WS)-\d+$');

void _pruefeWerte(FeldDef def, Object? wert, String pfad, List<Befund> b) {
  if (_leer(wert)) {
    if (def.pflicht) b.add(Befund(pfad, '${def.label} fehlt'));
    return;
  }
  if (def.art == FeldArt.dropdown && def.werte.isNotEmpty && !def.werte.contains(wert)) {
    b.add(Befund(pfad, '${def.label}: "$wert" ist kein erlaubter Wert'));
  }
}

/// Aufgabe prüfen. [inhalt] ist der Stand einer Fassung.
List<Befund> pruefeAufgabe(Map<String, dynamic> inhalt, {PruefKontext kontext = const PruefKontext()}) {
  final b = <Befund>[];
  for (final def in aufgabeFelder) {
    if (def.key == 'status') continue;
    _pruefeWerte(def, inhalt[def.key], def.key, b);
  }
  if (inhalt['matura_thema'] case final String t when t.isNotEmpty && !_maturaThemaMuster.hasMatch(t)) {
    b.add(const Befund('matura_thema', 'Matura-Thema folgt nicht dem Schema, z. B. MAG-04'));
  }
  if (inhalt['level'] is List && kontext.levels.isNotEmpty) {
    for (final l in inhalt['level'] as List) {
      if (!kontext.levels.contains(l)) b.add(Befund('level', 'Level "$l" gibt es nicht'));
    }
  }
  for (final feld in ['medien', 'loesung_medien']) {
    final medien = inhalt[feld];
    if (medien is! List) continue;
    for (final m in medien) {
      final geklaert = m is Map ? m['rechte_geklaert'] : null;
      if (geklaert != 'ja' && geklaert != true) {
        b.add(Befund(feld, 'Bildrechte sind nicht geklärt (${m is Map ? m['datei'] ?? m['typ'] : m})'));
      }
    }
  }

  final items = inhalt['items'] is List ? inhalt['items'] as List : const [];
  final teil = inhalt['teilaufgaben'] is List ? inhalt['teilaufgaben'] as List : const [];
  if (items.isEmpty && teil.isEmpty) b.add(const Befund('', 'Die Aufgabe hat keine Items'));

  final id = inhalt['id'];
  final fruehere = <String>{};
  for (var n = 0; n < items.length; n++) {
    final it = items[n];
    if (it is! Map<String, dynamic>) {
      b.add(Befund('items/$n', 'Item ${n + 1} ist unlesbar'));
      continue;
    }
    _pruefeItem(it, 'items/$n', id, fruehere, kontext, b);
    if (it['item_id'] case final String iid) fruehere.add(iid);
  }
  // Teilaufgaben haben kein eigenes Formular; Befunde stehen am JSON-Feld.
  for (final t in teil) {
    if (t is! Map || t['items'] is! List) {
      b.add(const Befund('teilaufgaben', 'Teilaufgabe ohne Items'));
      continue;
    }
    for (final it in t['items'] as List) {
      if (it is! Map<String, dynamic>) continue;
      final inner = <Befund>[];
      _pruefeItem(it, 'teilaufgaben', id, fruehere, kontext, inner);
      b.addAll(inner.map((x) => Befund('teilaufgaben', '${it['item_id']}: ${x.text}', istFehler: x.istFehler)));
      if (it['item_id'] case final String iid) fruehere.add(iid);
    }
  }
  _pruefeMitLoader(inhalt, b);
  return b;
}

void _pruefeItem(
  Map<String, dynamic> it,
  String pfad,
  Object? aufgabeId,
  Set<String> fruehere,
  PruefKontext kontext,
  List<Befund> b,
) {
  for (final def in itemFelder) {
    if (def.key == 'schwierigkeit_rating' || def.key == 'antwort' || def.key == 'hilfen') continue;
    _pruefeWerte(def, it[def.key], '$pfad/${def.key}', b);
  }
  final iid = it['item_id'];
  if (iid is String && aufgabeId is String && !iid.startsWith(aufgabeId)) {
    b.add(Befund('$pfad/item_id', 'Item-ID beginnt nicht mit der Aufgaben-ID'));
  }
  final op = it['operator'];
  final bereich = it['handlungsbereich'];
  if (!_leer(op)) {
    if (!alleOperatoren.contains(op)) {
      b.add(Befund('$pfad/operator', 'Operator "$op" gibt es nicht'));
    } else if (bereich is String && !operatorenFuer(bereich).contains(op)) {
      b.add(Befund('$pfad/operator', 'Operator "$op" passt nicht zu $bereich'));
    }
  }
  final kompetenz = it['kompetenz'];
  if (kompetenz is String && kompetenz.isNotEmpty) {
    if (!_kompetenzMuster.hasMatch(kompetenz)) {
      b.add(Befund('$pfad/kompetenz', 'Kompetenz folgt nicht dem Schema, z. B. fa-halbwertszeit'));
    } else if (kontext.kompetenzen.isNotEmpty && !kontext.kompetenzen.contains(kompetenz)) {
      b.add(Befund('$pfad/kompetenz', 'Neue Kompetenz, steht noch nicht in der Liste', istFehler: false));
    }
  }
  if (it['grundkompetenz'] case final String gk when gk.isNotEmpty && !_gkMuster.hasMatch(gk)) {
    b.add(Befund('$pfad/grundkompetenz', 'Grundkompetenz folgt nicht dem Schema, z. B. FA5.5'));
  }
  if (it['punkteschema'] == '0/½/1' && _leer(it['halbpunkt_regel'])) {
    b.add(Befund('$pfad/halbpunkt_regel', 'Bei 0/½/1 braucht es eine Halbpunkt-Regel'));
  }
  if (it['punkteschema'] != '0/½/1' && !_leer(it['halbpunkt_regel'])) {
    b.add(Befund('$pfad/halbpunkt_regel', 'Halbpunkt-Regel gilt nur bei 0/½/1'));
  }
  final abhaengig = it['abhaengig_von'];
  if (_leer(abhaengig)) {
    if (!_leer(it['folgefehler'])) b.add(Befund('$pfad/folgefehler', 'Folgefehler gibt es nur mit Abhängigkeit'));
  } else if (!fruehere.contains(abhaengig)) {
    b.add(Befund('$pfad/abhaengig_von', 'Abhängigkeit muss auf ein früheres Item derselben Aufgabe zeigen'));
  } else if (_leer(it['folgefehler'])) {
    b.add(Befund('$pfad/folgefehler', 'Bei einer Abhängigkeit festlegen, ob der Folgefehler gilt'));
  }
  final format = it['antwortformat'];
  final antwort = it['antwort'];
  if (antwort is! Map<String, dynamic>) {
    b.add(Befund('$pfad/antwort', 'Antwort fehlt'));
  } else if (format is String && antwortformate.contains(format)) {
    final f = pruefeAntwort(format, antwort);
    if (f != null) b.add(Befund('$pfad/antwort', f));
  }
  final hilfen = it['hilfen'];
  if (hilfen is! List || hilfen.length != 3) {
    b.add(Befund('$pfad/hilfen', 'Es braucht drei Hilfen'));
  } else {
    final texte = [for (final h in hilfen) h is Map ? h['text'] : null];
    if (texte.any(_leer)) b.add(Befund('$pfad/hilfen', 'Eine Hilfe hat keinen Text'));
    for (final h in hilfen) {
      if (h is Map && h['entwurf'] == 'ki') {
        b.add(Befund('$pfad/hilfen', 'Hilfe ${h['stufe']} ist ein KI-Entwurf, bitte prüfen', istFehler: false));
      }
    }
  }
}

/// Die Prüfung der App läuft zusätzlich, damit Tool und App dieselben Regeln
/// haben. Was schon oben gemeldet ist, wird nicht doppelt gezeigt.
void _pruefeMitLoader(Map<String, dynamic> inhalt, List<Befund> b) {
  final texte = b.map((x) => x.text).toSet();
  final items = inhalt['items'] is List ? inhalt['items'] as List : const [];
  final (:aufgabe, :fehler) = ladeZurVorschau(inhalt);
  for (final f in fehler) {
    if (f.contains('Pflichtfeld') || f.contains('abhaengig_von') || f.contains('drei Hilfen')) continue;
    if (f.contains('schwierigkeit_start') || f.contains('keine Items')) continue;
    final trenner = f.indexOf(': ');
    final kopf = trenner > 0 ? f.substring(0, trenner) : '';
    final rest = trenner > 0 ? f.substring(trenner + 2) : f;
    if (texte.contains(rest) || texte.contains(f)) continue;
    final n = items.indexWhere((i) => i is Map && i['item_id'] == kopf);
    b.add(Befund(n >= 0 ? 'items/$n/antwort' : '', rest));
  }
  if (aufgabe == null && !b.any((x) => x.istFehler)) {
    b.add(const Befund('', 'Die App kann diese Aufgabe nicht laden'));
  }
}

/// Lädt eine Aufgabe mit dem Loader der App, wie sie in der Vorschau erscheint.
({Aufgabe? aufgabe, List<String> fehler}) ladeZurVorschau(Map<String, dynamic> inhalt) {
  try {
    final kopie = {...inhalt, 'status': 'entwurf'};
    final geladen = ContentLoader().load(
      levelsJson: '{"lernwelten":[],"levels":[]}',
      aufgabenJsons: [
        jsonEncode({
          'aufgaben': [kopie],
        }),
      ],
    );
    return (aufgabe: geladen.aufgaben.isEmpty ? null : geladen.aufgaben.first, fehler: geladen.fehler);
  } catch (e) {
    return (aufgabe: null, fehler: ['Die Aufgabe ist unlesbar: $e']);
  }
}
