/// Aufgaben aus Sicht der Lehrpersonen: eine flache Zeile pro Aufgabe mit
/// allen Werten, nach denen im Aufgaben-Store gefiltert wird ("Design
/// Document; Lehrpersonen-Ansicht", Abschnitt "Filter").
library;

import 'package:didaktik_kern/src/modelle.dart';
import 'package:didaktik_kern/src/pruefung.dart';

/// Antwortformate in Gruppen, wie Lehrpersonen sie suchen.
const formatGruppen = {
  'ankreuzen': 'Ankreuzen',
  'luecke_zuordnung': 'Lücke & Zuordnung',
  'zahl_term': 'Zahl & Term',
  'offen': 'Offene Antwort',
  'konstruktion': 'Zeichnen',
};

String formatGruppe(String format) => switch (format) {
  'mc_1aus5' || 'mc_1aus6' || 'mc_2aus5' => 'ankreuzen',
  'lueckentext' || 'zuordnung' => 'luecke_zuordnung',
  'halboffen' || 'offen_zahl' || 'offen_term' => 'zahl_term',
  'offen_text' => 'offen',
  'konstruktion' => 'konstruktion',
  _ => 'zahl_term',
};

const formatNamen = {
  'mc_1aus5': '1 aus 5',
  'mc_1aus6': '1 aus 6',
  'mc_2aus5': '2 aus 5',
  'lueckentext': 'Lückentext',
  'zuordnung': 'Zuordnung',
  'halboffen': 'Halboffen',
  'offen_zahl': 'Zahl',
  'offen_term': 'Term',
  'offen_text': 'Text',
  'konstruktion': 'Konstruktion',
};

/// Schätzwerte pro Format, solange `erwartete_sekunden` fehlt.
const _sekundenSchaetzung = {
  'mc_1aus5': 60,
  'mc_1aus6': 60,
  'mc_2aus5': 90,
  'lueckentext': 60,
  'zuordnung': 90,
  'halboffen': 120,
  'offen_zahl': 120,
  'offen_term': 150,
  'offen_text': 240,
  'konstruktion': 180,
};

const themenbereichNamen = {
  'AG': 'Algebra und Geometrie',
  'FA': 'Funktionale Abhängigkeiten',
  'AN': 'Analysis',
  'WS': 'Wahrscheinlichkeit und Statistik',
};

const handlungsbereichNamen = {
  'H1': 'H1 Darstellen, Modellbilden',
  'H2': 'H2 Rechnen, Operieren',
  'H3': 'H3 Interpretieren',
  'H4': 'H4 Argumentieren, Begründen',
};

const kontextNamen = {
  'innermathematisch': 'Innermathematisch',
  'alltag': 'Alltag',
  'naturwissenschaft': 'Naturwissenschaft',
  'technik': 'Technik',
  'wirtschaft': 'Wirtschaft',
  'sport': 'Sport',
  'gesundheit': 'Gesundheit',
  'gesellschaft': 'Gesellschaft',
};

const technologieNamen = {'ohne': 'Ohne Hilfsmittel', 'taschenrechner': 'Taschenrechner', 'cas': 'CAS'};

const zusammenstellungNamen = {
  'einzel': 'Einzelaufgabe',
  'kontext': 'Kontextaufgabe',
  'kontext_reduziert': 'Kontextaufgabe (reduziert)',
};

const maturaNiveauNamen = {'einstieg': 'Einstieg', 'uebung': 'Übung', 'matura': 'Matura-Niveau'};

const schwierigkeitNamen = {1: 'sehr leicht', 2: 'leicht', 3: 'mittel', 4: 'schwer', 5: 'sehr schwer'};

/// Eine Aufgabe im Store. [inhalt] ist die Fassung, die Lehrpersonen sehen
/// (die freigegebene, im Test auf Wunsch die aktuelle).
class StoreAufgabe {
  StoreAufgabe({
    required this.id,
    required this.fassung,
    required this.status,
    required this.inhalt,
    required this.titel,
    required this.schulstufe,
    required this.themenbereiche,
    required this.levels,
    required this.kompetenzen,
    required this.hauptkompetenz,
    required this.grundkompetenzen,
    required this.formate,
    required this.handlungsbereiche,
    required this.schwierigkeit,
    required this.sekunden,
    required this.sekundenGeschaetzt,
    required this.kontext,
    required this.technologie,
    required this.zusammenstellung,
    required this.variantengruppe,
    required this.parametrisierbar,
    required this.hatMedien,
    required this.maturaNiveau,
    required this.maturaThema,
    required this.herkunft,
    required this.vorschauText,
    required this.itemZahl,
  });

