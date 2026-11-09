import 'dart:math';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:tuto_didaktik/vorschau/widgets/antwort_eingabe.dart';

/// Ein Item auf dem Blatt, schon mit eingesetzten Zahlen und gemischten Antworten.
class BlattItem {
  const BlattItem({
    required this.aufgabenstellung,
    required this.format,
    required this.antwort,
    required this.loesung,
    required this.loesungsweg,
  });

  final String aufgabenstellung;
  final String format;
  final Map<String, dynamic> antwort;
  final String loesung;
  final List<String> loesungsweg;
}

class BlattAufgabe {
  const BlattAufgabe({
    required this.nr,
    required this.titel,
    required this.stamm,
    required this.items,
    this.srdpKennung,
  });

  final int nr;
  final String titel;
  final String stamm;
  final List<BlattItem> items;

  /// ID im offiziellen SRDP-Aufgabenpool; `null` bei Tuto-Aufgaben.
  final String? srdpKennung;
}

/// Inhalt eines Blatts: eine Gruppe, Aufgaben oder Lösungen.
class Blatt {
  const Blatt({required this.paketTitel, required this.gruppe, required this.aufgaben, required this.loesungen});

  final String paketTitel;

  /// `null`, wenn das Paket nur eine Gruppe hat.
  final String? gruppe;
  final List<BlattAufgabe> aufgaben;
  final bool loesungen;

  bool get hatSrdp => aufgaben.any((a) => a.srdpKennung != null);
}

/// Stellt die Blätter zusammen: pro gewählter Gruppe ein Aufgabenblatt, auf
/// Wunsch danach ein Lösungsblatt. Gemischt wird wie in der Vorschau.
List<Blatt> paketBlaetter(
  Paket p,
  Map<String, StoreAufgabe> alle, {
  required List<String> gruppen,
  bool mitLoesungen = false,
}) {
  final blaetter = <Blatt>[];
  for (final gruppe in gruppen) {
    final g = gruppe.codeUnitAt(0) - 65;
    final aufgaben = <BlattAufgabe>[];
    for (var i = 0; i < p.plaetze.length; i++) {
      final gp = g == 0 ? null : p.gruppenPlaetze[gruppe]?.elementAtOrNull(i);
      final id = g == 0 ? p.plaetze[i].aufgabe : (gp?.aufgabe ?? p.plaetze[i].aufgabe);
      final a = alle[id];
      if (a == null) continue;
      final inhalt = g > 0 && p.antwortenMischen ? mischeAntworten(a.inhalt, g * 7919 + i) : a.inhalt;
      final geladen = ladeZurVorschau(inhalt).aufgabe;
      if (geladen == null) continue;
      final zufall = Random(gp?.seed ?? 0);
      final werte = <String, num>{
        for (final par in geladen.parameter) par.name: gp?.art == GruppenArt.parameter ? par.ziehe(zufall) : par.min,
      };
      String fuelle(String t) => fuelleParameter(t, werte);
      final refs = (a.inhalt['externe_referenzen'] as List?)?.whereType<Map>().toList() ?? const [];
      aufgaben.add(
        BlattAufgabe(
          nr: aufgaben.length + 1,
          titel: a.titel,
          stamm: fuelle(geladen.stamm),
          srdpKennung: a.herkunft == 'srdp' ? '${refs.isEmpty ? a.id : (refs.first['id'] ?? a.id)}' : null,
          items: [
            for (final it in geladen.items)
              BlattItem(
                aufgabenstellung: fuelle(it.aufgabenstellung),
                format: it.format,
                antwort: it.antwort,
                loesung: loesungAlsText(it, werte: werte),
                loesungsweg: [for (final s in it.loesungsweg) fuelle(s)],
              ),
          ],
        ),
      );
    }
    final name = p.gruppen > 1 ? gruppe : null;
    blaetter.add(Blatt(paketTitel: p.titel, gruppe: name, aufgaben: aufgaben, loesungen: false));
    if (mitLoesungen) blaetter.add(Blatt(paketTitel: p.titel, gruppe: name, aufgaben: aufgaben, loesungen: true));
  }
  return blaetter;
}

const _blau = PdfColor.fromInt(0xFF2A62C4);
const _grau = PdfColor.fromInt(0xFF5B6678);
const _linie = PdfColor.fromInt(0xFFB8C2CF);

/// Erzeugt das PDF. Schrift DejaVu Sans, weil sie die Mathe-Zeichen der
/// Aufgaben (ℕ ∈ ∩ ≤ √ …) enthält.
Future<Uint8List> paketPdf(List<Blatt> blaetter, {DateTime? datum}) async {
  final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final fett = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final jahr = (datum ?? DateTime.now()).year;
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: normal, bold: fett),
    title: blaetter.isEmpty ? 'Tuto' : blaetter.first.paketTitel,
    author: 'Tuto',
  );
  for (final b in blaetter) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 36),
        header: (c) => c.pageNumber == 1 ? _kopf(b) : pw.SizedBox(),
        footer: (c) => _fuss(c, b, jahr),
        build: (c) => [for (final a in b.aufgaben) b.loesungen ? _loesung(a) : _aufgabe(a)],
      ),
    );
  }
  return doc.save();
}

