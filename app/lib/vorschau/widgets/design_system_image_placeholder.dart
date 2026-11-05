// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/widgets/design_system_image_placeholder.dart

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_aqua.dart';

/// Ersetzt echte Bilder/Icons/Avatare/Illustrationen, solange es dafür noch
/// keinen echten Asset gibt. Rund als blaue Glanz-Kugel mit weißem Icon (wie
/// die Avatare im Aqua-Meadow-Entwurf), eckig als zart getönte Glas-Fläche.
class DesignSystemImagePlaceholder extends StatelessWidget {
  const DesignSystemImagePlaceholder({
    super.key,
    this.size = 48,
    this.circle = false,
    this.icon = PhosphorIconsRegular.image,
  });

  final double size;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    if (circle) {
      return AquaOrb(
        size: size,
        light: Color.lerp(tokens.primaryAccent, Colors.white, 0.45)!,
        dark: tokens.primaryAccent,
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: tokens.pillGradient,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.pillBorder),
      ),
      child: Icon(icon, color: tokens.primaryAccent, size: size * 0.5),
    );
  }
}
