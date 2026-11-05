/// Feldliste aus "Aufgaben Struktur" (Vault) und die Bedienart jedes Felds aus
/// dem "Design Document; Didaktik-Tool". Oberfläche und Prüfung lesen beide
/// von hier, damit sie nicht auseinanderlaufen.
library;

enum FeldArt { dropdown, suche, beispiel, text, formular, nurLesbar }

class FeldDef {
  const FeldDef(
    this.key,
    this.label,
    this.art, {
    this.werte = const [],
    this.beispiel,
    this.pflicht = false,
    this.mehrzeilig = false,
    this.mehrfach = false,
  });

  final String key;
  final String label;
  final FeldArt art;

  /// Erlaubte Werte bei [FeldArt.dropdown].
  final List<Object> werte;

  /// Ausgegrautes Beispiel bei Feldern mit Schema.
  final String? beispiel;
  final bool pflicht;
  final bool mehrzeilig;

  /// Der Wert ist eine Liste (z. B. `level`).
  final bool mehrfach;
}

const operatorenNachBereich = <String, List<String>>{
  'H1': [
    'aufstellen',
    'erstellen',
    'einzeichnen',
    'skizzieren',
    'eintragen',
    'kennzeichnen',
    'markieren',
    'veranschaulichen',
    'vervollstaendigen',
    'beschriften',
  ],
  'H2': ['berechnen', 'ermitteln', 'angeben', 'ablesen', 'abschaetzen', 'umformen'],
  'H3': ['interpretieren', 'beschreiben'],
  'H4': ['begruenden', 'erklaeren', 'argumentieren', 'nachweisen', 'zeigen', 'ueberpruefen'],
};

/// Operatoren, die zum Format gehören und in jedem Handlungsbereich gelten.
const operatorenFormatgebunden = ['ankreuzen', 'ergaenzen', 'zuordnen'];

/// Operatoren, die zum gewählten Handlungsbereich passen.
List<String> operatorenFuer(String? bereich) => [
  ...?operatorenNachBereich[bereich],
  ...operatorenFormatgebunden,
];

final alleOperatoren = <String>[
  for (final l in operatorenNachBereich.values) ...l,
  ...operatorenFormatgebunden,
];

const aufgabeFelder = <FeldDef>[
  FeldDef('id', 'ID', FeldArt.nurLesbar, pflicht: true),
  FeldDef('status', 'Status', FeldArt.nurLesbar),
  FeldDef('titel', 'Titel', FeldArt.text, pflicht: true),
  FeldDef('stamm', 'Stamm', FeldArt.text, mehrzeilig: true),
  FeldDef('herkunft', 'Herkunft', FeldArt.dropdown, werte: ['team', 'srdp'], pflicht: true),
  FeldDef('level', 'Level', FeldArt.suche, mehrfach: true),
  FeldDef('matura_thema', 'Matura-Thema', FeldArt.suche),
  FeldDef('lernpfad_geeignet', 'Lernpfad-geeignet', FeldArt.dropdown, werte: ['ja', 'nein']),
  FeldDef(
    'zusammenstellung',
    'Zusammenstellung',
    FeldArt.dropdown,
    werte: ['einzel', 'kontext', 'kontext_reduziert'],
    pflicht: true,
  ),
  FeldDef('matura_typ', 'Matura-Typ', FeldArt.dropdown, werte: ['typ1', 'typ2', 'typ2_rk']),
  FeldDef('matura_niveau', 'Matura-Niveau', FeldArt.dropdown, werte: ['einstieg', 'uebung', 'matura'], pflicht: true),
  FeldDef('schultyp', 'Schultyp', FeldArt.dropdown, werte: ['AHS', 'BHS'], pflicht: true),
  FeldDef('schulstufe', 'Schulstufe', FeldArt.dropdown, werte: [9, 10, 11, 12, 13], pflicht: true),
  FeldDef(
    'kontext',
    'Kontext',
    FeldArt.dropdown,
    werte: [
      'innermathematisch',
      'alltag',
      'naturwissenschaft',
      'technik',
      'wirtschaft',
      'sport',
      'gesundheit',
      'gesellschaft',
    ],
    pflicht: true,
  ),
  FeldDef('technologie', 'Technologie', FeldArt.dropdown, werte: ['ohne', 'taschenrechner', 'cas'], pflicht: true),
  FeldDef('parametrisierbar', 'Parametrisierbar', FeldArt.dropdown, werte: ['ja', 'nein'], pflicht: true),
  FeldDef('variantengruppe', 'Variantengruppe', FeldArt.beispiel, beispiel: 'AG5-01-A'),
  FeldDef('unterwegs', 'Unterwegs lösbar', FeldArt.dropdown, werte: ['ja', 'nein']),
  FeldDef('externe_referenzen', 'Externe Referenzen', FeldArt.formular),
  FeldDef('medien', 'Medien', FeldArt.formular),
  FeldDef('loesung_medien', 'Lösung als Medien', FeldArt.formular),
  FeldDef('parameter', 'Parameter', FeldArt.formular),
  FeldDef('teilaufgaben', 'Teilaufgaben', FeldArt.formular),
];

