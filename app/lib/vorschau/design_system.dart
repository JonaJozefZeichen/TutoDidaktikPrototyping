// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/design_system/design_system.dart

import 'package:flutter/material.dart';

/// Schrift aller drei Stile für Überschriften und Text (Jona, 04.11.2026:
/// überall dieselbe). Hier ändern, um die Schrift der ganzen App zu wechseln;
/// neue Schriften zuerst nach `assets/fonts/` und in `pubspec.yaml` eintragen.
const tutoSchrift = 'Open Sans';

/// Schrift aller Stile für Zahlen, Labels und die ASCII-Titel (`┤ TITEL ├`).
const tutoLabelSchrift = 'IBM Plex Mono';

/// Die visuellen Design-Tokens (Farben, Verläufe, Fonts, Formen, Spacing)
/// eines Stils. Drei Instanzen, umschaltbar über den Stil-Knopf
/// ([DesignSystemController]): [notizbuchTokens] (Standard seit 04.11.2026),
/// [schlichtTokens] und [aquaMeadowTokens].
@immutable
class DesignSystemTokens {
  const DesignSystemTokens({
    required this.name,
    required this.skyColors,
    required this.skyStops,
    required this.hillLight,
    required this.hillDark,
    required this.surface,
    required this.glassGradient,
    required this.glassBorder,
    required this.success,
    required this.reward,
    required this.primaryAccent,
    required this.aquaGradient,
    required this.aquaBorder,
    required this.meadowGradient,
    required this.meadowBorder,
    required this.meadowInk,
    required this.pillGradient,
    required this.pillBorder,
    required this.activeSegmentGradient,
    required this.alertGradient,
    required this.ink,
    required this.inkMuted,
    required this.divider,
    required this.warning,
    required this.headingShadow,
    required this.headingFontFamily,
    required this.bodyFontFamily,
    required this.cardRadius,
    required this.chipRadius,
    required this.secondaryButtonRadius,
    required this.spacingScale,
    required this.navBarColor,
    required this.navBarShadow,
    required this.cardShadow,
    required this.buttonShadow,
    this.glanz = true,
    this.papier = false,
    this.glasBlur = 0,
    this.labelFontFamily = tutoLabelSchrift,
  });

  final String name;

  /// Himmel von oben nach unten (Farben und ihre Positionen 0-1).
  final List<Color> skyColors;
  final List<double> skyStops;

  /// Die zwei Wiesen-Hügel am unteren Rand: (Kern, Rand).
  final (Color, Color) hillLight;
  final (Color, Color) hillDark;

  /// Undurchsichtige, leicht bläuliche Fläche - für Popups, Bottom-Sheets
  /// und überall, wo kein Glas-Verlauf passt.
  final Color surface;

  /// Glas-Karte: weißer Verlauf mit Glanzkante in der Mitte, weißer Rand.
  final LinearGradient glassGradient;
  final Color glassBorder;

  final Color success;
  final Color reward;

  /// Farbe für primäre Handlungsaufforderungen und Auswahl (Aqua-Blau).
  final Color primaryAccent;

  /// Glanz-Knöpfe: Aqua (runde Icon-Knöpfe), Wiese (Haupt-Button mit
  /// dunkelgrüner Schrift), Pill (Sekundär, Segment-Leiste, Badges).
  final LinearGradient aquaGradient;
  final Color aquaBorder;
  final LinearGradient meadowGradient;
  final Color meadowBorder;
  final Color meadowInk;
  final LinearGradient pillGradient;
  final Color pillBorder;

  /// Aktives Segment im Umschalter (dunkles Aqua).
  final LinearGradient activeSegmentGradient;

  /// Rotes Glanz-Badge (z. B. Überfälliges).
  final LinearGradient alertGradient;

  final Color ink;

  /// Zweite Textfarbe (Hinweise, Platzhalter, Untertitel).
  final Color inkMuted;

  /// Trennlinie zwischen Listen-Zeilen.
  final Color divider;

