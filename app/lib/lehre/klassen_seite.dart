import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

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

/// Eine Klasse: Liste der Schüler\*innen mit Gesamtstand, bester und
/// schwächster Kompetenz; dazu die schwächsten Kompetenzen der Klasse mit
/// Sprung zum passenden Förderpaket.
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

  Future<void> _foerderpaket(BuildContext context, String kompetenz) async {
    final p = zustand.neuesPaket(titel: 'Förderpaket $kompetenz (${klasse.name})')
      ..einstellung.anzahl = 4
      ..filter.umschalten('kompetenz', kompetenz);
    final f = await zustand.speicherePaket(p);
    if (!context.mounted) return;
    if (f != null) {
      await zeigeMeldung(context, f, fehler: true);
    } else {
      aktionen.oeffnePaket(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kompetenzen = klasse.schueler.isEmpty ? <String>[] : klasse.schueler.first.stufen.keys.toList();
    final schwach = [for (final k in kompetenzen) (k, klasse.schueler.where((s) => (s.stufen[k] ?? 0) <= 1).length)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final mitAufgaben = {for (final a in zustand.aufgaben) ...a.kompetenzen};
    final pakete = [
      for (final p in zustand.daten.pakete)
        if (p.zuweisungen.any((z) => z.klasse == klasse.id)) p,
    ];
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  SizedBox(
                    width: 720,
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: linie),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.3),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1.6),
                          3: FlexColumnWidth(1.6),
                          4: FixedColumnWidth(90),
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
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Schwächen der Klasse', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text('Personen unter Stufe 2 pro Kompetenz', style: text.bodySmall),
                        const SizedBox(height: 8),
                        for (final (k, n) in schwach.take(6))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(k),
                            subtitle: Text('$n von ${klasse.schueler.length}'),
                            trailing: TextButton(
                              key: ValueKey('foerder-$k'),
                              onPressed: mitAufgaben.contains(k) ? () => _foerderpaket(context, k) : null,
                              child: Text(mitAufgaben.contains(k) ? 'Förderpaket' : 'keine Aufgaben'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text('Zugewiesene Pakete', style: text.titleMedium),
                        const SizedBox(height: 4),
                        if (pakete.isEmpty)
                          Text('Noch keine. Im Paket-Editor mit „Zuweisen“.', style: text.bodySmall)
                        else
                          for (final p in pakete)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.inventory_2_outlined, size: 20),
                              title: Text(p.titel),
                              subtitle: Text(
                                '${p.plaetze.length} Aufgaben${p.gruppen > 1 ? ' · Gruppen ${gruppenNamen.take(p.gruppen).join('/')}' : ''}',
                              ),
                              onTap: () => aktionen.oeffnePaket(p.id),
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

/// Eine Person: alle Kompetenzen mit iKM-Stufe und die zugewiesenen Pakete.
class SchuelerinSeite extends StatelessWidget {
  const SchuelerinSeite({super.key, required this.zustand, required this.klasse, required this.person});

  final LehreZustand zustand;
  final TestKlasse klasse;
  final TestSchuelerin person;

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
                                  SizedBox(width: 100, child: IkmMarke(k.value)),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aufgabenpakete', style: text.titleMedium),
                        const SizedBox(height: 4),
                        if (pakete.isEmpty)
                          Text('Noch keine Pakete zugewiesen.', style: text.bodySmall)
                        else
                          for (final (p, gruppe) in pakete)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.titel),
                              subtitle: Text('Gruppe $gruppe · ${p.plaetze.length} Aufgaben'),
                              trailing: Text(
                                '${(testErgebnis(person.id, p.id, person.mittel) * 100).round()} % richtig',
                                style: text.bodySmall,
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
}
