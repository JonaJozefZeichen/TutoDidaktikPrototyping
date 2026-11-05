// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/features/aufgaben/widgets/medien.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tuto_didaktik/vorschau/design_system_controller.dart';

/// Zeigt die Medien einer Aufgabe (`medien` im Aufgaben-JSON), die ohne
/// Bilddatei auskommen: Graph eines Polynoms mit Punkten, Säulendiagramm und
/// Tabelle. Medien mit `datei` (Bilder) kommen später.
class AufgabenMedien extends StatelessWidget {
  const AufgabenMedien({super.key, required this.medien});

  final List<Map<String, dynamic>> medien;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    return Column(
      children: [
        for (final m in medien)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacingScale[0]),
            child: switch (m['typ']) {
              'graph' => _Rahmen(
                child: AspectRatio(aspectRatio: 1.25, child: CustomPaint(painter: GraphPainter.vonJson(m, tokens.ink))),
              ),
              'diagramm' => _Rahmen(
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: CustomPaint(painter: SaeulenPainter.vonJson(m, tokens.ink, tokens.primaryAccent)),
                ),
              ),
              'tabelle' => _Tabelle(
                kopf: (m['kopf'] as List).cast<String>(),
                zeilen: [for (final z in m['zeilen'] as List) (z as List).cast<String>()],
              ),
              _ => const SizedBox.shrink(),
            },
          ),
      ],
    );
  }
}

