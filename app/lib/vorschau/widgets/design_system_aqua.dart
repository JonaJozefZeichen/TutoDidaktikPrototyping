// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/widgets/design_system_aqua.dart

import 'package:flutter/material.dart';

import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_glass.dart';

/// Glanz-Fläche des Aqua-Meadow-Stils: Verlauf mit harter Glanzkante in der
/// Mitte, dünner Rand und eine weiße Lichtkante oben (wie `inset 0 1px 0
/// #fff` in den HTML-Entwürfen). Grundbaustein für Buttons, Pills, Badges
/// und aktive Segmente.
class AquaGloss extends StatelessWidget {
  const AquaGloss({
    super.key,
    required this.gradient,
    required this.borderColor,
    required this.child,
    this.radius = 999,
    this.shadow,
    this.padding,
  });

  final Gradient gradient;
  final Color borderColor;
  final Widget child;
  final double radius;
  final List<BoxShadow>? shadow;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final inhalt = padding == null ? child : Padding(padding: padding!, child: child);
    if (!context.designSystem.glanz) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: inhalt,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow,
      ),
      child: DecoratedBox(
        // Lichtkante oben: weißer Streifen, der nach unten ausläuft.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.08],
          ),
        ),
        child: inhalt,
      ),
    );
  }
}

/// Glänzende Kugel (Avatar, Haken, Themen-Punkt): Farbverlauf von [light]
/// zur Mitte unten nach [dark], innerer Schatten unten, weißes Glanzlicht
/// oben. [child] liegt mittig darauf.
class AquaOrb extends StatelessWidget {
  const AquaOrb({super.key, required this.size, required this.light, required this.dark, this.child, this.borderColor});

  final double size;
  final Color light;
  final Color dark;
  final Widget? child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (context.designSystem.papier) {
      // Notizbuch: abgerundetes Quadrat (12 px) in Tinte, ohne Glanz.
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(size < 40 ? 9 : 12)),
        child: child,
      );
    }
    if (!context.designSystem.glanz) {
      // Schlicht: einfarbiger Kreis ohne Verlauf, Glanzlicht und Schatten.
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dark),
        child: child,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: const Alignment(0, 0.4), radius: 0.75, colors: [light, dark]),
              border: borderColor == null ? null : Border.all(color: borderColor!),
              boxShadow: const [BoxShadow(color: Color(0x4D105090), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: const SizedBox.expand(),
          ),
          // Glanzlicht oben (wie `.am-orb:after`).
          Positioned(
            top: size * 0.06,
            left: size * 0.18,
            right: size * 0.18,
            height: size * 0.4,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(100, 60)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD9FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Runder Aqua-Glanzknopf mit weißem Icon (Zurück, Optionen, Werkzeuge).
class DesignSystemAquaIconButton extends StatelessWidget {
  const DesignSystemAquaIconButton({super.key, required this.icon, this.onTap, this.size = 46, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    if (tokens.papier) {
      // Notizbuch: Milchglas-Kreis mit Tinten-Icon und blauem Tintenpunkt.
      final knopf = GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GlassSurface(
                    kreis: true,
                    child: Center(
                      child: Icon(icon, color: tokens.ink, size: size * 0.42),
                    ),
                  ),
                ),
                Positioned(
                  right: size * 0.12,
                  top: size * 0.12,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: tokens.primaryAccent, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return tooltip == null ? knopf : Tooltip(message: tooltip!, child: knopf);
    }
    final button = GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: SizedBox(
          width: size,
          height: size,
          child: AquaGloss(
            gradient: tokens.aquaGradient,
            borderColor: tokens.aquaBorder,
            shadow: tokens.buttonShadow,
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.45,
                shadows: tokens.glanz
                    ? const [Shadow(color: Color(0x8C003C78), blurRadius: 1, offset: Offset(0, 1))]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Grüne Glanz-Kugel mit Haken (an) bzw. leerer Glas-Kreis (aus) - wie die
/// Erinnerungs-Schalter im Optionen-Entwurf.
class DesignSystemAquaCheck extends StatelessWidget {
  const DesignSystemAquaCheck({super.key, required this.checked, this.size = 30});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    if (tokens.papier) {
      return SizedBox(
        width: size + 8,
        height: size,
        child: Center(
          child: Text(
            checked ? '[x]' : '[ ]',
            style: tokens
                .label(size: size * 0.55, weight: FontWeight.w700)
                .copyWith(color: checked ? tokens.success : tokens.inkMuted),
          ),
        ),
      );
    }
    if (!checked) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: tokens.pillGradient,
          border: Border.all(color: tokens.pillBorder),
        ),
      );
    }
    return AquaOrb(
      size: size,
      light: tokens.glanz ? const Color(0xFFA6E86A) : tokens.success,
      dark: tokens.glanz ? const Color(0xFF3E9F1E) : tokens.success,
      borderColor: tokens.meadowBorder,
      child: Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}