const itemFelder = <FeldDef>[
  FeldDef('item_id', 'Item-ID', FeldArt.nurLesbar, pflicht: true),
  FeldDef('aufgabenstellung', 'Aufgabenstellung', FeldArt.text, pflicht: true, mehrzeilig: true),
  FeldDef('handlungsbereich', 'Handlungsbereich', FeldArt.dropdown, werte: ['H1', 'H2', 'H3', 'H4'], pflicht: true),
  FeldDef('operator', 'Operator', FeldArt.dropdown, pflicht: true),
  FeldDef('inhaltsbereich', 'Inhaltsbereich', FeldArt.dropdown, werte: ['AG', 'FA', 'AN', 'WS'], pflicht: true),
  FeldDef('kompetenz', 'Kompetenz', FeldArt.suche, pflicht: true),
  FeldDef('kompetenz_sekundaer', 'Weitere Kompetenzen', FeldArt.suche, mehrfach: true),
  FeldDef('grundkompetenz', 'Grundkompetenz', FeldArt.beispiel, beispiel: 'FA5.5'),
  FeldDef('antwortformat', 'Antwortformat', FeldArt.dropdown, werte: _formate, pflicht: true),
  FeldDef('antwort', 'Antwort', FeldArt.formular, pflicht: true),
  FeldDef('punkteschema', 'Punkteschema', FeldArt.dropdown, werte: ['0/1', '0/½/1'], pflicht: true),
  FeldDef(
    'halbpunkt_regel',
    'Halbpunkt-Regel',
    FeldArt.dropdown,
    werte: ['je_luecke', 'je_wert', 'zuordnung_2_bis_3'],
  ),
  FeldDef('schwierigkeit_start', 'Schwierigkeit', FeldArt.dropdown, werte: [1, 2, 3, 4, 5], pflicht: true),
  FeldDef('erwartete_sekunden', 'Erwartete Sekunden', FeldArt.beispiel, beispiel: '90'),
  FeldDef('loesungsweg', 'Lösungsweg', FeldArt.text, pflicht: true, mehrzeilig: true, mehrfach: true),
  FeldDef('hilfen', 'Hilfen', FeldArt.formular, pflicht: true),
  FeldDef('fehlerbilder', 'Fehlerbilder', FeldArt.formular),
  FeldDef('abhaengig_von', 'Hängt ab von', FeldArt.suche),
  FeldDef('folgefehler', 'Folgefehler', FeldArt.dropdown, werte: ['ja', 'nein']),
  FeldDef('schwierigkeit_rating', 'Schwierigkeit (gemessen)', FeldArt.nurLesbar),
];

const _formate = <Object>[
  'mc_1aus5',
  'mc_1aus6',
  'mc_2aus5',
  'lueckentext',
  'zuordnung',
  'halboffen',
  'offen_zahl',
  'offen_term',
  'offen_text',
  'konstruktion',
];

/// Suchbegriff im Bauplan für das "?" am Feld. Meist der Feldname; zwei Felder
/// sind dort nur unter einem Oberbegriff erklärt.
String hilfeBegriffFuer(String key) => switch (key) {
  'loesung_medien' => 'medien',
  'schwierigkeit_rating' => 'schwierigkeit',
  _ => key,
};

