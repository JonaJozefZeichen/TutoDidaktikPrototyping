import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/merkliste_seite.dart';
import 'package:tuto_didaktik/lehre/schueler_ansicht.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/lehre/zuweisen_seite.dart';
import 'package:tuto_didaktik/thema.dart';
import 'package:tuto_didaktik/vorschau/widgets/antwort_eingabe.dart';

const _stufenFarben = [Color(0xFFB3261E), Color(0xFFC77700), Color(0xFF2A62C4), Color(0xFF1B6B32)];

Widget _testHinweis() => Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  color: const Color(0xFFFFF1CC),
  child: const Text(
    'Testklasse: drei Testkonten, die du in der Schüler*innen-Ansicht selbst bedienst. '
    'Alle Werte sind Förderinformation, kein Notenersatz.',
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
  const KlassenSeite({super.key, required this.zustand, required this.onKlasse, required this.onSchuelerAnsicht});

  final LehreZustand zustand;
  final void Function(TestKlasse) onKlasse;
  final VoidCallback onSchuelerAnsicht;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        _testHinweis(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Meine Klassen', style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Vorerst gibt es nur die Testklasse. Weitere Klassen legst du später selbst an, oder das Tuto-Team '
                'richtet sie mit der Schullizenz ein.',
                style: text.bodySmall,
              ),
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
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: linie),
                        ),
                        child: InkWell(
                          key: ValueKey('klasse-${k.id}'),
                          borderRadius: BorderRadius.circular(16),
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
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  key: const ValueKey('schueler-ansicht'),
                                  onPressed: onSchuelerAnsicht,
                                  icon: const Icon(Icons.phone_iphone, size: 18),
                                  label: const Text('Schüler*innen-Ansicht öffnen'),
                                ),
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
        borderRadius: BorderRadius.circular(16),
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

  /// Aktueller Stand der Klasse (Stufen ändern sich mit jeder Antwort).
  TestKlasse get _k => zustand.klassen.firstWhere((k) => k.id == klasse.id, orElse: () => klasse);
  final void Function(TestSchuelerin) onSchuelerin;

  /// Förderpaket nur für die Personen, die in [kompetenz] unter Stufe 2 sind.
  Future<void> _foerderpaket(BuildContext context, String kompetenz) async {
    final ziel = [
      for (final s in _k.schueler)
        if (s.stufen[kompetenz] != null && s.stufen[kompetenz]! <= 1) s.id,
    ];
    final p = zustand.neuesPaket(titel: 'Förderpaket $kompetenz (${_k.name})')
      ..empfaenger[klasse.id] = ziel
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

  /// "Paket zuweisen": eigenes Paket wählen (Zuweisen-Ansicht mit allen
  /// Personen der Klasse) oder ein neues erstellen (alle Personen der Klasse
  /// als Empfänger\*innen).
  Future<void> _zuweisen(BuildContext context) async {
    final wahl = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text('Paket an ${_k.name} zuweisen'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('zuweisen-eigenes'),
            onPressed: () => Navigator.pop(d, 'eigenes'),
            child: const ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Eigenes Paket wählen'),
              subtitle: Text('Aus der Paketliste, danach Empfänger*innen, Gruppen und Abgabe prüfen'),
            ),
          ),
          SimpleDialogOption(
            key: const ValueKey('zuweisen-neues'),
            onPressed: () => Navigator.pop(d, 'neu'),
            child: const ListTile(
              leading: Icon(Icons.add),
              title: Text('Neues Paket erstellen'),
              subtitle: Text('Alle Personen der Klasse sind als Empfänger*innen eingetragen'),
            ),
          ),
        ],
      ),
    );
    if (wahl == null || !context.mounted) return;
    final alle = {for (final s in _k.schueler) s.id};
    if (wahl == 'eigenes') {
      aktionen.oeffneZuweisen(auswahl: {klasse.id: alle});
      return;
    }
    final p = await neuesPaketDialog(
      context,
      zustand,
      vorschlag: 'Paket ${_k.name}',
      empfaenger: {
        _k.id: [for (final s in _k.schueler) s.id],
      },
    );
    if (p != null && context.mounted) aktionen.oeffnePaket(p.id);
  }

  /// Datum, an dem ein Förderpaket für [kompetenz] an alle Personen ging, die
  /// es jetzt brauchen; dann verschwindet die Empfehlung.
  DateTime? _foerderungVerschickt(String kompetenz) {
    final betroffen = {
      for (final s in _k.schueler)
        if (s.stufen[kompetenz] != null && s.stufen[kompetenz]! <= 1) s.id,
    };
    DateTime? zuletzt;
    for (final p in zustand.daten.pakete) {
      final f = p.foerderung;
      if (f == null || f.kompetenz != kompetenz || f.klasse != klasse.id) continue;
      final erreicht = <String>{};
      DateTime? am;
      for (final z in p.zuweisungen) {
        if (z.klasse != klasse.id) continue;
        erreicht.addAll(z.verteilung.keys);
        if (am == null || z.am.isAfter(am)) am = z.am;
      }
      if (am != null && erreicht.containsAll(betroffen) && (zuletzt == null || am.isAfter(zuletzt))) zuletzt = am;
    }
    return zuletzt;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: zustand,
      builder: (context, _) {
        final kompetenzen = {for (final s in _k.schueler) ...s.stufen.keys}.toList()..sort();
        final proKompetenz = [
          for (final k in kompetenzen)
            () {
              final mit = [for (final s in _k.schueler) ?s.stufen[k]];
              return (k, mit.where((x) => x <= 1).length, mit.reduce((a, b) => a + b) / mit.length);
            }(),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        final mitAufgaben = {for (final a in zustand.aufgaben) ...a.kompetenzen};
        final pakete = [
          for (final p in zustand.daten.pakete)
            if (p.zuweisungen.any((z) => z.klasse == klasse.id)) p,
        ];
        final zuweisungen = [
          for (final p in pakete)
            for (final z in p.zuweisungen)
              if (z.klasse == klasse.id) (p, z),
        ]..sort((a, b) => b.$2.am.compareTo(a.$2.am));
        final jetzt = LehreZustand.uhr();
        final mitDaten = [
          for (final s in _k.schueler)
            if (s.stufen.isNotEmpty) s,
        ];
        final mittel = mitDaten.isEmpty ? 0.0 : mitDaten.fold<double>(0, (n, s) => n + s.mittel) / mitDaten.length;
        final verteilung = {
          for (final g in ['sicher', 'teils sicher', 'unsicher']) g: _k.schueler.where((s) => s.gesamt == g).length,
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
                  Text('${_k.name} · ${_k.lernwelt}. Klasse', style: text.titleMedium),
                  const Spacer(),
                  OutlinedButton.icon(
                    key: const ValueKey('klasse-schueler-ansicht'),
                    onPressed: () => aktionen.oeffne(SchuelerAnsicht(zustand: zustand)),
                    icon: const Icon(Icons.phone_iphone, size: 18),
                    label: const Text('Schüler*innen-Ansicht'),
                  ),
                  const SizedBox(width: 8),
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
                            '${mitDaten.isEmpty ? 'Noch keine Antworten' : 'Mittel ${ikmStufen[mittel.round().clamp(0, 3)]}'} · ${verteilung['sicher']} sicher, '
                            '${verteilung['teils sicher']} teils sicher, ${verteilung['unsicher']} unsicher',
                        kind: proKompetenz.isEmpty
                            ? Text(
                                'Noch keine Antworten. Pakete zuweisen und in der Schüler*innen-Ansicht lösen.',
                                key: const ValueKey('kompetenzen-leer'),
                                style: text.bodySmall,
                              )
                            : ListView(
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
                                            child: _foerderZelle(context, k, n, mitAufgaben.contains(k)),
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
                          key: const ValueKey('klasse-zuweisen'),
                          onPressed: () => _zuweisen(context),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Paket zuweisen'),
                        ),
                        kind: zuweisungen.isEmpty
                            ? Text('Noch keine. Mit „Paket zuweisen“ verschicken.', style: text.bodySmall)
                            : ListView(
                                children: [
                                  for (final (p, z) in zuweisungen)
                                    ListTile(
                                      key: ValueKey('zuweisung-${p.id}-${z.am.microsecondsSinceEpoch}'),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        p.foerderung == null ? Icons.inventory_2_outlined : Icons.healing_outlined,
                                        size: 20,
                                      ),
                                      title: Text(p.anzeigeName(z.version)),
                                      subtitle: Text(_zuweisungZeile(p, z, jetzt)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => aktionen.oeffne(
                                        ZuweisungSeite(
                                          zustand: zustand,
                                          paket: p,
                                          zuweisung: z,
                                          klasse: klasse,
                                          onPerson: (person, gruppe) => aktionen.oeffne(
                                            PaketErgebnisSeite(
                                              zustand: zustand,
                                              klasse: klasse,
                                              person: person,
                                              paket: p,
                                              zuweisung: z,
                                              gruppe: gruppe,
                                            ),
                                          ),
                                        ),
                                      ),
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
                    borderRadius: BorderRadius.circular(16),
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
                      for (final s in _k.schueler)
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
                              child: Text('${zuweisungen.where((x) => x.$2.verteilung.containsKey(s.id)).length}'),
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

  Widget _foerderZelle(BuildContext context, String k, int n, bool mitAufgaben) {
    if (n == 0) return const SizedBox.shrink();
    final am = _foerderungVerschickt(k);
    if (am != null) {
      return Text(
        'verschickt am ${datumText(am)}',
        key: ValueKey('foerder-verschickt-$k'),
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return TextButton(
      key: ValueKey('foerder-$k'),
      onPressed: mitAufgaben ? () => _foerderpaket(context, k) : null,
      child: Text(mitAufgaben ? 'Förderpaket' : 'keine Aufgaben'),
    );
  }

  String _zuweisungZeile(Paket p, Zuweisung z, DateTime jetzt) {
    final fertig = [
      for (final id in z.verteilung.keys)
        if (abgabeStand(id, z, zustand.daten.abgaben, jetzt).fertig) id,
    ].length;
    return [
      'am ${datumText(z.am)}',
      z.verteilung.length == _k.schueler.length ? 'an alle' : 'an ${z.verteilung.length} Personen',
      if (z.abgabe != null) 'Abgabe ${datumText(z.abgabe!)}',
      '$fertig/${z.verteilung.length} fertig',
    ].join(' · ');
  }

  Widget _gesamt(String g) {
    if (g == 'noch offen') return Marke(g);
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
          if (z.klasse == klasse.id && z.verteilung.containsKey(person.id)) (p, z, z.verteilung[person.id]!),
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
                          for (final (p, z, gruppe) in pakete)
                            ListTile(
                              key: ValueKey('ergebnis-${p.id}-${z.id}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.anzeigeName(z.version)),
                              subtitle: Text('${z.gruppen > 1 ? 'Gruppe $gruppe · ' : ''}${p.plaetze.length} Aufgaben'),
                              trailing: Text(_quote(z), style: text.bodySmall),
                              onTap: () => oeffne(
                                PaketErgebnisSeite(
                                  zustand: zustand,
                                  klasse: klasse,
                                  person: person,
                                  paket: p,
                                  zuweisung: z,
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

  String _quote(Zuweisung z) {
    final a = zustand.antworten(person.id, z.id);
    if (a.isEmpty) return 'noch offen';
    return '${a.where((x) => x.richtig).length}/${a.length} richtig';
  }
}

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
    required this.zuweisung,
    required this.gruppe,
  });

  final LehreZustand zustand;
  final TestKlasse klasse;
  final TestSchuelerin person;
  final Paket paket;
  final Zuweisung zuweisung;
  final String gruppe;

  @override
  State<PaketErgebnisSeite> createState() => _PaketErgebnisSeiteState();
}

class _PaketErgebnisSeiteState extends State<PaketErgebnisSeite> {
  int _auswahl = 0;
  List<String> _ids = const [];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ids = aufgabenDerGruppe(widget.paket, widget.gruppe);
    final antworten = widget.zustand.antworten(widget.person.id, widget.zuweisung.id)
      ..sort((a, b) => ids.indexOf(a.aufgabe).compareTo(ids.indexOf(b.aufgabe)));
    _ids = ids;
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
                  '${widget.person.name} · ${widget.paket.anzeigeName(widget.zuweisung.version)}'
                  '${widget.zuweisung.gruppen > 1 ? ' · Gruppe ${widget.gruppe}' : ''}',
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

  Widget _antwortKarte(BuildContext context, int i, SchuelerVersuch a) {
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: i == _auswahl ? tutoBlau : linie, width: i == _auswahl ? 2 : 1),
      ),
      child: InkWell(
        key: ValueKey('antwort-$i'),
        borderRadius: BorderRadius.circular(16),
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
                      '${_ids.indexOf(a.aufgabe) + 1}. ${s?.titel ?? a.aufgabe}',
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
              if (a.antwort.isEmpty && !a.richtig)
                const Text('Antwort: „Weiß ich nicht“', style: TextStyle(color: fehlerRot))
              else if (a.antwort.isNotEmpty)
                Text(
                  a.selbstBewertet
                      ? 'Antwort: ${a.antwort} (selbst bewertet: ${a.r >= 1 ? 'richtig' : (a.r > 0 ? 'teilweise' : 'falsch')})'
                      : 'Antwort: ${a.antwort}',
                  style: TextStyle(color: a.richtig ? const Color(0xFF1B6B32) : (a.selbstBewertet ? tinte : fehlerRot)),
                ),
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