  factory StoreAufgabe.aus(String id, Map<String, dynamic> inhalt, {required int fassung, required String status}) {
    final items = alleItems(inhalt);
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    final stufen = [
      for (final i in items)
        if (i['schwierigkeit_start'] is int) i['schwierigkeit_start'] as int,
    ];
    var sekunden = 0;
    var geschaetzt = false;
    for (final i in items) {
      final s = i['erwartete_sekunden'];
      if (s is int && s > 0) {
        sekunden += s;
      } else {
        sekunden += _sekundenSchaetzung[i['antwortformat']] ?? 120;
        geschaetzt = true;
      }
    }
    final medien = inhalt['medien'];
    final vg = text(inhalt['variantengruppe']);
    return StoreAufgabe(
      id: id,
      fassung: fassung,
      status: status,
      inhalt: inhalt,
      titel: text(inhalt['titel']) ?? id,
      schulstufe: inhalt['schulstufe'] is int ? inhalt['schulstufe'] as int : null,
      themenbereiche: {for (final i in items) ?text(i['inhaltsbereich'])},
      levels: [...((inhalt['level'] as List?) ?? const []).whereType<String>()],
      kompetenzen: {
        for (final i in items) ...[
          ?text(i['kompetenz']),
          ...((i['kompetenz_sekundaer'] as List?) ?? const []).whereType<String>(),
        ],
      },
      hauptkompetenz: items.isEmpty ? null : text(items.first['kompetenz']),
      grundkompetenzen: {for (final i in items) ?text(i['grundkompetenz'])},
      formate: {for (final i in items) ?text(i['antwortformat'])},
      handlungsbereiche: {for (final i in items) ?text(i['handlungsbereich'])},
      schwierigkeit: stufen.isEmpty ? null : (stufen.reduce((a, b) => a + b) / stufen.length),
      sekunden: sekunden,
      sekundenGeschaetzt: geschaetzt,
      kontext: text(inhalt['kontext']),
      technologie: text(inhalt['technologie']),
      zusammenstellung: text(inhalt['zusammenstellung']),
      variantengruppe: vg == null || vg == id ? null : vg,
      parametrisierbar: inhalt['parametrisierbar'] == 'ja' && (inhalt['parameter'] as List?)?.isNotEmpty == true,
      hatMedien: medien is List && medien.isNotEmpty,
      maturaNiveau: text(inhalt['matura_niveau']),
      maturaThema: text(inhalt['matura_thema']),
      herkunft: text(inhalt['herkunft']),
      vorschauText: items.isEmpty ? (text(inhalt['stamm']) ?? '') : (text(items.first['aufgabenstellung']) ?? ''),
      itemZahl: items.length,
    );
  }

  final String id;
  final int fassung;
  final String status;
  final Map<String, dynamic> inhalt;
  final String titel;
  final int? schulstufe;
  final Set<String> themenbereiche;
  final List<String> levels;

  /// Haupt- und Nebenkompetenzen aller Items.
  final Set<String> kompetenzen;

  /// Kompetenz des ersten Items, für Ersatz und Streuung.
  final String? hauptkompetenz;
  final Set<String> grundkompetenzen;
  final Set<String> formate;
  final Set<String> handlungsbereiche;

  /// Mittel von `schwierigkeit_start` über alle Items (1-5).
  final double? schwierigkeit;
  final int sekunden;
  final bool sekundenGeschaetzt;
  final String? kontext;
  final String? technologie;
  final String? zusammenstellung;

  /// `null`, wenn die Gruppe nur die Aufgabe selbst ist.
  final String? variantengruppe;
  final bool parametrisierbar;
  final bool hatMedien;
  final String? maturaNiveau;
  final String? maturaThema;
  final String? herkunft;
  final String vorschauText;
  final int itemZahl;

  int? get klasse => schulstufe == null ? null : schulstufe! - 4;
  int? get schwierigkeitGerundet => schwierigkeit?.round();
  Set<String> get formatGruppenSet => {for (final f in formate) formatGruppe(f)};
  double get minuten => sekunden / 60;

  /// Gruppe gleichwertiger Aufgaben; ohne eigene Gruppe die eigene ID.
  String get gruppenSchluessel => variantengruppe ?? id;
}

/// Baut die Store-Liste aus den Einträgen des Bestands. Lehrpersonen sehen
/// nur freigegebene Aufgaben; mit [auchUnfreigegebene] (nur Teststand) auch
/// Entwürfe in ihrer aktuellen Fassung, aber nie zurückgezogene.
List<StoreAufgabe> storeAufgaben(Iterable<Eintrag> eintraege, {bool auchUnfreigegebene = false}) {
  final liste = <StoreAufgabe>[];
  for (final e in eintraege) {
    if (e.status == 'zurueckgezogen') continue;
    final live = e.liveInhalt;
    if (live != null) {
      liste.add(StoreAufgabe.aus(e.id, live, fassung: e.liveFassung!, status: 'live'));
    } else if (auchUnfreigegebene) {
      liste.add(StoreAufgabe.aus(e.id, e.aktuell.inhalt, fassung: e.aktuell.nr, status: e.status));
    }
  }
  liste.sort((a, b) => a.id.compareTo(b.id));
  return liste;
}

/// Wie viele Aufgaben dieselbe Variantengruppe teilen, pro Gruppe.
Map<String, int> variantenZahlen(Iterable<StoreAufgabe> alle) {
  final z = <String, int>{};
  for (final a in alle) {
    if (a.variantengruppe != null) z[a.variantengruppe!] = (z[a.variantengruppe!] ?? 0) + 1;
  }
  return z;
}
