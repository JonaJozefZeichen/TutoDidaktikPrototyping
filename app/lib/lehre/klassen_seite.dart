import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';
import 'package:tuto_didaktik/vorschau/widgets/antwort_eingabe.dart';

const _stufenFarben = [Color(0xFFB3261E), Color(0xFFC77700), Color(0xFF2A62C4), Color(0xFF1B6B32)];

Widget _testHinweis() => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  color: const Color(0xFFFFF4D6),
  child: const Text(
    'Testdaten: erfundene Personen und Lernstände. Alle Werte sind Förderinformation, kein Notenersatz.',
    style: TextStyle(fontSize: 12, color: hinweisGelb, fontWeight: FontWeight.w600),
  ),
);

class IkmMarke extends StatelessWidget {
  const IkmMarke(this.stufe, {super.key});
  final int stufe;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ikmBedeutung[stufe],
    child: Marke(ikmStufen[stufe], farbe: _stufenFarben[stufe], grund: _stufenFarben[stufe].withValues(alpha: 0.1)),
  );
}

/// Startseite der Lehrenden: die eigenen Klassen bzw. Nachhilfegruppen.
class KlassenSeite extends StatelessWidget {
  const KlassenSeite({super.key, required this.zustand, required this.onKlasse});

  final LehreZustand zustand;
  final void Function(TestKlasse) onKlasse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final nachhilfe = zustand.klassen.isNotEmpty && zustand.klassen.first.art == 'nachhilfe';
    return Column(
      children: [
        _testHinweis(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(nachhilfe ? 'Meine Nachhilfegruppen' : 'Meine Klassen', style: text.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final k in zustand.klassen)
                    SizedBox(
                      width: 300,
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: linie),
                        ),
                        child: InkWell(
                          key: ValueKey('klasse-${k.id}'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onKlasse(k),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(k.name, style: text.titleLarge),
                                Text(
                                  '${k.lernwelt}. Klasse · ${k.schueler.length} ${k.schueler.length == 1 ? 'Person' : 'Personen'}',
                                  style: text.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                _verteilung(k),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verteilung(TestKlasse k) {
    final zahlen = {
      for (final g in ['sicher', 'teils sicher', 'unsicher']) g: k.schueler.where((s) => s.gesamt == g).length,
    };
    return Wrap(
      spacing: 6,
      children: [
        Marke('${zahlen['sicher']} sicher', farbe: _stufenFarben[3], grund: _stufenFarben[3].withValues(alpha: 0.1)),
        Marke(
          '${zahlen['teils sicher']} teils',
          farbe: _stufenFarben[1],
          grund: _stufenFarben[1].withValues(alpha: 0.1),
        ),
        Marke(
          '${zahlen['unsicher']} unsicher',
          farbe: _stufenFarben[0],
          grund: _stufenFarben[0].withValues(alpha: 0.1),
        ),
      ],
    );
  }
}

/// Kasten mit Titel, fester Höhe und eigenem Scrollbereich.
class _Kasten extends StatelessWidget {
  const _Kasten({required this.titel, required this.kind, this.aktion, this.unterzeile});

  final String titel;
  final String? unterzeile;
  final Widget? aktion;
  final Widget kind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: linie),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titel, style: text.titleMedium),
                      if (unterzeile != null) Text(unterzeile!, style: text.bodySmall),
                    ],
                  ),
                ),
                ?aktion,
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: kind),
          ],
        ),
      ),
    );
  }
}

/// Eine Klasse: oben fest nebeneinander die Kompetenzen der Klasse und die
/// zugewiesenen Pakete (je mit eigenem Scrollbereich), darunter die Liste der
/// Schüler\*innen über die ganze Breite.
class KlasseSeite extends StatelessWidget {
  const KlasseSeite({
    super.key,
    required this.zustand,
    required this.aktionen,
    required this.klasse,
    required this.onSchuelerin,
  });

  final LehreZustand zustand;
  final LehreAktionen aktionen;
  final TestKlasse klasse;
  final void Function(TestSchuelerin) onSchuelerin;

  /// Förderpaket nur für die Personen, die in [kompetenz] unter Stufe 2 sind.
  Future<void> _foerderpaket(BuildContext context, String kompetenz) async {
    final ziel = [
      for (final s in klasse.schueler)
        if ((s.stufen[kompetenz] ?? 0) <= 1) s.id,
    ];
    final p = zustand.neuesPaket(titel: 'Förderpaket $kompetenz (${klasse.name})')
      ..einstellung.anzahl = 4
      ..filter.umschalten('kompetenz', kompetenz)
      ..foerderung = Foerderung(klasse: klasse.id, kompetenz: kompetenz, schueler: ziel);
    final f = await zustand.speicherePaket(p);
    if (!context.mounted) return;
    if (f != null) {
      await zeigeMeldung(context, f, fehler: true);
    } else {
      aktionen.oeffnePaket(p.id);
    }
  }

