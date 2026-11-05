// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/widgets/design_system_selectable_card.dart

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_aqua.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_image_placeholder.dart';

/// Auswahl-Karte für Onboarding-Fragen (Lernziel, Schulstufe, ...) - Glas-
/// Karte, ausgewählt mit Aqua-Rand und grünem Glanz-Haken.
class DesignSystemSelectableCard extends StatelessWidget {
  const DesignSystemSelectableCard({
    super.key,
    required this.label,
    required this.selected,
    this.icon = PhosphorIconsRegular.circle,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    final glass = tokens.glassCard(radius: tokens.cardRadius);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: glass.copyWith(
          border: Border.all(color: selected ? tokens.primaryAccent : tokens.glassBorder, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            DesignSystemImagePlaceholder(icon: icon, size: 36, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: tokens.body(size: 17, weight: FontWeight.w600)),
            ),
            DesignSystemAquaCheck(checked: selected),
          ],
        ),
      ),
    );
  }
}
