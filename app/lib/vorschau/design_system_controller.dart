// Vereinfachte Fassung von lib/design_system/design_system_controller.dart aus
// dem Prototyp: ohne Speichern und ohne dart:io, damit sie im Browser läuft.
// Die Vorschau zeigt immer den Standard-Stil der App (Notizbuch).
import 'package:flutter/widgets.dart';

import 'package:tuto_didaktik/vorschau/design_system.dart';

extension DesignSystemContext on BuildContext {
  DesignSystemTokens get designSystem => notizbuchTokens;
}