  /// "Paket an alle senden": ein vorhandenes Paket der ganzen Klasse zuweisen.
  Future<void> _anAlle(BuildContext context) async {
    final pakete = [
      for (final p in zustand.daten.pakete)
        if (p.plaetze.isNotEmpty && p.foerderung == null) p,
    ];
    if (pakete.isEmpty) {
      await zeigeMeldung(context, 'Noch kein Paket mit Aufgaben. Unter „Pakete“ eines anlegen.', fehler: true);
      return;
    }
    final gewaehlt = await showDialog<Paket>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text('Paket an alle in ${klasse.name} senden'),
        children: [
          for (final p in pakete)
            SimpleDialogOption(
              key: ValueKey('an-alle-${p.id}'),
              onPressed: () => Navigator.pop(d, p),
              child: Text(
                '${p.titel} · ${p.plaetze.length} Aufgaben'
                '${p.gruppen > 1 ? ' · ${p.gruppen} Gruppen' : ''}',
              ),
            ),
        ],
      ),
    );
    if (gewaehlt == null || !context.mounted) return;
    final p = Paket.fromJson(gewaehlt.toJson());
    final meldung = weiseZu(p, klasse, [for (final s in klasse.schueler) s.id]);
    final f = await zustand.speicherePaket(p);
    if (context.mounted) await zeigeMeldung(context, f ?? meldung, fehler: f != null);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: zustand,
      builder: (context, _) {
        final kompetenzen = klasse.schueler.isEmpty ? <String>[] : klasse.schueler.first.stufen.keys.toList();
        final proKompetenz = [
          for (final k in kompetenzen)
            (
              k,
              klasse.schueler.where((s) => (s.stufen[k] ?? 0) <= 1).length,
              klasse.schueler.isEmpty
                  ? 0
                  : klasse.schueler.fold<int>(0, (n, s) => n + (s.stufen[k] ?? 0)) / klasse.schueler.length,
            ),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        final mitAufgaben = {for (final a in zustand.aufgaben) ...a.kompetenzen};
        final pakete = [
          for (final p in zustand.daten.pakete)
            if (p.zuweisungen.any((z) => z.klasse == klasse.id)) p,
        ];
        final mittel = klasse.schueler.isEmpty
            ? 0.0
            : klasse.schueler.fold<double>(0, (n, s) => n + s.mittel) / klasse.schueler.length;
        final verteilung = {
          for (final g in ['sicher', 'teils sicher', 'unsicher']) g: klasse.schueler.where((s) => s.gesamt == g).length,
        };
        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('klasse-zurueck'),
                    tooltip: 'Zurück',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text('${klasse.name} · ${klasse.lernwelt}. Klasse', style: text.titleMedium),
                ],
              ),
            ),
            _testHinweis(),
            SizedBox(
              height: 270,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Kasten(
                        titel: 'Kompetenzen der Klasse',
                        unterzeile:
                            'Mittel ${ikmStufen[mittel.round().clamp(0, 3)]} · ${verteilung['sicher']} sicher, '
                            '${verteilung['teils sicher']} teils sicher, ${verteilung['unsicher']} unsicher',
                        kind: ListView(
                          key: const ValueKey('kompetenzen-kasten'),
                          children: [
                            for (final (k, n, m) in proKompetenz)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(k, overflow: TextOverflow.ellipsis)),
                                    IkmMarke(m.round().clamp(0, 3)),
                                    SizedBox(
                                      width: 124,
                                      child: Text(
                                        '$n unter Stufe 2',
                                        textAlign: TextAlign.right,
                                        style: text.bodySmall,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: n == 0
                                          ? const SizedBox.shrink()
                                          : TextButton(
                                              key: ValueKey('foerder-$k'),
                                              onPressed: mitAufgaben.contains(k)
                                                  ? () => _foerderpaket(context, k)
                                                  : null,
                                              child: Text(mitAufgaben.contains(k) ? 'Förderpaket' : 'keine Aufgaben'),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Kasten(
                        titel: 'Zugewiesene Pakete',
                        aktion: FilledButton.icon(
                          key: const ValueKey('an-alle-senden'),
                          onPressed: () => _anAlle(context),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Paket an alle senden'),
                        ),
                        kind: pakete.isEmpty
                            ? Text(
                                'Noch keine. „Paket an alle senden“ oder im Paket-Editor „Zuweisen“.',
                                style: text.bodySmall,
                              )
                            : ListView(
                                children: [
                                  for (final p in pakete)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        p.foerderung == null ? Icons.inventory_2_outlined : Icons.healing_outlined,
                                        size: 20,
                                      ),
                                      title: Text(p.titel),
                                      subtitle: Text(_paketZeile(p)),
                                      onTap: () => aktionen.oeffnePaket(p.id),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: linie),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(0.9),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(1.8),
                      4: FlexColumnWidth(0.8),
                      5: FlexColumnWidth(0.8),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: flaeche),
                        children: [
                          for (final t in [
                            'Name',
                            'Gesamt',
                            'Stärkste Kompetenz',
                            'Schwächste Kompetenz',
                            'Aufgaben/Woche',
                            'Pakete',
                          ])
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(t, style: text.labelMedium),
                            ),
                        ],
                      ),
                      for (final s in klasse.schueler)
                        TableRow(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: linie)),
                          ),
                          children: [
                            InkWell(
                              key: ValueKey('schueler-${s.id}'),
                              onTap: () => onSchuelerin(s),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  s.name,
                                  style: const TextStyle(color: tutoBlau, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Align(alignment: Alignment.centerLeft, child: _gesamt(s.gesamt)),
                            ),
                            _kompetenzZelle(s.beste),
                            _kompetenzZelle(s.schwaechste),
                            Padding(padding: const EdgeInsets.all(8), child: Text('${s.aufgabenWoche}')),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${pakete.where((p) => p.zuweisungen.any((z) => z.klasse == klasse.id && z.verteilung.containsKey(s.id))).length}',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _paketZeile(Paket p) {
    final z = p.zuweisungen.firstWhere((z) => z.klasse == klasse.id);
    return [
      '${p.plaetze.length} Aufgaben',
      if (p.gruppen > 1) '${p.gruppen} Gruppen',
      z.verteilung.length == klasse.schueler.length ? 'an alle' : 'an ${z.verteilung.length} Personen',
    ].join(' · ');
  }

  Widget _gesamt(String g) {
    final i = switch (g) {
      'sicher' => 3,
      'teils sicher' => 1,
      _ => 0,
    };
    return Marke(g, farbe: _stufenFarben[i], grund: _stufenFarben[i].withValues(alpha: 0.1));
  }

  Widget _kompetenzZelle(MapEntry<String, int>? e) => Padding(
    padding: const EdgeInsets.all(8),
    child: e == null
        ? const Text('-')
        : Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(e.key, style: const TextStyle(fontSize: 12.5)),
              IkmMarke(e.value),
            ],
          ),
  );
}

