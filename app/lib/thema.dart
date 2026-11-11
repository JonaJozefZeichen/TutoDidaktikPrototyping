import 'package:flutter/material.dart';

/// Arbeitsoberfläche in der Designsprache "schwebende Pill": hell, schwarz/weiß
/// mit Grautönen, weiche Kacheln statt Linien, große Radien. Schrift Inter.
/// Nur die Handy-Vorschau zeigt den Stil der App.
const schrift = 'Inter';

/// Nur für rohes JSON und Code-Eingaben; IDs und Zahlen stehen in [schrift]
/// mit Tabellenziffern ([ziffern]).
const codeSchrift = 'IBM Plex Mono';
const ziffern = [FontFeature.tabularFigures()];

/// Fast schwarz: Text und Hauptaktion (gefüllte Knöpfe, aktive Navigation).
const tinte = Color(0xFF111113);
const grauText = Color(0xFF6B6B73);

/// Hintergrund der Seiten: weiß, Ruhe durch Weißraum statt Karten.
const flaeche = Colors.white;

/// Graue Kachel innerhalb weißer Flächen (Felder, Zweitknöpfe, Zeilen beim Darüberfahren).
const kachel = Color(0xFFF4F4F5);
const kachelAktiv = Color(0xFFEBEBED);

/// Hauchdünne Trennlinien (Tabellenzeilen, Spalten).
const linie = Color(0xFFF0F0F2);

/// Einziger Farbakzent: Links und Auswahl, sparsam.
const tutoBlau = Color(0xFF2A62C4);
const fehlerRot = Color(0xFFC62828);
const hinweisGelb = Color(0xFF8A6100);
const erfolgGruen = Color(0xFF1B6B32);

const radiusFeld = 12.0;
const radiusKarte = 20.0;

/// Weicher Schatten für schwebende Elemente (Navigation, Toolbar, Dialoge).
const schwebeSchatten = [
  BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
];

/// Weiße Fläche. Auf weißem Grund ohne Rand und Schatten unsichtbar, also flach;
/// [schwebend] nur für echte Overlays.
BoxDecoration karte({double radius = radiusKarte, bool schwebend = false}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: schwebend ? schwebeSchatten : null,
);

ThemeData baueThema() {
  final schema = ColorScheme.fromSeed(
    seedColor: tinte,
    primary: tinte,
    onPrimary: Colors.white,
    secondary: tutoBlau,
    surface: Colors.white,
    surfaceContainerHighest: kachel,
    error: fehlerRot,
  );
  const pill = StadiumBorder();
  final feldRand = OutlineInputBorder(borderRadius: BorderRadius.circular(radiusFeld), borderSide: BorderSide.none);
  return ThemeData(
    colorScheme: schema,
    fontFamily: schrift,
    scaffoldBackgroundColor: flaeche,
    visualDensity: VisualDensity.compact,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(color: linie, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: kachel,
      hoverColor: kachelAktiv,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(color: Color(0xFF9A9AA3)),
      border: feldRand,
      enabledBorder: feldRand,
      disabledBorder: feldRand,
      focusedBorder: feldRand.copyWith(borderSide: const BorderSide(color: tinte, width: 1.5)),
      errorBorder: feldRand.copyWith(borderSide: const BorderSide(color: fehlerRot)),
      focusedErrorBorder: feldRand.copyWith(borderSide: const BorderSide(color: fehlerRot, width: 1.5)),
    ),
    // Hauptaktion: schwarze Pill mit weißer Schrift.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        backgroundColor: tinte,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kachel,
        disabledForegroundColor: const Color(0xFFAAAAB2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontFamily: schrift, fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    // Zweitaktionen: graue Kachel ohne Rahmen.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        side: BorderSide.none,
        backgroundColor: kachel,
        foregroundColor: tinte,
        disabledForegroundColor: const Color(0xFFAAAAB2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontFamily: schrift, fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: tinte,
        textStyle: const TextStyle(fontFamily: schrift, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: tinte)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: pill,
        side: BorderSide.none,
        backgroundColor: kachel,
        selectedBackgroundColor: tinte,
        selectedForegroundColor: Colors.white,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide.none,
      backgroundColor: kachel,
      selectedColor: tinte,
      secondarySelectedColor: tinte,
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontFamily: schrift, fontSize: 12.5, fontWeight: FontWeight.w500, color: tinte),
      secondaryLabelStyle: const TextStyle(fontFamily: schrift, fontSize: 12.5, color: Colors.white),
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: Color(0xFFBDBDC4), width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tinte : kachelAktiv),
      thumbColor: WidgetStateProperty.all(Colors.white),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kachel,
      indicatorShape: StadiumBorder(),
      selectedIconTheme: IconThemeData(color: tinte, size: 20),
      unselectedIconTheme: IconThemeData(color: grauText, size: 20),
      selectedLabelTextStyle: TextStyle(fontFamily: schrift, fontSize: 11.5, fontWeight: FontWeight.w600, color: tinte),
      unselectedLabelTextStyle: TextStyle(fontFamily: schrift, fontSize: 11.5, color: grauText),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: tinte,
      unselectedLabelColor: grauText,
      indicatorColor: tinte,
      dividerColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: ShapeDecoration(color: tinte, shape: StadiumBorder()),
      textStyle: TextStyle(fontFamily: schrift, fontSize: 12, color: Colors.white),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      waitDuration: Duration(milliseconds: 400),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: tinte),
    // Dialoge: weiß, großer Radius, weicher Schatten, ohne Material-3-Tönung.
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(fontFamily: schrift, fontSize: 18, fontWeight: FontWeight.w700, color: tinte),
      contentTextStyle: const TextStyle(fontFamily: schrift, fontSize: 13.5, color: tinte, height: 1.45),
    ),
    cardTheme: CardThemeData(
      color: kachel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Meldungen schweben als schwarze Pill unten mittig.
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: tinte,
      shape: StadiumBorder(),
      contentTextStyle: TextStyle(fontFamily: schrift, fontSize: 13, color: Colors.white),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: tinte, letterSpacing: -0.4),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: tinte, letterSpacing: -0.3),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tinte, letterSpacing: -0.1),
      bodyMedium: TextStyle(fontSize: 13.5, color: tinte, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: grauText, height: 1.35),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: grauText),
    ),
  );
}