pw.Widget _kopf(Blatt b) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            b.loesungen ? '${b.paketTitel}: Lösungen' : b.paketTitel,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (b.gruppe != null)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _blau),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Gruppe ${b.gruppe}',
              style: pw.TextStyle(color: _blau, fontWeight: pw.FontWeight.bold),
            ),
          ),
      ],
    ),
    if (!b.loesungen) ...[
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          pw.Text('Name: ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(child: pw.Container(height: 12, decoration: _unterstrich)),
          pw.SizedBox(width: 24),
          pw.Text('Datum: ', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 110, child: pw.Container(height: 12, decoration: _unterstrich)),
        ],
      ),
    ],
    pw.SizedBox(height: 14),
  ],
);

const _unterstrich = pw.BoxDecoration(
  border: pw.Border(bottom: pw.BorderSide(color: _linie)),
);

pw.Widget _fuss(pw.Context c, Blatt b, int jahr) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Divider(color: _linie, thickness: 0.5),
    if (b.hatSrdp)
      pw.Text(
        'Mit * gekennzeichnete Aufgaben stammen aus dem offiziellen SRDP-Aufgabenpool '
        '(Bundesministerium für Bildung, CC BY 4.0) und wurden für Tuto bearbeitet.',
        style: const pw.TextStyle(fontSize: 7.5, color: _grau),
      ),
    pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            '© $jahr Tuto · Aufgaben aus dem Tuto-Aufgabenbestand',
            style: const pw.TextStyle(fontSize: 7.5, color: _grau),
          ),
        ),
        pw.Text('Seite ${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grau)),
      ],
    ),
  ],
);

pw.Widget _titel(BlattAufgabe a) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.end,
  children: [
    pw.Text('${a.nr}. ${a.titel}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    if (a.srdpKennung != null) ...[
      pw.SizedBox(width: 6),
      pw.Text('* SRDP ${a.srdpKennung}', style: const pw.TextStyle(fontSize: 7.5, color: _grau)),
    ],
  ],
);

pw.Widget _aufgabe(BlattAufgabe a) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 16),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titel(a),
      if (a.stamm.trim().isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text(a.stamm, style: const pw.TextStyle(fontSize: 10.5)),
      ],
      for (final it in a.items) ...[
        pw.SizedBox(height: 6),
        pw.Text(it.aufgabenstellung, style: const pw.TextStyle(fontSize: 10.5)),
        pw.SizedBox(height: 4),
        _antwortFeld(it),
      ],
    ],
  ),
);

pw.Widget _kaestchen(String text, {String? marke}) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 9,
        height: 9,
        margin: const pw.EdgeInsets.only(top: 2, right: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _grau, width: 0.7)),
      ),
      if (marke != null) pw.SizedBox(width: 14, child: pw.Text(marke, style: const pw.TextStyle(fontSize: 10))),
      pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
    ],
  ),
);

/// Freier Platz für die Rechnung, ohne Linien (Jona, 09.11.2026).
pw.Widget _platz(int zeilen) => pw.SizedBox(height: zeilen * 18.0);

pw.Widget _antwortFeld(BlattItem it) {
  final a = it.antwort;
  List<String> liste(Object? v) => v is List ? [for (final x in v) '$x'] : const [];
  switch (it.format) {
    case 'mc_1aus5' || 'mc_1aus6' || 'mc_2aus5':
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (it.format == 'mc_2aus5')
            pw.Text(
              'Kreuze die zwei zutreffenden Antworten an.',
              style: const pw.TextStyle(fontSize: 8.5, color: _grau),
            ),
          for (final o in liste(a['optionen'])) _kaestchen(o),
        ],
      );
    case 'lueckentext':
      final satz = '${a['satz'] ?? ''}'.replaceAll('{1}', '___(1)___').replaceAll('{2}', '___(2)___');
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(satz, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final l in [1, 2])
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('($l)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      for (final o in liste(a['luecke_$l'])) _kaestchen(o),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    case 'zuordnung':
      final optionen = liste(a['optionen']);
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final e in liste(a['elemente']))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 18,
                          height: 14,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: _grau, width: 0.7)),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Expanded(child: pw.Text(e, style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < optionen.length; i++)
                  pw.Text('${String.fromCharCode(65 + i)}  ${optionen[i]}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      );
    case 'offen_text':
      return _platz(6);
    case 'konstruktion':
      return _platz(9);
    default:
      final vorlage = a['vorlage'];
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _platz(4),
          if (vorlage is String && vorlage.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(vorlage.replaceAll(RegExp(r'\{[a-z]\}'), '________'), style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      );
  }
}

pw.Widget _loesung(BlattAufgabe a) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 12),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titel(a),
      for (final it in a.items) ...[
        pw.SizedBox(height: 3),
        pw.Text('Lösung: ${it.loesung}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        for (final s in it.loesungsweg) pw.Text(s, style: const pw.TextStyle(fontSize: 9.5, color: _grau)),
      ],
    ],
  ),
);
