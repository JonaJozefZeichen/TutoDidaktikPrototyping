// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/features/learning_engine/answer_checker.dart
// Bis zum gemeinsamen Paket hier nicht weiterentwickeln, siehe README.

/// Antwortprüfer pro Format. Liefert das Ergebnis `r` (0 / 0,5 / 1 nach
/// `punkteschema`) und, falls die falsche Antwort einem gepflegten
/// Fehlerbild entspricht, dessen Tag.
///
/// Antworten der Lernenden:
/// - `mc_1aus5`/`mc_1aus6`: `int` (Index)
/// - `mc_2aus5`: `Set<int>`
/// - `lueckentext`: `List<int?>` mit 2 Indizes
/// - `zuordnung`: `Map<int, String>` Element → Buchstabe
/// - `offen_zahl`/`halboffen`: `String` (Eingabe, deutsches oder englisches Komma, auch Brüche);
///   `halboffen` mit mehreren Feldern (`{x}`, `{y}` …): `List<String>`
/// - Terme (`offen_term`, `halboffen` mit `art: term`): `String`, geprüft über `term.dart`
/// - selbst bewertete Formate (offen_text, konstruktion): `double` 0 / 0,5 / 1
///
/// Bei parametrisierten Aufgaben kommen die gezogenen Werte über `werte`
/// herein; die Lösung wird dann aus `formel` berechnet.
library;

import 'dart:math' as math;

import 'package:didaktik_kern/src/aus_prototyp/content.dart';
import 'package:didaktik_kern/src/aus_prototyp/term.dart';

class CheckResult {
  const CheckResult(this.r, {this.fehlerbild});

  /// 0, 0,5 oder 1.
  final double r;
  final String? fehlerbild;

  bool get richtig => r >= 1;
}

class AnswerChecker {
  const AnswerChecker();

  CheckResult check(Item item, Object? antwort, {Map<String, num> werte = const {}}) {
    final a = item.antwort;
    switch (item.format) {
      case 'mc_1aus5' || 'mc_1aus6':
        if (antwort is! int) return const CheckResult(0);
        if (antwort == a['richtig']) return const CheckResult(1);
        return CheckResult(0, fehlerbild: item.fehlerbilder['$antwort']);
      case 'mc_2aus5':
        if (antwort is! Set<int>) return const CheckResult(0);
        final richtig = {...(a['richtig'] as List).cast<int>()};
        return CheckResult(antwort.length == 2 && antwort.containsAll(richtig) ? 1 : 0);
      case 'lueckentext':
        if (antwort is! List) return const CheckResult(0);
        final richtig = (a['richtig'] as List).cast<int>();
        final ok = antwort.length == 2 && antwort[0] == richtig[0] && antwort[1] == richtig[1];
        return CheckResult(ok ? 1 : 0);
      case 'zuordnung':
        if (antwort is! Map<int, String>) return const CheckResult(0);
        final richtig = (a['richtig'] as Map).map((k, v) => MapEntry(int.parse('$k'), '$v'));
        final treffer = richtig.entries.where((e) => antwort[e.key] == e.value).length;
        if (treffer == richtig.length) return const CheckResult(1);
        if (item.punkteschema == '0/½/1' && treffer >= 2) return const CheckResult(0.5);
        return const CheckResult(0);
      case 'offen_term':
        return CheckResult(antwort is String && gleichwertig(antwort, a['term'] as String) ? 1 : 0);
      case 'offen_zahl' || 'halboffen':
        if (a['art'] == 'term') {
          final eingabe = antwort is List ? (antwort.isEmpty ? '' : '${antwort.first}') : '$antwort';
          return CheckResult(gleichwertig(eingabe, (a['term'] ?? a['wert']) as String) ? 1 : 0);
        }
        final eingaben = antwort is List ? [for (final e in antwort) '$e'] : [antwort is String ? antwort : ''];
        if (a['pruefregel'] is List) return CheckResult(_regelnErfuellt(a['pruefregel'] as List, eingaben) ? 1 : 0);
        final loesung = loesungsWert(item, werte);
        if (loesung is List) return CheckResult(_listeRichtig(eingaben, loesung.cast<num>(), a) ? 1 : 0);
        final eingabe = eingaben.first;
        final x = parseZahl(eingabe);
        if (x == null || loesung is! num) return const CheckResult(0);
        final wert = loesung.toDouble();
        final tol = ((a['toleranz'] as num?) ?? 0).toDouble();
        if ((x - wert).abs() <= tol + 1e-9) return const CheckResult(1);
        if (gerundetRichtig(eingabe, x, wert)) return const CheckResult(1);
        for (final e in item.fehlerbilder.entries) {
          final f = parseZahl(e.key);
          if (f != null && (x - f).abs() <= tol + 1e-9) return CheckResult(0, fehlerbild: e.value);
        }
        return const CheckResult(0);
      default:
        // Selbstbewertung (offen_text, konstruktion).
        if (antwort is num) return CheckResult(antwort.toDouble().clamp(0, 1));
        return const CheckResult(0);
    }
  }
}