class _Rahmen extends StatelessWidget {
  const _Rahmen({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.ink.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

class _Tabelle extends StatelessWidget {
  const _Tabelle({required this.kopf, required this.zeilen});
  final List<String> kopf;
  final List<List<String>> zeilen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    final rand = BorderSide(color: tokens.ink.withValues(alpha: 0.15));
    Widget zelle(String t, {bool fett = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: tokens.body(size: 15, weight: fett ? FontWeight.w700 : FontWeight.w400),
      ),
    );
    // Wenige Spalten, viele Zeilen: transponiert (wie im Schulbuch waagrecht).
    final waagrecht = kopf.length == 2;
    final rows = waagrecht
        ? [
            for (var c = 0; c < kopf.length; c++) [kopf[c], for (final z in zeilen) z[c]],
          ]
        : [kopf, ...zeilen];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(tokens.chipRadius)),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(horizontalInside: rand, verticalInside: rand),
          children: [
            for (var r = 0; r < rows.length; r++)
              TableRow(
                children: [
                  for (var c = 0; c < rows[r].length; c++) zelle(rows[r][c], fett: waagrecht ? c == 0 : r == 0),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Koordinatensystem mit Gitter, Achsen, Beschriftung, dem Graphen eines
/// Polynoms (`polynom`: [a0, a1, a2 …]) und hervorgehobenen Punkten.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.koeffizienten,
    required this.x,
    required this.y,
    required this.punkte,
    required this.ink,
  });

  factory GraphPainter.vonJson(Map<String, dynamic> m, Color ink) {
    List<double> zahlen(Object? l) => [for (final v in (l as List? ?? const [])) (v as num).toDouble()];
    return GraphPainter(
      koeffizienten: zahlen(m['polynom']),
      x: zahlen(m['x'] ?? [-5, 5]),
      y: zahlen(m['y'] ?? [-5, 5]),
      punkte: [for (final p in (m['punkte'] as List? ?? const [])) zahlen(p)],
      ink: ink,
    );
  }

  final List<double> koeffizienten;
  final List<double> x;
  final List<double> y;
  final List<List<double>> punkte;
  final Color ink;

  double f(double v) {
    var s = 0.0;
    for (var i = koeffizienten.length - 1; i >= 0; i--) {
      s = s * v + koeffizienten[i];
    }
    return s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 22.0;
    final (x0, x1, y0, y1) = (x[0], x[1], y[0], y[1]);
    Offset p(double a, double b) => Offset(
      pad + (a - x0) / (x1 - x0) * (size.width - 2 * pad),
      size.height - pad - (b - y0) / (y1 - y0) * (size.height - 2 * pad),
    );
    final gitter = Paint()
      ..color = ink.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var a = x0.ceil(); a <= x1; a++) {
      canvas.drawLine(p(a.toDouble(), y0), p(a.toDouble(), y1), gitter);
    }
    for (var b = y0.ceil(); b <= y1; b++) {
      canvas.drawLine(p(x0, b.toDouble()), p(x1, b.toDouble()), gitter);
    }
    final achse = Paint()
      ..color = ink.withValues(alpha: 0.6)
      ..strokeWidth = 1.6;
    if (y0 <= 0 && y1 >= 0) canvas.drawLine(p(x0, 0), p(x1, 0), achse);
    if (x0 <= 0 && x1 >= 0) canvas.drawLine(p(0, y0), p(0, y1), achse);
    final stil = TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.6));
    void label(String t, Offset o) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: stil),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    final ax = (y0 <= 0 && y1 >= 0) ? 0.0 : y0;
    final ay = (x0 <= 0 && x1 >= 0) ? 0.0 : x0;
    for (var a = x0.ceil(); a <= x1; a++) {
      if (a != 0) label('$a', p(a.toDouble(), ax) + const Offset(0, 10));
    }
    for (var b = y0.ceil(); b <= y1; b++) {
      if (b != 0) label('$b', p(ay, b.toDouble()) + const Offset(-10, 0));
    }
    if (koeffizienten.isNotEmpty) {
      final pfad = Path();
      var offen = false;
      const schritte = 200;
      for (var i = 0; i <= schritte; i++) {
        final a = x0 + (x1 - x0) * i / schritte;
        final b = f(a);
        if (b < y0 - 1 || b > y1 + 1) {
          offen = false;
          continue;
        }
        final o = p(a, b.clamp(y0 - 1, y1 + 1));
        if (offen) {
          pfad.lineTo(o.dx, o.dy);
        } else {
          pfad.moveTo(o.dx, o.dy);
          offen = true;
        }
      }
      canvas.save();
      canvas.clipRect(Rect.fromPoints(p(x0, y1), p(x1, y0)));
      canvas.drawPath(
        pfad,
        Paint()
          ..color = const Color(0xFF2F6FD6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
    for (final pt in punkte) {
      canvas.drawCircle(p(pt[0], pt[1]), 4.5, Paint()..color = const Color(0xFFD64F2F));
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter old) => old.koeffizienten != koeffizienten || old.punkte != punkte;
}

/// Säulendiagramm; `y_start` > 0 erzeugt bewusst eine abgeschnittene Achse
/// (Aufgaben zu irreführenden Diagrammen).
class SaeulenPainter extends CustomPainter {
  SaeulenPainter({
    required this.beschriftungen,
    required this.werte,
    required this.yStart,
    required this.ink,
    required this.farbe,
  });

  factory SaeulenPainter.vonJson(Map<String, dynamic> m, Color ink, Color farbe) => SaeulenPainter(
    beschriftungen: (m['beschriftungen'] as List).cast<String>(),
    werte: [for (final v in m['werte'] as List) (v as num).toDouble()],
    yStart: ((m['y_start'] as num?) ?? 0).toDouble(),
    ink: ink,
    farbe: farbe,
  );

  final List<String> beschriftungen;
  final List<double> werte;
  final double yStart;
  final Color ink;
  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    const links = 34.0, unten = 22.0, oben = 8.0;
    final maxWert = werte.reduce(math.max);
    final schritt = _schritt(maxWert - yStart);
    final yMax = ((maxWert / schritt).ceil() * schritt).toDouble();
    final hoehe = size.height - unten - oben;
    double yPos(double v) => size.height - unten - (v - yStart) / (yMax - yStart) * hoehe;
    final stil = TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.65));
    void text(String t, Offset o, {bool rechts = false}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: stil),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(rechts ? tp.width : tp.width / 2, tp.height / 2));
    }

    final linie = Paint()
      ..color = ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var v = yStart; v <= yMax + 1e-9; v += schritt) {
      canvas.drawLine(Offset(links, yPos(v)), Offset(size.width, yPos(v)), linie);
      text(v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1), Offset(links - 4, yPos(v)), rechts: true);
    }
    final breite = (size.width - links) / werte.length;
    for (var i = 0; i < werte.length; i++) {
      final r = Rect.fromLTRB(links + breite * (i + 0.2), yPos(werte[i]), links + breite * (i + 0.8), yPos(yStart));
      canvas.drawRRect(
        RRect.fromRectAndCorners(r, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
        Paint()..color = farbe.withValues(alpha: 0.85),
      );
      text(beschriftungen[i], Offset(links + breite * (i + 0.5), size.height - unten / 2));
    }
  }

  static double _schritt(double spanne) {
    if (spanne <= 0) return 1;
    final roh = spanne / 5;
    final basis = math.pow(10, (math.log(roh) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 5, 10]) {
      if (roh <= m * basis) return m * basis;
    }
    return 10 * basis;
  }

  @override
  bool shouldRepaint(covariant SaeulenPainter old) => old.werte != werte;
}
