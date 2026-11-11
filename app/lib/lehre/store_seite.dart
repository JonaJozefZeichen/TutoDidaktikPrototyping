import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

/// Was die Seiten des Bereichs für Lehrende aufrufen, um zu navigieren.
class LehreAktionen {
  const LehreAktionen({
    required this.oeffneAufgabe,
    required this.oeffnePaket,
    required this.oeffneZuweisen,
    required this.oeffne,
  });

  final void Function(String id) oeffneAufgabe;
  final void Function(String paketId) oeffnePaket;

  /// Zentrale Zuweisen-Ansicht, optional mit Paket und Vorauswahl.
  final void Function({String? paketId, Map<String, Set<String>>? auswahl}) oeffneZuweisen;
  final void Function(Widget seite) oeffne;
}

/// Aufgabenkatalog: Suchfeld oben, Filter links, Treffer als Karten.
class KatalogSeite extends StatefulWidget {
  const KatalogSeite({super.key, required this.zustand, required this.aktionen, required this.filter});

  final LehreZustand zustand;
  final LehreAktionen aktionen;

  /// Bleibt beim Seitenwechsel erhalten.
  final StoreFilter filter;

  @override
  State<KatalogSeite> createState() => _KatalogSeiteState();
}

class _KatalogSeiteState extends State<KatalogSeite> {
  late final _suche = TextEditingController(text: widget.filter.text);
  bool _raster = true;

  StoreFilter get _f => widget.filter;

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  void _neu() => setState(() {
    if (_suche.text != _f.text) _suche.text = _f.text;
  });

  Future<void> _sucheSpeichern() async {
    final name = await frageText(context, titel: 'Suche speichern', hinweis: 'z. B. Lineare Funktionen, Sport');
    if (name == null || !mounted) return;
    final fehler = await widget.zustand.aendere(
      (d) => d.suchen.add(GespeicherteSuche(id: LehreZustand.neueId('suche'), name: name, filter: _f.kopie())),
    );
    if (mounted) {
      await zeigeMeldung(
        context,
        fehler ?? 'Gespeichert. Die Suche steht in der Merkliste und im Generator als Quelle.',
        fehler: fehler != null,
      );
    }
  }