/// Ein Feld richtig: innerhalb der Toleranz oder richtig gerundet.
bool _zahlRichtig(String eingabe, double wert, double tol) {
  final x = parseZahl(eingabe);
  if (x == null) return false;
  return (x - wert).abs() <= tol + 1e-9 || gerundetRichtig(eingabe, x, wert);
}

/// Mehrere Felder (Zahlenpaar, Lösungsliste); bei `reihenfolge_egal` in beliebiger Reihenfolge.
bool _listeRichtig(List<String> eingaben, List<num> werte, Map<String, dynamic> a) {
  if (eingaben.length != werte.length) return false;
  final tol = ((a['toleranz'] as num?) ?? 0).toDouble();
  final egal = a['reihenfolge_egal'] == 'ja' || a['reihenfolge_egal'] == true;
  if (!egal) {
    for (var i = 0; i < werte.length; i++) {
      if (!_zahlRichtig(eingaben[i], werte[i].toDouble(), tol)) return false;
    }
    return true;
  }
  // Jede Eingabe einem noch freien Wert zuordnen.
  final frei = [for (final w in werte) w.toDouble()];
  for (final e in eingaben) {
    final i = frei.indexWhere((w) => _zahlRichtig(e, w, tol));
    if (i < 0) return false;
    frei.removeAt(i);
  }
  return true;
}

/// Prüfregeln: alle Regeln der Liste müssen stimmen. Die Eingaben bilden
/// einen Vektor bzw. die Werte von x, y, z.
bool _regelnErfuellt(List regeln, List<String> eingaben) {
  final v = [for (final e in eingaben) parseZahl(e)];
  if (v.any((x) => x == null)) return false;
  final u = v.cast<double>();
  double laenge(List<double> w) => math.sqrt(w.fold(0.0, (s, x) => s + x * x));
  for (final r in regeln.cast<Map>()) {
    final tol = ((r['toleranz'] as num?) ?? 1e-6).toDouble();
    switch (r['regel']) {
      case 'orthogonal_zu':
        final w = (r['vektor'] as List).map((x) => (x as num).toDouble()).toList();
        if (laenge(u) < 1e-9 || w.length != u.length) return false;
        var skalar = 0.0;
        for (var i = 0; i < u.length; i++) {
          skalar += u[i] * w[i];
        }
        if (skalar.abs() > tol * math.max(1, laenge(u) * laenge(w))) return false;
      case 'parallel_zu':
        final w = (r['vektor'] as List).map((x) => (x as num).toDouble()).toList();
        if (laenge(u) < 1e-9 || w.length != u.length) return false;
        for (var i = 0; i < u.length; i++) {
          for (var j = i + 1; j < u.length; j++) {
            if ((u[i] * w[j] - u[j] * w[i]).abs() > tol * math.max(1, laenge(u) * laenge(w))) return false;
          }
        }
      case 'laenge':
        final t = ((r['toleranz'] as num?) ?? 0.01).toDouble();
        if ((laenge(u) - (r['wert'] as num).toDouble()).abs() > t) return false;
      case 'erfuellt_gleichung':
        final g = parseGleichung(r['gleichung'] as String);
        if (g == null) return false;
        final belegung = {for (var i = 0; i < u.length && i < eingabeFeldNamen.length; i++) eingabeFeldNamen[i]: u[i]};
        final d = g.wert(belegung);
        if (!d.isFinite || d.abs() > math.max(tol, 1e-6)) return false;
      default:
        return false;
    }
  }
  return true;
}

/// Lange oder periodische Ergebnisse (mehr als zwei Nachkommastellen, z. B.
/// 33,333…) gelten auch gerundet als richtig, sobald mindestens eine
/// Nachkommastelle eingegeben ist und richtig gerundet wurde: 33,3 oder
/// 33,33 statt 33,333… (Jona, 02.11.2026). Kurze Werte wie 13,92 € bleiben
/// streng.
bool gerundetRichtig(String eingabe, double x, double wert) {
  final lang = (wert * 100 - (wert * 100).roundToDouble()).abs() > 1e-6;
  if (!lang) return false;
  final m = RegExp(r'[.,](\d+)').firstMatch(eingabe.replaceAll(RegExp(r'\s'), ''));
  if (m == null || eingabe.contains('/')) return false;
  final stellen = m.group(1)!.length;
  return (x - wert).abs() <= 0.5 * math.pow(10, -stellen) + 1e-9;
}

/// Liest eine Zahl aus einer Eingabe: `2,5`, `2.5`, `−3`, `1/2`, `20 %`,
/// `1 200`. Einheiten am Ende werden ignoriert.
double? parseZahl(String s) {
  final t = s.trim().replaceAll('−', '-').replaceAll('–', '-').replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^(-?\d[\d.,]*)(?:/(-?\d[\d.,]*))?').firstMatch(t);
  if (m == null) return null;
  final z = _dezimal(m.group(1)!);
  if (m.group(2) == null) return z;
  final n = _dezimal(m.group(2)!);
  if (z == null || n == null || n == 0) return null;
  return z / n;
}

double? _dezimal(String t) {
  if (t.contains(',') && t.contains('.')) {
    // 1.234,5 → Tausenderpunkt
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(t.replaceAll(',', '.'));
}
