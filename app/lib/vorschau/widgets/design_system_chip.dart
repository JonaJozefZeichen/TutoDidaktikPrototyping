// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/widgets/design_system_chip.dart

import 'package:flutter/material.dart';

import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_aqua.dart';

/// Kleiner, auswählbarer Chip (z. B. Zeit-/Minuten-Auswahl) - helle
/// Glanz-Pill, ausgewählt dunkles Aqua mit weißer Schrift.
class DesignSystemChip extends StatelessWidget {
  const DesignSystemChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    return GestureDetector(
      onTap: onTap,
      child: AquaGloss(
        gradient: selected ? tokens.activeSegmentGradient : tokens.pillGradient,
        borderColor: selected ? tokens.aquaBorder : tokens.pillBorder,
        shadow: tokens.buttonShadow,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          label,
          style: tokens.body(weight: FontWeight.w700).copyWith(color: selected ? Colors.white : tokens.ink),
        ),
      ),
    );
  }
}