/// Leere `antwort` beim Wechsel des Antwortformats.
Map<String, dynamic> leereAntwort(String format) => switch (format) {
  'mc_1aus5' => {'optionen': List.filled(5, ''), 'richtig': 0},
  'mc_1aus6' => {'optionen': List.filled(6, ''), 'richtig': 0},
  'mc_2aus5' => {
    'optionen': List.filled(5, ''),
    'richtig': [0, 1],
  },
  'lueckentext' => {
    'satz': '… {1} … {2} …',
    'luecke_1': List.filled(3, ''),
    'luecke_2': List.filled(3, ''),
    'richtig': [0, 0],
  },
  'zuordnung' => {
    'elemente': List.filled(4, ''),
    'optionen': List.filled(6, ''),
    'richtig': {'0': 'A', '1': 'B', '2': 'C', '3': 'D'},
  },
  'halboffen' => {
    'vorlage': 'x = {x}',
    'art': 'zahl',
    'wert': 0,
    'toleranz': 0,
    'einheit': null,
    'einheit_pflicht': 'nein',
    'rundung': null,
  },
  'offen_zahl' => {'wert': 0, 'toleranz': 0, 'einheit': null, 'einheit_pflicht': 'nein', 'rundung': null},
  'offen_term' => {'term': ''},
  'offen_text' => {'musterloesung': '', 'bewertungskriterium': ''},
  'konstruktion' => {
    'zeichenflaeche': 'koordinatensystem',
    'bereich': [0, 6, 0, 6],
    'ziel': 'punkt',
    'geometrie': <String, dynamic>{},
    'toleranz': 0.1,
  },
  _ => <String, dynamic>{},
};

/// Ankreuzformate: Anzahl der Antworten und der richtigen.
const ankreuzFormate = <String, (int antworten, int richtige)>{
  'mc_1aus5': (5, 1),
  'mc_1aus6': (6, 1),
  'mc_2aus5': (5, 2),
};

/// `richtig` als Liste, egal ob als Zahl oder Liste gespeichert.
List<int> richtigeIndizes(Object? richtig) => switch (richtig) {
  final int i => [i],
  final List<dynamic> l => l.whereType<int>().toList(),
  _ => const [],
};

/// Eine Markierung bei einem 1-aus-Format als Zahl, wie die App sie liest; sonst
/// als Liste. So bleibt auch ein unpassender Zwischenstand erhalten.
Object richtigFuerFormat(String format, List<int> indizes) {
  final sortiert = [...indizes]..sort();
  return ankreuzFormate[format]?.$2 == 1 && sortiert.length == 1 ? sortiert.first : sortiert;
}

bool _gleicheArt(Object? a, Object? b) =>
    (a is List && b is List) || (a is Map && b is Map) || (a is num && b is num) || (a is String && b is String);

/// `antwort` beim Wechsel des Antwortformats. Zwischen Ankreuzformaten bleibt
/// alles stehen (passt die Zahl nicht, meldet das die Prüfung); sonst bleiben
/// die Felder, die beide Formate kennen und die denselben Typ haben.
Map<String, dynamic> antwortFuerFormat(String neu, Map<String, dynamic> alt) {
  final vorlage = leereAntwort(neu);
  final ankreuz = ankreuzFormate[neu];
  if (ankreuz != null && alt['optionen'] is List && alt['richtig'] is! Map) {
    final optionen = [...alt['optionen'] as List];
    while (optionen.length > ankreuz.$1 && '${optionen.last ?? ''}'.trim().isEmpty) {
      optionen.removeLast();
    }
    return {...alt, 'optionen': optionen, 'richtig': richtigFuerFormat(neu, richtigeIndizes(alt['richtig']))};
  }
  return {
    for (final e in vorlage.entries)
      e.key: alt[e.key] != null && (e.value == null || _gleicheArt(alt[e.key], e.value)) ? alt[e.key] : e.value,
  };
}

/// Leeres Item für den Knopf "Item hinzufügen".
Map<String, dynamic> leeresItem(String itemId) => {
  'item_id': itemId,
  'aufgabenstellung': '',
  'operator': null,
  'handlungsbereich': null,
  'inhaltsbereich': null,
  'kompetenz': null,
  'kompetenz_sekundaer': <String>[],
  'grundkompetenz': null,
  'antwortformat': 'mc_1aus5',
  'antwort': leereAntwort('mc_1aus5'),
  'punkteschema': '0/1',
  'halbpunkt_regel': null,
  'loesungsweg': <String>[],
  'fehlerbilder': <String, dynamic>{},
  'hilfen': [
    for (final s in [1, 2, 3])
      {
        'stufe': s,
        'text': '',
        'freigabe': {'nach_sekunden': s * 20},
      },
  ],
  'abhaengig_von': null,
  'folgefehler': null,
  'schwierigkeit_start': 3,
  'erwartete_sekunden': 90,
};
