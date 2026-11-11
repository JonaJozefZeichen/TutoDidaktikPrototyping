import 'package:flutter/material.dart';

/// Außenmaße des Geräts in logischen Pixeln; Seitenverhältnis wie ein
/// aktuelles 6,1-Zoll-iPhone (ca. 0,47).
const iphoneBreite = 390.0;
const iphoneHoehe = 820.0;

/// Fläche, die der Inhalt bekommt: Bildschirm ohne Statusleiste und
/// Home-Indikator.
const iphoneInhalt = Size(_bildschirmBreite, _bildschirmHoehe - _statusHoehe - _homeHoehe);

const _knopfBreite = 3.0;
const _gehaeuseBreite = iphoneBreite - 2 * _knopfBreite;
const _rahmen = 12.0; // Titan + schwarzer Displayrand
const _bildschirmBreite = _gehaeuseBreite - 2 * _rahmen;
const _bildschirmHoehe = iphoneHoehe - 2 * _rahmen;
const _statusHoehe = 52.0;
const _homeHoehe = 22.0;

/// iPhone-Mockup mit Titanrahmen, Seitentasten, Dynamic Island, Statusleiste
/// und Home-Indikator, komplett im Code gezeichnet (keine Bilddateien).
/// [hintergrund] füllt den ganzen Bildschirm, also auch hinter der
/// Statusleiste; [child] liegt im Bereich darunter ([iphoneInhalt]).
class IPhoneRahmen extends StatelessWidget {
  const IPhoneRahmen({super.key, required this.child, this.hintergrund});

  final Widget child;
  final Gradient? hintergrund;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: iphoneBreite,
      height: iphoneHoehe,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Seitentasten links: Aktionstaste, lauter, leiser; rechts: Seitentaste.
          const _Taste(links: true, oben: 150, hoehe: 34),
          const _Taste(links: true, oben: 212, hoehe: 62),
          const _Taste(links: true, oben: 290, hoehe: 62),
          const _Taste(links: false, oben: 240, hoehe: 98),
          Positioned(left: _knopfBreite, top: 0, width: _gehaeuseBreite, height: iphoneHoehe, child: _gehaeuse()),
        ],
      ),
    );
  }

  Widget _gehaeuse() => DecoratedBox(
    // Titanrahmen: leichter Verlauf mit hellen Kanten.
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(64),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD7D4CE), Color(0xFF8D8A84), Color(0xFFB9B6B0), Color(0xFF6F6C67)],
        stops: [0, 0.35, 0.7, 1],
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x1F000000), blurRadius: 60, offset: Offset(0, 24), spreadRadius: -14),
        BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF0A0A0B), borderRadius: BorderRadius.circular(61)),
        child: Padding(
          padding: const EdgeInsets.all(_rahmen - 3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(52),
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, gradient: hintergrund),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        const SizedBox(height: _statusHoehe, child: _Statusleiste()),
                        // Eigenes Theme: Der Bildschirm zeigt die App, nicht den Stil des Tools.
                        Expanded(
                          child: Theme(data: _appThema, child: child),
                        ),
                        const SizedBox(height: _homeHoehe),
                      ],
                    ),
                  ),
                  // Dynamic Island
                  Positioned(
                    top: 11,
                    left: (_bildschirmBreite - 122) / 2,
                    child: Container(
                      width: 122,
                      height: 35,
                      decoration: const ShapeDecoration(color: Colors.black, shape: StadiumBorder()),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 14),
                      // Kameralinse
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFF2B3446), Color(0xFF0B0E14)],
                            center: Alignment(-0.3, -0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Home-Indikator
                  Positioned(
                    bottom: 8,
                    left: (_bildschirmBreite - 136) / 2,
                    child: Container(
                      width: 136,
                      height: 5,
                      decoration: const ShapeDecoration(color: Color(0xE6111111), shape: StadiumBorder()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Material-Grundlage im Bildschirm wie vor dem Redesign des Tools (Tuto-Blau,
/// Open Sans), damit Knöpfe und Felder im Handy nicht den Tool-Stil annehmen.
final _appThema = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A62C4), primary: const Color(0xFF2A62C4)),
  fontFamily: 'Open Sans',
  visualDensity: VisualDensity.compact,
);

class _Taste extends StatelessWidget {
  const _Taste({required this.links, required this.oben, required this.hoehe});

  final bool links;
  final double oben;
  final double hoehe;

  @override
  Widget build(BuildContext context) => Positioned(
    left: links ? 0 : null,
    right: links ? null : 0,
    top: oben,
    child: Container(
      width: _knopfBreite + 2,
      height: hoehe,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(colors: [Color(0xFF7D7A75), Color(0xFFC4C1BB), Color(0xFF8D8A84)]),
      ),
    ),
  );
}

/// Uhrzeit links, Empfang, WLAN und Akku rechts, wie auf iOS.
class _Statusleiste extends StatelessWidget {
  const _Statusleiste();

  static const _farbe = Color(0xFF111111);

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(34, 17, 28, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '9:41',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _farbe,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Spacer(),
        Padding(padding: EdgeInsets.only(top: 3), child: _Empfang()),
        SizedBox(width: 6),
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: SizedBox(width: 17, height: 12, child: CustomPaint(painter: _WlanMaler())),
        ),
        SizedBox(width: 6),
        Padding(padding: EdgeInsets.only(top: 3), child: _Akku()),
      ],
    ),
  );
}

class _Empfang extends StatelessWidget {
  const _Empfang();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final h in const [4.0, 6.5, 9.0, 11.5]) ...[
        Container(
          width: 3,
          height: h,
          decoration: BoxDecoration(color: _Statusleiste._farbe, borderRadius: BorderRadius.circular(1)),
        ),
        const SizedBox(width: 1.5),
      ],
    ],
  );
}

class _Akku extends StatelessWidget {
  const _Akku();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 25,
        height: 12,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x66111111)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            child: Container(
              decoration: BoxDecoration(color: _Statusleiste._farbe, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 1),
      Container(
        width: 1.5,
        height: 4,
        decoration: const BoxDecoration(
          color: Color(0x66111111),
          borderRadius: BorderRadius.horizontal(right: Radius.circular(1)),
        ),
      ),
    ],
  );
}

/// WLAN-Symbol: drei Bögen und ein Punkt, unabhängig von Icon-Schriften.
class _WlanMaler extends CustomPainter {
  const _WlanMaler();

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = Offset(size.width / 2, size.height);
    final stift = Paint()
      ..color = _Statusleiste._farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    const start = -3.14159 / 2 - 0.82;
    const winkel = 1.64;
    for (final r in [size.height - 1.2, size.height * 0.62]) {
      canvas.drawArc(Rect.fromCircle(center: mitte, radius: r), start, winkel, false, stift);
    }
    final punkt = Path()
      ..moveTo(mitte.dx, mitte.dy)
      ..arcTo(Rect.fromCircle(center: mitte, radius: size.height * 0.3), start, winkel, false)
      ..close();
    canvas.drawPath(punkt, Paint()..color = _Statusleiste._farbe);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