  Future<void> _insPaket(String id) async {
    final (p, fehler) = await widget.zustand.insPaket(id);
    if (!mounted) return;
    await zeigeMeldung(
      context,
      fehler ?? 'In „${p.titel}“ gelegt (${p.plaetze.length} Aufgaben)',
      fehler: fehler != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zustand;
    return ListenableBuilder(
      listenable: z,
      builder: (context, _) {
        final treffer = _f.treffer(z.aufgaben, varianten: z.varianten);
        final paket = z.paket(z.offenesPaket);
        final imPaket = {for (final p in paket?.plaetze ?? const <PaketPlatz>[]) p.aufgabe};
        return LayoutBuilder(
          builder: (context, groesse) {
            final schmal = groesse.maxWidth < 860;
            final filter = FilterSpalte(zustand: z, filter: _f, alle: z.aufgaben, onChanged: _neu);
            return Column(
              children: [
                _kopf(context, schmal, filter),
                if (z.auchUnfreigegebene) _testHinweis(context),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!schmal)
                        Container(
                          width: 290,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(right: BorderSide(color: linie)),
                          ),
                          child: filter,
                        ),
                      Expanded(child: _treffer(context, treffer, imPaket)),
                    ],
                  ),
                ),
                if (paket != null) _paketLeiste(context, paket),
              ],
            );
          },
        );
      },
    );
  }

  Widget _kopf(BuildContext context, bool schmal, Widget filter) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('store-suche'),
            controller: _suche,
            decoration: const InputDecoration(
              hintText: 'Wonach suchst du? Titel, Thema, Kompetenz, Level ...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _f.text = v),
          ),
        ),
        if (schmal) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const ValueKey('filter-blatt'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: StatefulBuilder(
                  builder: (c, setBlatt) => FilterSpalte(
                    zustand: widget.zustand,
                    filter: _f,
                    alle: widget.zustand.aufgaben,
                    onChanged: () {
                      setBlatt(() {});
                      _neu();
                    },
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(_f.anzahl == 0 ? 'Filter' : 'Filter (${_f.anzahl})'),
          ),
        ],
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: const ValueKey('suche-speichern'),
          onPressed: _f.istLeer ? null : _sucheSpeichern,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('Suche speichern'),
        ),
      ],
    ),
  );

  Widget _testHinweis(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFFFF1CC),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 16, color: hinweisGelb),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Teststand: Es werden auch noch nicht freigegebene Aufgaben gezeigt. Lehrpersonen sehen später nur Live-Aufgaben.',
            style: TextStyle(fontSize: 12, color: hinweisGelb, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          key: const ValueKey('nur-live'),
          onPressed: () => widget.zustand.setzeAuchUnfreigegebene(false),
          child: const Text('Nur Live zeigen'),
        ),
      ],
    ),
  );

  Widget _treffer(BuildContext context, List<StoreAufgabe> treffer, Set<String> imPaket) {
    final z = widget.zustand;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${treffer.length} ${treffer.length == 1 ? 'Aufgabe' : 'Aufgaben'}',
                        key: const ValueKey('trefferzahl'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    DropdownButton<Sortierung>(
                      value: _f.sortierung,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final s in Sortierung.values) DropdownMenuItem(value: s, child: Text(s.bezeichnung)),
                      ],
                      onChanged: (s) => setState(() => _f.sortierung = s ?? Sortierung.passend),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, icon: Icon(Icons.grid_view, size: 18), tooltip: 'Raster'),
                        ButtonSegment(value: false, icon: Icon(Icons.view_list, size: 18), tooltip: 'Liste'),
                      ],
                      selected: {_raster},
                      onSelectionChanged: (s) => setState(() => _raster = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AktiveFilter(zustand: z, filter: _f, onChanged: _neu),
              ],
            ),
          ),
        ),
        if (treffer.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 40, color: grauText),
                  const SizedBox(height: 8),
                  Text(
                    z.aufgaben.isEmpty
                        ? 'Noch keine freigegebenen Aufgaben.'
                        : 'Keine Aufgabe passt zu diesen Filtern. Entferne einen Filter oben.',
                  ),
                  if (z.aufgaben.isEmpty && !z.auchUnfreigegebene)
                    TextButton(
                      onPressed: () => z.setzeAuchUnfreigegebene(true),
                      child: const Text('Im Test auch Entwürfe zeigen'),
                    ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: _raster
                ? SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 236,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _karte(treffer[i], imPaket),
                      childCount: treffer.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: treffer.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _karte(treffer[i], imPaket),
                  ),
          ),
      ],
    );
  }

  Widget _karte(StoreAufgabe a, Set<String> imPaket) => AufgabenKarte(
    zustand: widget.zustand,
    aufgabe: a,
    onOeffnen: () => widget.aktionen.oeffneAufgabe(a.id),
    onInsPaket: () => _insPaket(a.id),
    imPaket: imPaket.contains(a.id),
  );

  Widget _paketLeiste(BuildContext context, Paket p) {
    final z = widget.zustand;
    return Container(
      key: const ValueKey('paket-leiste'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: linie)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: tutoBlau),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mit dem Katalog verbunden: „+ Ins Paket“ legt in „${p.titel}“ · ${p.plaetze.length} Aufgaben · '
              '${minutenText(z.minuten(p.plaetze.map((x) => x.aufgabe)))}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: () => setState(() => z.offenesPaket = null), child: const Text('Trennen')),
          FilledButton(
            key: const ValueKey('zum-paket'),
            onPressed: () => widget.aktionen.oeffnePaket(p.id),
            child: const Text('Zum Paket'),
          ),
        ],
      ),
    );
  }
}

/// Eine Aufgabe im Detail: Vorschau wie am Handy, Eckdaten, Varianten und
/// ähnliche Aufgaben.
class AufgabeDetailSeite extends StatelessWidget {
  const AufgabeDetailSeite({super.key, required this.zustand, required this.aktionen, required this.id});

