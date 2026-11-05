// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/features/learning_engine/term.dart
// Bis zum gemeinsamen Paket hier nicht weiterentwickeln, siehe README.

/// Kleiner Termauswerter für die Antwortprüfung ohne CAS ("Antwortprüfung
/// ohne CAS" in der Lern-Engine). Er liest Terme so, wie Schüler*innen sie
/// tippen (`1,5x+4`, `2(x-3)^2`, `x²`, `√x`), und einfache LaTeX-Reste aus dem
/// Aufgaben-JSON (`\cdot`, `\frac{a}{b}`, `\sqrt{x}`).
///
/// Zwei Terme gelten als gleichwertig, wenn sie an mehreren Zufallsstellen
/// denselben Wert haben ([gleichwertig]); so sind `4+1,5x` und `1,5x+4` gleich,
/// ohne dass ein Computeralgebra-System nötig ist. Dieselbe Auswertung
/// berechnet Lösungen aus Formeln parametrisierter Aufgaben und prüft
/// Gleichungen in Prüfregeln.
library;

import 'dart:math' as math;

typedef Belegung = Map<String, double>;

/// Ein geparster Term: auswertbar für eine Belegung der Variablen.
class Term {
  Term._(this._f, this.variablen);

  final double Function(Belegung b) _f;

  /// Vorkommende Variablen (einzelne Buchstaben bzw. Parameternamen).
  final Set<String> variablen;

  /// Wert des Terms; `NaN`, wenn eine Variable fehlt oder er nicht definiert ist.
  double wert([Belegung b = const {}]) {
    try {
      return _f(b);
    } on _Fehler {
      return double.nan;
    }
  }

  /// Liest einen Term; `null`, wenn er sich nicht lesen lässt.
  /// [namen]: Mehrbuchstabige Namen, die als eine Variable gelten
  /// (z. B. Parameter wie `grund`); sonst ist jeder Buchstabe eine Variable.
  static Term? parse(String text, {Set<String> namen = const {}}) {
    try {
      final p = _Parser(_normalisiere(text), namen);
      final f = p.ausdruck();
      if (!p.amEnde) return null;
      return Term._(f, p.variablen);
    } on _Fehler {
      return null;
    }
  }

  /// Liest eine Antwort wie `f(x) = 2x+1` oder `y=2x+1`: Ein Name links vom
  /// Gleichheitszeichen wird abgeschnitten.
  static Term? parseAntwort(String text, {Set<String> namen = const {}}) => parse(ohneLinkeSeite(text), namen: namen);
}

/// Entfernt `f(x)=`, `y=`, `K(x)=` usw. am Anfang.
String ohneLinkeSeite(String text) {
  final m = RegExp(r'^\s*[A-Za-z][A-Za-z0-9_]*\s*(\(\s*[A-Za-z]\s*\))?\s*=(.*)$').firstMatch(text);
  return m == null ? text : m.group(2)!;
}

/// Gleichung `links = rechts` als Term `links − rechts`.
Term? parseGleichung(String text, {Set<String> namen = const {}}) {
  final teile = text.split('=');
  if (teile.length != 2) return null;
  return Term.parse('(${teile[0]})-(${teile[1]})', namen: namen);
}

/// Vergleicht zwei Terme an Zufallsstellen (feste Saat, damit die Prüfung
/// reproduzierbar bleibt). Undefinierte Stellen werden übersprungen; es
/// braucht mindestens drei gültige Stellen.
bool gleichwertig(String eingabe, String loesung, {Set<String> namen = const {}}) {
  final a = Term.parseAntwort(eingabe, namen: namen);
  final b = Term.parseAntwort(loesung, namen: namen);
  if (a == null || b == null) return false;
  final vars = {...a.variablen, ...b.variablen};
  final rng = math.Random(42);
  var gueltig = 0;
  for (var n = 0; n < 12 && gueltig < 8; n++) {
    final belegung = {for (final v in vars) v: rng.nextDouble() * 8 - 3.7};
    final x = a.wert(belegung);
    final y = b.wert(belegung);
    if (!x.isFinite || !y.isFinite) continue;
    if ((x - y).abs() > 1e-6 * math.max(1, math.max(x.abs(), y.abs()))) return false;
    gueltig++;
    if (vars.isEmpty) return true;
  }
  return gueltig >= 3;
}

class _Fehler implements Exception {
  const _Fehler();
}

String _normalisiere(String s) {
  var t = s
      .replaceAll(RegExp(r'\\left|\\right'), '')
      .replaceAll(RegExp(r'\\cdot|\\times'), '*')
      .replaceAll(r'\pi', 'π')
      .replaceAll(r'\sqrt', '√')
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll(RegExp('[·×⋅]'), '*')
      .replaceAll(RegExp('[:÷]'), '/')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll(r'$', '');
  // \frac{a}{b} → ((a)/(b)), auch verschachtelt.
  while (t.contains(r'\frac')) {
    final i = t.indexOf(r'\frac');
    final (a, nachA) = _klammerInhalt(t, i + 5);
    final (b, nachB) = _klammerInhalt(t, nachA);
    t = '${t.substring(0, i)}(($a)/($b))${t.substring(nachB)}';
  }
  return t.replaceAll('{', '(').replaceAll('}', ')').replaceAll(RegExp(r'\s'), '');
}