  final Color warning;

  /// Schatten unter weißen Überschriften auf dem Himmel.
  final List<Shadow> headingShadow;

  final String headingFontFamily;
  final String bodyFontFamily;

  final double cardRadius;
  final double chipRadius;

  /// Radius des Sekundär-Buttons (Primär-Buttons sind immer Pill-Form).
  final double secondaryButtonRadius;

  /// 8pt-Raster-Werte.
  final List<double> spacingScale;

  /// Hintergrundfarbe der schwebenden Bottom-Nav-Pille (teiltransparent).
  final Color navBarColor;

  /// Weicher Schatten der Bottom-Nav-Pille.
  final List<BoxShadow> navBarShadow;

  /// Blauer, weicher Schlagschatten für Karten und Listen-Kacheln.
  final List<BoxShadow> cardShadow;

  /// Schatten unter Glanz-Knöpfen.
  final List<BoxShadow> buttonShadow;

  /// `true`: Glanz-Effekte von Aqua Meadow (Lichtkanten, Glanzkugeln,
  /// Himmel mit Wolken und Wiese). `false`: alles flach und schlicht.
  final bool glanz;

  /// `true`: Notizbuch-Stil - heller Himmel, Milchglas-Karten mit
  /// ASCII-Titeln (`┤ TITEL ├`), Mono-Labels.
  final bool papier;

  /// Unschärfe hinter Glas-Flächen ([GlassSurface]); 0 = kein Blur.
  final double glasBlur;

  /// Schrift für Labels, Zahlen und Daten.
  final String labelFontFamily;

  LinearGradient get backgroundGradient =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: skyColors, stops: skyStops);

  /// Glas-Karte mit Radius [radius] (Standard [cardRadius]) - Verlauf,
  /// weißer Rand, blauer Schatten.
  BoxDecoration glassCard({double? radius}) => BoxDecoration(
    gradient: glassGradient,
    borderRadius: BorderRadius.circular(radius ?? cardRadius),
    border: Border.all(color: glassBorder),
    boxShadow: cardShadow,
  );

  TextStyle heading({double size = 24, FontWeight weight = FontWeight.w700}) {
    return TextStyle(
      fontFamily: headingFontFamily,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: ink,
    );
  }

  /// Weiße Überschrift mit Schatten, direkt auf dem Himmel (im schlichten
  /// Stil dunkel ohne Schatten).
  TextStyle skyHeading({double size = 30, FontWeight weight = FontWeight.w800}) => papier
      ? heading(size: size, weight: FontWeight.w600)
      : glanz
      ? heading(size: size, weight: weight).copyWith(color: Colors.white, shadows: headingShadow)
      : heading(size: size, weight: weight);

  TextStyle body({double size = 16, FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontFamily: bodyFontFamily,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: ink,
    );
  }

  /// Label, Zahl oder Datum (im Notizbuch-Stil in Mono).
  TextStyle label({double size = 13, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: labelFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: ink,
    letterSpacing: papier ? 0.2 : null,
  );
}