/// Eine Person: alle Kompetenzen mit iKM-Stufe und die zugewiesenen Pakete;
/// ein Paket öffnet die Antworten dieser Person.
class SchuelerinSeite extends StatelessWidget {
  const SchuelerinSeite({
    super.key,
    required this.zustand,
    required this.klasse,
    required this.person,
    required this.oeffne,
  });

  final LehreZustand zustand;
  final TestKlasse klasse;
  final TestSchuelerin person;
  final void Function(Widget seite) oeffne;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final nachBereich = <String, List<MapEntry<String, int>>>{};
    for (final e in person.stufen.entries) {
      nachBereich.putIfAbsent(e.key.split('-').first.toUpperCase(), () => []).add(e);
    }
    final pakete = [
      for (final p in zustand.daten.pakete)
        for (final z in p.zuweisungen)
          if (z.klasse == klasse.id && z.verteilung.containsKey(person.id)) (p, z.verteilung[person.id]!),
    ];
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('person-zurueck'),
                tooltip: 'Zurück',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Text('${person.name} · ${klasse.name}', style: text.titleMedium),
            ],
          ),
        ),
        _testHinweis(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 560,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kompetenzen (${person.stufen.length})', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'iKM-Skala: unter Stufe 1 nicht erreicht, Stufe 1 teilweise, Stufe 2 erreicht, Stufe 3 übertroffen',
                          style: text.bodySmall,
                        ),
                        for (final e in nachBereich.entries) ...[
                          const SizedBox(height: 12),
                          Text(themenbereichNamen[e.key] ?? e.key, style: text.labelMedium),
                          for (final k in e.value)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(child: Text(k.key)),
                                  SizedBox(
                                    width: 140,
                                    child: LinearProgressIndicator(
                                      value: (k.value + 1) / 4,
                                      color: _stufenFarben[k.value],
                                      backgroundColor: const Color(0xFFEDEFF3),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 116,
                                    child: Align(alignment: Alignment.centerLeft, child: IkmMarke(k.value)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aufgabenpakete', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text('Antippen zeigt die Antworten.', style: text.bodySmall),
                        if (pakete.isEmpty)
                          Text('Noch keine Pakete zugewiesen.', style: text.bodySmall)
                        else
                          for (final (p, gruppe) in pakete)
                            ListTile(
                              key: ValueKey('ergebnis-${p.id}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.titel),
                              subtitle: Text('Gruppe $gruppe · ${p.plaetze.length} Aufgaben'),
                              trailing: Text(_quote(p, gruppe), style: text.bodySmall),
                              onTap: () => oeffne(
                                PaketErgebnisSeite(
                                  zustand: zustand,
                                  klasse: klasse,
                                  person: person,
                                  paket: p,
                                  gruppe: gruppe,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _quote(Paket p, String gruppe) {
    final a = testAntworten(person, p.id, aufgabenDerGruppe(p, gruppe), _inhalte(zustand));
    if (a.isEmpty) return '';
    return '${a.where((x) => x.richtig).length}/${a.length} richtig';
  }
}

Map<String, Map<String, dynamic>> _inhalte(LehreZustand z) => {for (final a in z.aufgaben) a.id: a.inhalt};

/// Aufgaben, die eine Person in Gruppe [gruppe] bekommt.
List<String> aufgabenDerGruppe(Paket p, String gruppe) {
  if (gruppe == 'A') return [for (final x in p.plaetze) x.aufgabe];
  final g = p.gruppenPlaetze[gruppe];
  return [for (var i = 0; i < p.plaetze.length; i++) g?.elementAtOrNull(i)?.aufgabe ?? p.plaetze[i].aufgabe];
}

/// Antworten einer Person zu einem zugewiesenen Paket (nur selbst zugewiesene
/// Pakete sind sichtbar, freies Üben nicht). Links die Liste, rechts fest die
/// Aufgabe in der Vorschau.
class PaketErgebnisSeite extends StatefulWidget {
  const PaketErgebnisSeite({
    super.key,
    required this.zustand,
    required this.klasse,
    required this.person,
    required this.paket,
    required this.gruppe,
  });

  final LehreZustand zustand;
  final TestKlasse klasse;
  final TestSchuelerin person;
  final Paket paket;
  final String gruppe;

  @override
  State<PaketErgebnisSeite> createState() => _PaketErgebnisSeiteState();
}

class _PaketErgebnisSeiteState extends State<PaketErgebnisSeite> {
  int _auswahl = 0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ids = aufgabenDerGruppe(widget.paket, widget.gruppe);
    final antworten = testAntworten(widget.person, widget.paket.id, ids, _inhalte(widget.zustand));
    final richtig = antworten.where((a) => a.richtig).length;
    final gewaehlt = antworten.isEmpty ? null : antworten[_auswahl.clamp(0, antworten.length - 1)];
    final aufgabe = gewaehlt == null ? null : widget.zustand.nachId[gewaehlt.aufgabe];
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('ergebnis-zurueck'),
                tooltip: 'Zurück',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${widget.person.name} · ${widget.paket.titel} · Gruppe ${widget.gruppe}',
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$richtig von ${antworten.length} richtig', key: const ValueKey('ergebnis-summe')),
              const SizedBox(width: 8),
            ],
          ),
        ),
        _testHinweis(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 520,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: antworten.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _antwortKarte(context, i, antworten[i]),
                ),
              ),
              const VerticalDivider(width: 1, color: linie),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: aufgabe == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.topLeft,
                          child: HandyVorschau(
                            key: ValueKey('ergebnis-vorschau-${aufgabe.id}'),
                            inhalt: aufgabe.inhalt,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _antwortKarte(BuildContext context, int i, TestAntwort a) {
    final text = Theme.of(context).textTheme;
    final s = widget.zustand.nachId[a.aufgabe];
    final item = s == null ? null : ladeZurVorschau(s.inhalt).aufgabe?.items.where((x) => x.id == a.itemId).firstOrNull;
    final loesung = item == null ? '' : loesungAlsText(item).trim();
    final (farbe, symbol, status) = a.selbstBewertet
        ? (grauText, Icons.rate_review_outlined, 'selbst bewertet')
        : a.richtig
        ? (const Color(0xFF1B6B32), Icons.check_circle, 'richtig')
        : (fehlerRot, Icons.cancel, 'falsch');
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: i == _auswahl ? tutoBlau : linie, width: i == _auswahl ? 2 : 1),
      ),
      child: InkWell(
        key: ValueKey('antwort-$i'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _auswahl = i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(symbol, color: farbe, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${a.platz + 1}. ${s?.titel ?? a.aufgabe}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(color: farbe, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!a.richtig && !a.selbstBewertet)
                Text('Antwort: ${a.gegeben}', style: const TextStyle(color: fehlerRot)),
              if (a.fehlerbild != null) Text('Fehlerbild: ${a.fehlerbild}', style: text.bodySmall),
              if (loesung.isNotEmpty) Text('Lösung: $loesung', style: text.bodyMedium),
              const SizedBox(height: 4),
              Text(
                '${a.hilfen == 0 ? 'ohne Hilfe' : '${a.hilfen} ${a.hilfen == 1 ? 'Hilfe' : 'Hilfen'}'} · '
                '${(a.sekunden / 60).toStringAsFixed(1).replaceAll('.', ',')} min',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