  final LehreZustand zustand;
  final LehreAktionen aktionen;
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: zustand,
      builder: (context, _) {
        final a = zustand.nachId[id];
        if (a == null) {
          return const Center(child: Text('Diese Aufgabe ist nicht (mehr) verfügbar.'));
        }
        final text = Theme.of(context).textTheme;
        final varianten = [
          for (final x in zustand.aufgaben)
            if (x.id != a.id && a.variantengruppe != null && x.variantengruppe == a.variantengruppe) x,
        ];
        final aehnlich = [
          for (final x in zustand.aufgaben)
            if (x.id != a.id && x.hauptkompetenz == a.hauptkompetenz && !varianten.contains(x)) x,
        ].take(6).toList();
        final paket = zustand.paket(zustand.offenesPaket);
        final imPaket = paket?.plaetze.any((p) => p.aufgabe == a.id) ?? false;
        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('detail-zurueck'),
                    tooltip: 'Zurück',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(a.titel, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                  ),
                  MerkKnopf(zustand: zustand, id: a.id),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Melden kommt mit Phase 6 (Meldungen an das Didaktik-Team)',
                    child: TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Melden'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    key: const ValueKey('detail-ins-paket'),
                    onPressed: imPaket
                        ? null
                        : () async {
                            final (p, f) = await zustand.insPaket(a.id);
                            if (context.mounted) {
                              await zeigeMeldung(context, f ?? 'In „${p.titel}“ gelegt', fehler: f != null);
                            }
                          },
                    icon: Icon(imPaket ? Icons.check : Icons.add, size: 18),
                    label: Text(imPaket ? 'Im Paket' : 'Ins Paket'),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Links scrollt die Spalte mit ähnlichen Aufgaben und Informationen,
            // die Vorschau daneben steht fest (sie scrollt nie).
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: ListView(
                      key: const ValueKey('detail-spalte'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (varianten.isNotEmpty) ...[
                          Text('Varianten (gleichwertig)', style: text.titleMedium),
                          const SizedBox(height: 8),
                          for (final v in varianten) _kleineKarte(v),
                          const SizedBox(height: 12),
                        ],
                        Text('Ähnliche Aufgaben (gleiche Kompetenz)', style: text.titleMedium),
                        const SizedBox(height: 8),
                        if (aehnlich.isEmpty)
                          Text('Keine weiteren Aufgaben zu dieser Kompetenz.', style: text.bodySmall)
                        else
                          for (final v in aehnlich) _kleineKarte(v),
                        const SizedBox(height: 20),
                        Text('Informationen zur Aufgabe', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(eckdaten(a), style: text.labelMedium),
                        const SizedBox(height: 8),
                        _fakten(context, a),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, color: linie),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: HandyVorschau(key: ValueKey('vorschau-${a.id}'), inhalt: a.inhalt),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kleineKarte(StoreAufgabe v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AufgabenKarte(zustand: zustand, aufgabe: v, onOeffnen: () => aktionen.oeffneAufgabe(v.id)),
  );

  Widget _fakten(BuildContext context, StoreAufgabe a) {
    final zeilen = <(String, String)>[
      ('ID', a.id),
      ('Themenbereich', a.themenbereiche.map((t) => themenbereichNamen[t] ?? t).join(', ')),
      ('Lernziel (Level)', a.levels.map(zustand.levelName).join('\n')),
      ('Kompetenz', a.kompetenzen.join(', ')),
      if (a.grundkompetenzen.isNotEmpty) ('Grundkompetenz', a.grundkompetenzen.join(', ')),
      ('Aufgabentyp', a.formate.map((f) => formatNamen[f] ?? f).join(', ')),
      ('Handlungsbereich', a.handlungsbereiche.map((h) => handlungsbereichNamen[h] ?? h).join(', ')),
      ('Schwierigkeit', a.schwierigkeitGerundet == null ? '-' : schwierigkeitNamen[a.schwierigkeitGerundet]!),
      ('Dauer', '${a.sekundenGeschaetzt ? 'geschätzt ' : ''}${minutenText(a.minuten)}'),
      ('Kontext', kontextNamen[a.kontext] ?? '-'),
      ('Technologie', technologieNamen[a.technologie] ?? '-'),
      (
        'Aufbau',
        '${zusammenstellungNamen[a.zusammenstellung] ?? '-'}, ${a.itemZahl} ${a.itemZahl == 1 ? 'Teil' : 'Teile'}',
      ),
      ('Fassung', '${a.fassung} (${statusNamen[a.status] ?? a.status})'),
    ];
    return Table(
      columnWidths: const {0: FixedColumnWidth(140)},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final (k, v) in zeilen)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(k, style: Theme.of(context).textTheme.labelMedium),
              ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: SelectableText(v.isEmpty ? '-' : v)),
            ],
          ),
      ],
    );
  }
}