/// Die konkreten Werte des "Aqua Meadow"-Stils (glänzende Frutiger-Aero-Optik,
/// Himmel, Wiese, Glanz-Knöpfe). Farbwerte 1:1 aus den `AquaMeadow-*.html`-Entwürfen.
const aquaMeadowTokens = DesignSystemTokens(
  name: 'Aqua Meadow',
  skyColors: [Color(0xFF2A9BE6), Color(0xFF6CC7F6), Color(0xFFC5EDFF)],
  skyStops: [0, 0.45, 0.75],
  hillLight: (Color(0xFF3FA52A), Color(0xFF6CC93A)),
  hillDark: (Color(0xFF2E8F23), Color(0xFF59B92F)),
  surface: Color(0xFFF2F9FE),
  glassGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE0FFFFFF), Color(0xA8FFFFFF), Color(0x99F0FAFF), Color(0xB8FFFFFF)],
    stops: [0, 0.5, 0.51, 1],
  ),
  glassBorder: Color(0xF2FFFFFF),
  success: Color(0xFF4AB21C),
  reward: Color(0xFFE06A12),
  primaryAccent: Color(0xFF1890DE),
  aquaGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8FE1FF), Color(0xFF38B4F1), Color(0xFF1890DE), Color(0xFF3AB0F0)],
    stops: [0, 0.48, 0.52, 1],
  ),
  aquaBorder: Color(0xFF0E6FB8),
  meadowGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFB6F07A), Color(0xFF6CCB34), Color(0xFF4AB21C), Color(0xFF69C934)],
    stops: [0, 0.48, 0.52, 1],
  ),
  meadowBorder: Color(0xFF2E8A17),
  meadowInk: Color(0xFF103A06),
  pillGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFEAF6FD), Color(0xFFD5ECF9), Color(0xFFEEF8FE)],
    stops: [0, 0.5, 0.51, 1],
  ),
  pillBorder: Color(0xFF9CC8E6),
  activeSegmentGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A86D2), Color(0xFF1872C4), Color(0xFF0E5FAE), Color(0xFF1A6FBE)],
    stops: [0, 0.48, 0.52, 1],
  ),
  alertGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF8A7A), Color(0xFFE2382A), Color(0xFFC9241A), Color(0xFFE04236)],
    stops: [0, 0.5, 0.51, 1],
  ),
  ink: Color(0xFF0F2C45),
  inkMuted: Color(0xFF3E6280),
  divider: Color(0x5978B4DC),
  warning: Color(0xFFE2382A),
  headingShadow: [
    Shadow(color: Color(0x73003C78), blurRadius: 6, offset: Offset(0, 2)),
    Shadow(color: Color(0x99003C78), blurRadius: 1),
  ],
  headingFontFamily: tutoSchrift,
  bodyFontFamily: tutoSchrift,
  cardRadius: 18,
  chipRadius: 14,
  secondaryButtonRadius: 999,
  spacingScale: [8, 16, 32, 48, 64],
  navBarColor: Color(0xD9FFFFFF),
  navBarShadow: [BoxShadow(color: Color(0x40105090), blurRadius: 24, offset: Offset(0, 8))],
  cardShadow: [BoxShadow(color: Color(0x40105090), blurRadius: 24, offset: Offset(0, 8))],
  buttonShadow: [BoxShadow(color: Color(0x59105090), blurRadius: 8, offset: Offset(0, 3))],
);

LinearGradient _flach(Color c) => LinearGradient(colors: [c, c]);

/// Schlichter Stil (02.11.2026, Jonas Wunsch nach dem Gerätetest): helle,
/// einfarbige Flächen, weiße Karten mit dünnem Rand, eine Akzentfarbe, flache
/// Knöpfe ohne Glanz, kaum Schatten.
final schlichtTokens = DesignSystemTokens(
  name: 'Schlicht',
  skyColors: const [Color(0xFFF4F5F7), Color(0xFFF4F5F7), Color(0xFFF4F5F7)],
  skyStops: const [0, 0.5, 1],
  hillLight: const (Color(0xFFF4F5F7), Color(0xFFF4F5F7)),
  hillDark: const (Color(0xFFF4F5F7), Color(0xFFF4F5F7)),
  surface: const Color(0xFFFFFFFF),
  glassGradient: _flach(const Color(0xFFFFFFFF)),
  glassBorder: const Color(0xFFE1E4E8),
  success: const Color(0xFF2E9E4F),
  reward: const Color(0xFFD9822B),
  primaryAccent: const Color(0xFF2F6FD6),
  aquaGradient: _flach(const Color(0xFF2F6FD6)),
  aquaBorder: const Color(0xFF2F6FD6),
  meadowGradient: _flach(const Color(0xFF2F6FD6)),
  meadowBorder: const Color(0xFF2F6FD6),
  meadowInk: const Color(0xFFFFFFFF),
  pillGradient: _flach(const Color(0xFFF1F3F5)),
  pillBorder: const Color(0xFFD5D9DE),
  activeSegmentGradient: _flach(const Color(0xFF2F6FD6)),
  alertGradient: _flach(const Color(0xFFD64545)),
  ink: const Color(0xFF1C1F24),
  inkMuted: const Color(0xFF5F6670),
  divider: const Color(0xFFE6E8EB),
  warning: const Color(0xFFD64545),
  headingShadow: const [],
  headingFontFamily: tutoSchrift,
  bodyFontFamily: tutoSchrift,
  cardRadius: 12,
  chipRadius: 10,
  secondaryButtonRadius: 12,
  spacingScale: const [8, 16, 32, 48, 64],
  navBarColor: const Color(0xF2FFFFFF),
  navBarShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
  cardShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1))],
  buttonShadow: const [],
  glanz: false,
);

