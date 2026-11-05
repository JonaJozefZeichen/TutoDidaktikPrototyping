import 'package:flutter/material.dart';

/// Schlichte Arbeitsoberfläche: Tuto-Blau, Open Sans, IBM Plex Mono für IDs.
/// Nur die Handy-Vorschau zeigt den Stil der App.
const tutoBlau = Color(0xFF2A62C4);
const tinte = Color(0xFF1B2433);
const grauText = Color(0xFF5B6678);
const linie = Color(0xFFDCE2EA);
const flaeche = Color(0xFFF5F7FA);
const fehlerRot = Color(0xFFB3261E);
const hinweisGelb = Color(0xFF8A6100);
const monoSchrift = 'IBM Plex Mono';

ThemeData baueThema() {
  final schema = ColorScheme.fromSeed(seedColor: tutoBlau, primary: tutoBlau, surface: Colors.white, error: fehlerRot);
  return ThemeData(
    colorScheme: schema,
    fontFamily: 'Open Sans',
    scaffoldBackgroundColor: flaeche,
    visualDensity: VisualDensity.compact,
    dividerTheme: const DividerThemeData(color: linie, space: 1, thickness: 1),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: TextStyle(color: Color(0xFF9AA5B4)),
      border: OutlineInputBorder(borderSide: BorderSide(color: linie)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: linie)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tinte),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tinte),
      bodyMedium: TextStyle(fontSize: 13.5, color: tinte),
      bodySmall: TextStyle(fontSize: 12, color: grauText),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: grauText),
    ),
  );
}

const statusNamen = {'entwurf': 'Entwurf', 'geprueft': 'Geprüft', 'live': 'Live', 'zurueckgezogen': 'Zurückgezogen'};

/// Status als Plakette; zusätzlich zur Farbe steht immer der Name dabei.
class StatusPlakette extends StatelessWidget {
  const StatusPlakette(this.status, {super.key, this.korrektur = false, this.approvals = 0});

  final String status;
  final bool korrektur;
  final int approvals;

  @override
  Widget build(BuildContext context) {
    final (grund, schrift) = switch (status) {
      'live' => (const Color(0xFFE2F3E6), const Color(0xFF1B6B32)),
      'geprueft' => (const Color(0xFFE4ECFA), tutoBlau),
      'zurueckgezogen' => (const Color(0xFFFBE6E4), fehlerRot),
      _ => (const Color(0xFFEDEFF3), grauText),
    };
    final text = korrektur ? 'Live, Korrektur $approvals/2' : statusNamen[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: grund, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: schrift),
      ),
    );
  }
}

Future<void> zeigeMeldung(BuildContext context, String text, {bool fehler = false}) async {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: fehler ? fehlerRot : tinte));
}