/// Liest `{...}` ab [start] (Leerzeichen davor erlaubt) und gibt Inhalt und Position danach zurück.
(String, int) _klammerInhalt(String t, int start) {
  var i = start;
  while (i < t.length && t[i] == ' ') {
    i++;
  }
  if (i >= t.length || t[i] != '{') throw const _Fehler();
  var tiefe = 0;
  for (var j = i; j < t.length; j++) {
    if (t[j] == '{') tiefe++;
    if (t[j] == '}' && --tiefe == 0) return (t.substring(i + 1, j), j + 1);
  }
  throw const _Fehler();
}

const _funktionen = <String, double Function(double)>{
  'sqrt': math.sqrt,
  'sin': math.sin,
  'cos': math.cos,
  'tan': math.tan,
  'ln': math.log,
  'log': _log10,
  'lg': _log10,
  'exp': math.exp,
  'abs': _abs,
};

double _log10(double x) => math.log(x) / math.ln10;
double _abs(double x) => x.abs();

/// Rekursiver Abstieg: Summe → Produkt (auch implizit) → Vorzeichen → Potenz → Atom.
class _Parser {
  _Parser(this.t, this.namen);

  final String t;
  final Set<String> namen;
  final variablen = <String>{};
  int i = 0;

  bool get amEnde => i >= t.length;
  String? get _c => amEnde ? null : t[i];

  double Function(Belegung) ausdruck() {
    var f = _produkt();
    while (_c == '+' || _c == '-') {
      final op = t[i++];
      final l = f;
      final r = _produkt();
      f = op == '+' ? (b) => l(b) + r(b) : (b) => l(b) - r(b);
    }
    return f;
  }

  bool get _startetAtom {
    final c = _c;
    if (c == null) return false;
    return RegExp(r'[0-9.,(A-Za-zπ√]').hasMatch(c);
  }

  double Function(Belegung) _produkt() {
    var f = _vorzeichen();
    while (true) {
      if (_c == '*' || _c == '/') {
        final op = t[i++];
        final l = f;
        final r = _vorzeichen();
        f = op == '*' ? (b) => l(b) * r(b) : (b) => l(b) / r(b);
      } else if (_startetAtom) {
        // Implizite Multiplikation: 2x, 3(x+1), x(x+1), 2√x.
        final l = f;
        final r = _potenz();
        f = (b) => l(b) * r(b);
      } else {
        return f;
      }
    }
  }

  double Function(Belegung) _vorzeichen() {
    if (_c == '-') {
      i++;
      final f = _vorzeichen();
      return (b) => -f(b);
    }
    if (_c == '+') {
      i++;
      return _vorzeichen();
    }
    return _potenz();
  }

  double Function(Belegung) _potenz() {
    final basis = _atom();
    if (_c == '^') {
      i++;
      final hoch = _vorzeichen();
      return (b) => math.pow(basis(b), hoch(b)).toDouble();
    }
    return basis;
  }

  double Function(Belegung) _atom() {
    final c = _c;
    if (c == null) throw const _Fehler();
    if (c == '(') {
      i++;
      final f = ausdruck();
      if (_c != ')') throw const _Fehler();
      i++;
      return f;
    }
    if (c == '|') {
      i++;
      final f = ausdruck();
      if (_c != '|') throw const _Fehler();
      i++;
      return (b) => f(b).abs();
    }
    if (c == '√') {
      i++;
      final f = _potenzOhneHoch();
      return (b) => math.sqrt(f(b));
    }
    if (c == 'π') {
      i++;
      return (_) => math.pi;
    }
    if (RegExp('[0-9.,]').hasMatch(c)) return _zahl();
    if (RegExp('[A-Za-z]').hasMatch(c)) return _name();
    throw const _Fehler();
  }

  /// Argument von √ ohne Hochzahl dahinter (√x² = √(x²) wäre mehrdeutig).
  double Function(Belegung) _potenzOhneHoch() => _atom();

  double Function(Belegung) _zahl() {
    final m = RegExp(r'[0-9]*[.,]?[0-9]+|[0-9]+').matchAsPrefix(t, i);
    if (m == null) throw const _Fehler();
    i = m.end;
    final v = double.parse(m.group(0)!.replaceAll(',', '.'));
    return (_) => v;
  }

  double Function(Belegung) _name() {
    // Mehrbuchstabige Namen: Parameter, dann Funktionen, sonst ein Buchstabe.
    final rest = t.substring(i);
    final langeZuerst = [...namen]..sort((a, b) => b.length.compareTo(a.length));
    for (final n in langeZuerst) {
      if (rest.startsWith(n)) {
        i += n.length;
        variablen.add(n);
        return (b) => b[n] ?? (throw const _Fehler());
      }
    }
    for (final e in _funktionen.entries) {
      if (rest.startsWith('${e.key}(') || (rest.startsWith(e.key) && e.key == 'sqrt')) {
        i += e.key.length;
        final arg = _atom();
        return (b) => e.value(arg(b));
      }
    }
    if (rest.startsWith('pi')) {
      i += 2;
      return (_) => math.pi;
    }
    final c = t[i++];
    if (c == 'e' && !namen.contains('e')) return (_) => math.e;
    variablen.add(c);
    return (b) => b[c] ?? (throw const _Fehler());
  }
}
