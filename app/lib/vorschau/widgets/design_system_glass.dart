// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/widgets/design_system_glass.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:tuto_didaktik/vorschau/design_system.dart';
import 'package:tuto_didaktik/vorschau/design_system_controller.dart';

/// Milchglas-Fläche: Unschärfe dahinter ([DesignSystemTokens.glasBlur]),
/// halbtransparentes Weiß und heller Rand. Ohne Blur (Schlicht, Aqua) eine
/// normale Glas-Karte ([DesignSystemTokens.glassCard]).
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius, this.padding, this.kreis = false});

  final Widget child;
  final double? radius;
  final EdgeInsetsGeometry? padding;

  /// Runde Form (z. B. Zurück-Knopf).
  final bool kreis;

  @override
  Widget build(BuildContext context) {
    final t = context.designSystem;
    final r = radius ?? t.cardRadius;
    final inhalt = padding == null ? child : Padding(padding: padding!, child: child);
    if (t.glasBlur <= 0) {
      return DecoratedBox(
        decoration: kreis
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(color: t.glassBorder),
              )
            : t.glassCard(radius: r),
        child: inhalt,
      );
    }
    final form = kreis
        ? const BoxDecoration(shape: BoxShape.circle)
        : BoxDecoration(borderRadius: BorderRadius.circular(r));
    final flaeche = DecoratedBox(
      decoration: form.copyWith(
        color: const Color(0x80FFFFFF),
        border: Border.all(color: t.glassBorder),
      ),
      child: inhalt,
    );
    return DecoratedBox(
      decoration: form.copyWith(boxShadow: t.cardShadow),
      child: kreis
          ? ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: t.glasBlur / 2, sigmaY: t.glasBlur / 2),
                child: flaeche,
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: t.glasBlur / 2, sigmaY: t.glasBlur / 2),
                child: flaeche,
              ),
            ),
    );
  }
}

/// Karte mit Abschnittstitel. Im Notizbuch-Stil Milchglas mit dem Titel als
/// `┤ TITEL ├` im oberen Rand (IBM Plex Mono), sonst Glas-Karte mit einer
/// kleinen Überschrift.
class DesignSystemCard extends StatelessWidget {
  const DesignSystemCard({super.key, this.titel, required this.child, this.padding = const EdgeInsets.all(16)});

  final String? titel;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.designSystem;
    final titel = this.titel;
    if (!t.papier) {
      return GlassSurface(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titel != null) ...[
              Text(
                titel,
                style: t.body(size: 13, weight: FontWeight.w700).copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: titel == null ? 0 : 9),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassSurface(padding: titel == null ? padding : padding.add(const EdgeInsets.only(top: 6)), child: child),
          if (titel != null) Positioned(top: -9, left: 18, child: BoxTitle(titel)),
        ],
      ),
    );
  }
}

/// `┤ TITEL ├` in Mono auf einem hellen Etikett, das den Kartenrand unterbricht.
class BoxTitle extends StatelessWidget {
  const BoxTitle(this.titel, {super.key});
  final String titel;

  @override
  Widget build(BuildContext context) {
    final t = context.designSystem;
    return DecoratedBox(
      // Helles Glas-Etikett, damit der Titel den Kartenrand unterbricht.
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '┤ ${titel.toUpperCase()} ├',
          style: t.label(size: 12, weight: FontWeight.w600).copyWith(color: t.inkMuted, height: 1.4),
        ),
      ),
    );
  }
}