/// Notizbuch-Stil (04.11.2026, nach Jonas Vorlage "a well-kept ledger on a
/// desk", ohne Punktraster und Schnipsel): heller Himmel statt Papier,
/// Milchglas-Karten, ASCII-Titel im Kartenrand,
/// Schriften wie in allen Stilen ([tutoSchrift], [tutoLabelSchrift]). Akzent ist
/// das Tuto-Blau, eine Spur dunkler (#2A62C4), damit blauer Text auf den
/// hellen Flächen 4,5 : 1 erreicht.
final notizbuchTokens = DesignSystemTokens(
  name: 'Notizbuch',
  // Heller Himmel in Tuto-Blau (oben kräftiger, unten fast weiß), damit die
  // Insel weiter wie im Meer unter dem Himmel wirkt (Jona, 04.11.2026).
  skyColors: const [Color(0xFFB5D8F3), Color(0xFFD6EAF8), Color(0xFFF1F7FC)],
  skyStops: const [0, 0.45, 1],
  hillLight: const (Color(0xFFF1F7FC), Color(0xFFF1F7FC)),
  hillDark: const (Color(0xFFF1F7FC), Color(0xFFF1F7FC)),
  surface: const Color(0xFFF7FAFD),
  glassGradient: _flach(const Color(0xB8FFFFFF)),
  glassBorder: const Color(0xCCFFFFFF),
  success: const Color(0xFF3E8A52),
  reward: const Color(0xFFC2822A),
  primaryAccent: const Color(0xFF2A62C4),
  aquaGradient: _flach(const Color(0xFF2A62C4)),
  aquaBorder: const Color(0xFF2A62C4),
  meadowGradient: _flach(const Color(0xFF2A62C4)),
  meadowBorder: const Color(0xFF2A62C4),
  meadowInk: const Color(0xFFFFFFFF),
  pillGradient: _flach(const Color(0x8CFFFFFF)),
  pillBorder: const Color(0xFFD3DFEA),
  activeSegmentGradient: _flach(const Color(0xFF2A62C4)),
  alertGradient: _flach(const Color(0xFFA8352A)),
  ink: const Color(0xFF1F2A3D),
  inkMuted: const Color(0xFF4F5D72),
  divider: const Color(0xFFD3DFEA),
  warning: const Color(0xFFA8352A),
  headingShadow: const [],
  headingFontFamily: tutoSchrift,
  bodyFontFamily: tutoSchrift,
  cardRadius: 22,
  chipRadius: 12,
  secondaryButtonRadius: 999,
  spacingScale: const [8, 16, 32, 48, 64],
  navBarColor: const Color(0xB3FFFFFF),
  navBarShadow: const [BoxShadow(color: Color(0x1F1F4A7A), blurRadius: 18, offset: Offset(0, 6))],
  cardShadow: const [BoxShadow(color: Color(0x1A1F4A7A), blurRadius: 16, offset: Offset(0, 4))],
  buttonShadow: const [BoxShadow(color: Color(0x141F4A7A), blurRadius: 6, offset: Offset(0, 2))],
  glanz: false,
  papier: true,
  glasBlur: 18,
);