const statusNamen = {'entwurf': 'Entwurf', 'geprueft': 'Geprüft', 'live': 'Live', 'zurueckgezogen': 'Zurückgezogen'};

/// Status als Punkt mit Text, ohne Hintergrund; zusätzlich zur Farbe steht immer der Name dabei.
class StatusPlakette extends StatelessWidget {
  const StatusPlakette(this.status, {super.key, this.korrektur = false, this.approvals = 0});

  final String status;
  final bool korrektur;
  final int approvals;

  @override
  Widget build(BuildContext context) {
    final punkt = switch (status) {
      'live' => const Color(0xFF22A45D),
      'geprueft' => tutoBlau,
      'zurueckgezogen' => fehlerRot,
      _ => const Color(0xFFA1A1AA),
    };
    final text = korrektur ? 'Live, Korrektur $approvals/2' : statusNamen[status] ?? status;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: punkt, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tinte),
          ),
        ],
      ),
    );
  }
}

/// Schwebende weiße Pill, z. B. für Navigation und Werkzeugleisten.
class SchwebePill extends StatelessWidget {
  const SchwebePill({super.key, required this.child, this.padding = const EdgeInsets.all(6), this.radius = 28});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: karte(radius: radius, schwebend: true),
    child: child,
  );
}

/// Leiser Hinweis: graue Pill mit gelbem Punkt statt gelbem Balken. Der volle
/// Text steht im Tooltip, [aktion] ist optional ein leiser Link daneben.
class LeiserHinweis extends StatelessWidget {
  const LeiserHinweis(this.text, {super.key, this.erklaerung, this.aktion});

  final String text;
  final String? erklaerung;
  final Widget? aktion;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
      decoration: const ShapeDecoration(color: kachel, shape: StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFFE0A100), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: grauText),
            ),
          ),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: erklaerung == null ? pill : Tooltip(message: erklaerung, child: pill),
        ),
        if (aktion != null) ...[const SizedBox(width: 4), aktion!],
      ],
    );
  }
}

/// Filter- und Zähler-Chip: grauer Text mit Zahl, aktiv schwarz auf hellgrau.
class ZaehlerChip extends StatelessWidget {
  const ZaehlerChip({super.key, required this.label, required this.zahl, this.aktiv = false, this.onTap});

  final String label;
  final int zahl;
  final bool aktiv;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: aktiv ? kachelAktiv : kachel,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(color: aktiv ? tinte : grauText, fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: '$zahl',
                style: const TextStyle(color: tinte, fontWeight: FontWeight.w600, fontFeatures: ziffern),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    ),
  );
}

/// Angemeldete Testperson als Pill mit Initialen und "Wechseln".
class PersonPill extends StatelessWidget {
  const PersonPill({super.key, required this.name, required this.rolle, required this.onWechseln});

  final String name;
  final String rolle;
  final VoidCallback onWechseln;

  @override
  Widget build(BuildContext context) {
    final initialen = name
        .replaceFirst('Test-', '')
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: kachel,
            child: Text(
              initialen,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tinte),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: rolle,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: tinte),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(onPressed: onWechseln, child: const Text('Wechseln')),
        ],
      ),
    );
  }
}

Future<void> zeigeMeldung(BuildContext context, String text, {bool fehler = false}) async {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: fehler ? fehlerRot : tinte));
}
