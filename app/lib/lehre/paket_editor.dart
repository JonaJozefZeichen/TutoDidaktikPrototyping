import 'dart:math';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:printing/printing.dart';

import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/paket_pdf.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

/// Paket-Editor: Plätze per Hand füllen oder generieren, einzelne Plätze
/// sperren und neu würfeln, Gruppen A/B/C bilden, an eine Klasse zuweisen.
/// Jede Änderung wird sofort gespeichert.
class PaketEditor extends StatefulWidget {
  const PaketEditor({super.key, required this.zustand, required this.aktionen, required this.paketId});

  final LehreZustand zustand;
  final LehreAktionen aktionen;
  final String paketId;

  /// Zufallsquelle für den Generator; Tests setzen einen festen Seed.
  static Random Function() zufall = Random.new;

  @override
  State<PaketEditor> createState() => _PaketEditorState();
}

class _PaketEditorState extends State<PaketEditor> with SingleTickerProviderStateMixin {
  late Paket _p;
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final TextEditingController _titel;
  final _zufall = PaketEditor.zufall();

  /// Ausgewählter Platz für die Vorschau: (Gruppe, Index).
  (String, int)? _auswahl;
  bool _filterOffen = false;

  LehreZustand get z => widget.zustand;

  @override
  void initState() {
    super.initState();
    _p = Paket.fromJson(z.paket(widget.paketId)!.toJson());
    _titel = TextEditingController(text: _p.titel);
    if (_p.plaetze.isNotEmpty) _auswahl = ('A', 0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titel.dispose();
    super.dispose();
  }

  Future<void> _speichere() async {
    final f = await z.speicherePaket(_p);
    if (f != null && mounted) await zeigeMeldung(context, f, fehler: true);
  }

  /// Ändert die Plätze und hält die Gruppen B/C passend: Plätze mit derselben
  /// Aufgabe behalten ihre Gruppen-Aufgabe, neue bekommen eine neue.
  Future<void> _aendere(void Function() aenderung) async {
    final vorher = [for (final x in _p.plaetze) x.aufgabe];
    final alteGruppen = {
      for (final e in _p.gruppenPlaetze.entries) e.key: [...e.value],
    };
    setState(aenderung);
    if (_p.gruppen > 1) {
      final belegt = {for (final x in _p.plaetze) x.aufgabe};
      final neu = <String, List<GruppenPlatz>>{};
      for (var g = 1; g < _p.gruppen; g++) {
        final name = gruppenName(g);
        final alt = alteGruppen[name] ?? const <GruppenPlatz>[];
        final liste = <GruppenPlatz>[];
        for (final platz in _p.plaetze) {
          final i = vorher.indexOf(platz.aufgabe);
          final behalten = i >= 0 && i < alt.length ? alt[i] : null;
          final gp = behalten ?? gruppenPlatzFuer(platz, g, z.nachId, belegt);
          if (gp.aufgabe != null && gp.art != GruppenArt.parameter) belegt.add(gp.aufgabe!);
          liste.add(gp);
        }
        neu[name] = liste;
      }
      _p.gruppenPlaetze
        ..clear()
        ..addAll(neu);
    }
    final a = _auswahl;
    if (a != null && a.$2 >= _p.plaetze.length) _auswahl = _p.plaetze.isEmpty ? null : ('A', _p.plaetze.length - 1);
    await _speichere();
  }

  PaketGenerator get _generator => PaketGenerator(z.generatorPool(_p), gemerkt: z.daten.gemerkt);

  Future<void> _generieren() async {
    final pool = z.generatorPool(_p);
    if (pool.isEmpty) {
      await zeigeMeldung(context, 'Keine Aufgabe passt zu Quelle und Filtern.', fehler: true);
      return;
    }
    final neu = _generator.fuelle(_p.plaetze, _p.einstellung, _zufall.nextInt(1 << 31), alle: z.nachId);
    await _aendere(() {
      _p.plaetze
        ..clear()
        ..addAll(neu);
      if (_p.plaetze.isNotEmpty) _auswahl = ('A', 0);
    });
    if (!mounted) return;
    final gewuenscht = _p.einstellung.zielMinuten == null ? _p.einstellung.anzahl : null;
    if (gewuenscht != null && neu.length < gewuenscht) {
      await zeigeMeldung(context, 'Nur ${neu.length} passende Aufgaben gefunden. Filter lockern?', fehler: true);
    }
  }

  Future<void> _neuWuerfeln(int i) async {
    final neu = _generator.neuWuerfeln(_p.plaetze, i, _p.einstellung, _zufall.nextInt(1 << 31));
    if (neu == null) {
      await zeigeMeldung(context, 'Keine andere passende Aufgabe in der Quelle.', fehler: true);
      return;
    }
    await _aendere(() {
      _p.plaetze[i] = neu;
      _auswahl = ('A', i);
    });
  }

  Future<void> _austauschen(int i) async {
    final vorschlaege = PaketGenerator(z.aufgaben, gemerkt: z.daten.gemerkt).vorschlaege(_p.plaetze, i, alle: z.nachId);
    final id = await waehleAufgabe(
      context,
      zustand: z,
      titel: 'Platz ${i + 1} austauschen',
      vorschlaege: vorschlaege,
      vorschlagTitel: 'Passend (gleiche Kompetenz, gemerkte zuerst)',
      ausgeschlossen: {for (final p in _p.plaetze) p.aufgabe},
    );
    if (id == null) return;
    await _aendere(() {
      _p.plaetze[i] = PaketPlatz.von(z.nachId[id]!, gesperrt: _p.plaetze[i].gesperrt);
      _auswahl = ('A', i);
    });
  }

  Future<void> _hinzufuegen() async {
    final id = await waehleAufgabe(
      context,
      zustand: z,
      titel: 'Aufgabe hinzufügen',
      ausgeschlossen: {for (final p in _p.plaetze) p.aufgabe},
    );
    if (id == null) return;
    await _aendere(() {
      _p.plaetze.add(PaketPlatz.von(z.nachId[id]!));
      _auswahl = ('A', _p.plaetze.length - 1);
    });
  }

  Future<void> _gruppenSetzen(int zahl) async {
    setState(() {
      _p.gruppen = zahl;
      _p.gruppenPlaetze
        ..clear()
        ..addAll(bildeGruppen(_p.plaetze, zahl, z.nachId));
    });
    await _speichere();
  }

  Future<void> _gruppenAustauschen(String gruppe, int i) async {
    final original = z.nachId[_p.plaetze[i].aufgabe];
    final belegt = {
      for (final x in _p.plaetze) x.aufgabe,
      for (final l in _p.gruppenPlaetze.values)
        for (final g in l) ?g.aufgabe,
    };
    final ersatz = original == null ? <StoreAufgabe>[] : ersatzKandidaten(original, z.nachId, belegt);
    final id = await waehleAufgabe(
      context,
      zustand: z,
      titel: 'Gruppe $gruppe, Platz ${i + 1}',
      vorschlaege: ersatz,
      vorschlagTitel: 'Ersatz: gleiche Kompetenz, ähnliche Schwierigkeit, gleicher Aufgabentyp zuerst',
      ausgeschlossen: belegt,
    );
    if (id == null) return;
    final a = z.nachId[id]!;
    final art = a.variantengruppe != null && a.variantengruppe == original?.variantengruppe
        ? GruppenArt.variante
        : (original != null && a.formatGruppenSet.intersection(original.formatGruppenSet).isEmpty
              ? GruppenArt.ersatzTyp
              : GruppenArt.ersatz);
    setState(() {
      _p.gruppenPlaetze[gruppe]![i] = GruppenPlatz(aufgabe: id, fassung: a.fassung, art: art);
      _auswahl = (gruppe, i);
    });
    await _speichere();
  }

  /// Förderpakete gehen ohne Rückfrage nur an die Personen, die die
  /// Förderung brauchen; andere Pakete an eine gewählte Klasse.
  Future<void> _zuweisen() async {
    final f = _p.foerderung;
    final TestKlasse? klasse;
    if (f != null) {
      klasse = z.klassen.where((k) => k.id == f.klasse).firstOrNull;
    } else {
      klasse = await showDialog<TestKlasse>(
        context: context,
        builder: (d) => SimpleDialog(
          title: const Text('An Klasse zuweisen (Testdaten)'),
          children: [
            for (final k in z.klassen)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(d, k),
                child: Text('${k.name} · ${k.lernwelt}. Klasse · ${k.schueler.length} Personen'),
              ),
          ],
        ),
      );
    }
    if (klasse == null || !mounted) return;
    final personen = [
      for (final s in klasse.schueler)
        if (f == null || f.schueler.contains(s.id)) s.id,
    ];
    final meldung = weiseZu(_p, klasse, personen);
    setState(() {});
    await _speichere();
    if (mounted) await zeigeMeldung(context, meldung);
  }

  /// Drucken als PDF: Gruppen wählen, auf Wunsch mit Lösungsblatt.
  Future<void> _drucken() async {
    final namen = gruppenNamenBis(_p.gruppen);
    final gewaehlt = {...namen};
    var loesungen = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Drucken / PDF'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (namen.length > 1) ...[
                  const Text('Gruppen'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final g in namen)
                        FilterChip(
                          label: Text(g),
                          selected: gewaehlt.contains(g),
                          onSelected: (v) => setD(() => v ? gewaehlt.add(g) : gewaehlt.remove(g)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  key: const ValueKey('pdf-loesungen'),
                  contentPadding: EdgeInsets.zero,
                  value: loesungen,
                  title: const Text('Lösungsblatt pro Gruppe anhängen'),
                  onChanged: (v) => setD(() => loesungen = v),
                ),
                Text(
                  'Unten auf jeder Seite steht „© Tuto · Aufgaben aus dem Tuto-Aufgabenbestand“. '
                  'SRDP-Aufgaben tragen ihre ID neben dem Titel und einen Quellenhinweis.',
                  style: Theme.of(d).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
            FilledButton(
              key: const ValueKey('pdf-erzeugen'),
              onPressed: gewaehlt.isEmpty ? null : () => Navigator.pop(d, true),
              child: const Text('PDF erzeugen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final blaetter = paketBlaetter(
      _p,
      z.nachId,
      gruppen: [
        for (final g in namen)
          if (gewaehlt.contains(g)) g,
      ],
      mitLoesungen: loesungen,
    );
    final bytes = await paketPdf(blaetter);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: '${_p.titel}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: z,
      builder: (context, _) {
        final minuten = z.minuten(_p.plaetze.map((x) => x.aufgabe));
        final text = Theme.of(context).textTheme;
        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('paket-zurueck'),
                        tooltip: 'Zurück',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          key: const ValueKey('paket-titel'),
                          controller: _titel,
                          style: text.titleMedium,
                          decoration: const InputDecoration(hintText: 'Titel des Pakets'),
                          onSubmitted: (_) => _speichere(),
                          onChanged: (v) => _p.titel = v.trim().isEmpty ? 'Paket' : v.trim(),
                          onEditingComplete: _speichere,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_p.plaetze.length} Aufgaben · ${minutenText(minuten)}',
                        key: const ValueKey('paket-summe'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        key: const ValueKey('als-warenkorb'),
                        onPressed: z.offenesPaket == _p.id ? null : () => setState(() => z.offenesPaket = _p.id),
                        icon: Icon(z.offenesPaket == _p.id ? Icons.check : Icons.add_shopping_cart, size: 18),
                        label: Text(z.offenesPaket == _p.id ? 'Store legt hier hinein' : 'Aus dem Store befüllen'),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        key: const ValueKey('paket-drucken'),
                        onPressed: _p.plaetze.isEmpty ? null : _drucken,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Drucken / PDF'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const ValueKey('paket-zuweisen'),
                        onPressed: _p.plaetze.isEmpty ? null : _zuweisen,
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Zuweisen'),
                      ),
                    ],
                  ),
                  if (_p.foerderung case final f?)
                    Container(
                      key: const ValueKey('foerder-hinweis'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE4ECFA), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Förderpaket „${f.kompetenz}“ für ${f.schueler.length} '
                        '${f.schueler.length == 1 ? 'Person' : 'Personen'} der '
                        '${z.klassen.where((k) => k.id == f.klasse).firstOrNull?.name ?? f.klasse}. '
                        'Zuweisen schickt es direkt an diese Personen.',
                        style: const TextStyle(color: tutoBlau, fontWeight: FontWeight.w600),
                      ),
                    ),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      const Tab(key: ValueKey('tab-aufgaben'), text: 'Aufgaben'),
                      Tab(
                        key: const ValueKey('tab-gruppen'),
                        text: _p.gruppen == 1 ? 'Gruppen' : 'Gruppen (${_p.gruppen})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, groesse) {
                  final mitVorschau = groesse.maxWidth >= 1250;
                  final vorschauBreite = (groesse.maxWidth * 0.42).clamp(440.0, 700.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [_aufgabenTab(context, groesse.maxWidth), _gruppenTab(context)],
                        ),
                      ),
                      if (mitVorschau)
                        Container(
                          width: vorschauBreite,
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: linie)),
                          ),
                          child: _vorschau(context),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Tab Aufgaben ---

  Widget _aufgabenTab(BuildContext context, double breite) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          child: Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: linie)),
            ),
            child: _generatorSpalte(context),
          ),
        ),
        Expanded(child: _plaetzeListe(context)),
      ],
    );
  }

  Widget _generatorSpalte(BuildContext context) {
    final e = _p.einstellung;
    final text = Theme.of(context).textTheme;
    final quellen = <String>[
      'alle',
      for (final s in z.daten.suchen) 'suche:${s.id}',
      for (final o in z.daten.ordner)
        if (o.aufgaben.isNotEmpty || _p.quelle == 'ordner:${o.id}') 'ordner:${o.id}',
    ];
    if (!quellen.contains(_p.quelle)) quellen.add(_p.quelle);
    // Grundmenge der Quelle ohne die Zusatzfilter, für die Trefferzahlen.
    final basis = z.generatorPool(Paket(id: '', titel: '', erstellt: DateTime(0), quelle: _p.quelle));
    final pool = z.generatorPool(_p);
    final offen = _p.plaetze.where((x) => !x.gesperrt).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            children: [
              Text('Generator', style: text.titleMedium),
              const SizedBox(height: 8),
              Text('Woraus gewählt wird', style: text.labelMedium),
              DropdownButton<String>(
                key: const ValueKey('generator-quelle'),
                isExpanded: true,
                value: _p.quelle,
                items: [
                  for (final q in quellen)
                    DropdownMenuItem(
                      value: q,
                      child: Text(z.quelleName(q), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (q) {
                  setState(() => _p.quelle = q ?? 'alle');
                  _speichere();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Anzahl')),
                        ButtonSegment(value: true, label: Text('Minuten')),
                      ],
                      selected: {e.zielMinuten != null},
                      onSelectionChanged: (s) {
                        setState(() => e.zielMinuten = s.first ? 20 : null);
                        _speichere();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Weniger',
                    onPressed: () {
                      setState(() {
                        if (e.zielMinuten != null) {
                          e.zielMinuten = max(5, e.zielMinuten! - 5);
                        } else {
                          e.anzahl = max(1, e.anzahl - 1);
                        }
                      });
                      _speichere();
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      e.zielMinuten != null ? 'etwa ${e.zielMinuten} Minuten' : '${e.anzahl} Aufgaben',
                      key: const ValueKey('generator-menge'),
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('generator-mehr'),
                    tooltip: 'Mehr',
                    onPressed: () {
                      setState(() {
                        if (e.zielMinuten != null) {
                          e.zielMinuten = min(120, e.zielMinuten! + 5);
                        } else {
                          e.anzahl = min(PaketGenerator.maxPlaetze, e.anzahl + 1);
                        }
                      });
                      _speichere();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: e.aufsteigend,
                title: const Text('Leichte Aufgaben zuerst'),
                onChanged: (v) {
                  setState(() => e.aufsteigend = v ?? true);
                  _speichere();
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: e.formateMischen,
                title: const Text('Aufgabentypen mischen'),
                onChanged: (v) {
                  setState(() => e.formateMischen = v ?? true);
                  _speichere();
                },
              ),
              const Divider(),
              InkWell(
                onTap: () => setState(() => _filterOffen = !_filterOffen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _p.filter.anzahl == 0
                              ? 'Filter (Klasse, Kompetenz, Typ ...)'
                              : 'Filter (${_p.filter.anzahl})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(_filterOffen ? Icons.expand_less : Icons.expand_more, size: 20),
                    ],
                  ),
                ),
              ),
              if (_p.filter.anzahl > 0)
                AktiveFilter(
                  zustand: z,
                  filter: _p.filter,
                  onChanged: () {
                    setState(() {});
                    _speichere();
                  },
                ),
              if (_filterOffen)
                SizedBox(
                  height: 420,
                  child: FilterSpalte(
                    key: const ValueKey('generator-filter'),
                    zustand: z,
                    filter: _p.filter,
                    alle: basis,
                    ohneText: true,
                    onChanged: () {
                      setState(() {});
                      _speichere();
                    },
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: linie)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${pool.length} passende Aufgaben', style: text.bodySmall, key: const ValueKey('generator-pool')),
              const SizedBox(height: 6),
              FilledButton.icon(
                key: const ValueKey('generieren'),
                onPressed: _generieren,
                icon: const Icon(Icons.casino_outlined),
                label: Text(
                  _p.plaetze.isEmpty
                      ? 'Paket generieren'
                      : (offen == _p.plaetze.length ? 'Alle neu würfeln' : 'Offene neu würfeln ($offen)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plaetzeListe(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_p.plaetze.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 40, color: grauText),
              const SizedBox(height: 8),
              const Text('Noch leer.'),
              const SizedBox(height: 4),
              Text(
                'Links generieren lassen, oder Aufgaben per Hand aus Merkliste und Store hinzufügen.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('aufgabe-hinzufuegen'),
                onPressed: _hinzufuegen,
                icon: const Icon(Icons.add),
                label: const Text('Aufgabe hinzufügen'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Schloss: Platz bleibt beim Neu-Würfeln stehen. Würfel: nur diesen Platz neu. Ziehen: Reihenfolge ändern.',
            style: text.bodySmall,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            buildDefaultDragHandles: false,
            itemCount: _p.plaetze.length,
            onReorderItem: (alt, neu) => _aendere(() {
              _p.plaetze.insert(neu, _p.plaetze.removeAt(alt));
              _auswahl = ('A', neu);
            }),
            itemBuilder: (context, i) => _platz(context, i),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('aufgabe-hinzufuegen'),
                  onPressed: _hinzufuegen,
                  icon: const Icon(Icons.add),
                  label: const Text('Aufgabe hinzufügen'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _platz(BuildContext context, int i) {
    final p = _p.plaetze[i];
    final a = z.nachId[p.aufgabe];
    final gewaehlt = _auswahl == ('A', i);
    final aktuelleFassung = a != null && a.fassung != p.fassung;
    return Padding(
      key: ValueKey('platz-$i-${p.aufgabe}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.gesperrt ? const Color(0xFFEFF4FD) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: gewaehlt ? tutoBlau : linie, width: gewaehlt ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _auswahl = ('A', i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_indicator, color: grauText),
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontFamily: monoSchrift, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: ValueKey('sperren-$i'),
                  tooltip: p.gesperrt ? 'Entsperren' : 'Sperren (bleibt beim Würfeln)',
                  isSelected: p.gesperrt,
                  onPressed: () => _aendere(() => p.gesperrt = !p.gesperrt),
                  icon: const Icon(Icons.lock_open, color: grauText),
                  selectedIcon: const Icon(Icons.lock, color: tutoBlau),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: a == null
                      ? Text('${p.aufgabe}: nicht mehr verfügbar', style: const TextStyle(color: fehlerRot))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.titel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(eckdaten(a), style: Theme.of(context).textTheme.bodySmall),
                                for (final f in a.formate) Marke(formatNamen[f] ?? f),
                                Marke(minutenText(a.minuten), icon: Icons.schedule),
                                SchwierigkeitPunkte(a.schwierigkeitGerundet),
                                if (aktuelleFassung)
                                  const Tooltip(
                                    message: 'Das Didaktik-Team hat die Aufgabe inzwischen korrigiert.',
                                    child: Marke('neuere Fassung', farbe: hinweisGelb, grund: Color(0xFFFFF4D6)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
                IconButton(
                  key: ValueKey('wuerfeln-$i'),
                  tooltip: p.gesperrt ? 'Gesperrt' : 'Nur diesen Platz neu würfeln',
                  onPressed: p.gesperrt ? null : () => _neuWuerfeln(i),
                  icon: const Icon(Icons.casino_outlined),
                ),
                IconButton(
                  key: ValueKey('tauschen-$i'),
                  tooltip: 'Gezielt austauschen',
                  onPressed: () => _austauschen(i),
                  icon: const Icon(Icons.swap_horiz),
                ),
                IconButton(
                  key: ValueKey('entfernen-$i'),
                  tooltip: 'Entfernen',
                  onPressed: () => _aendere(() => _p.plaetze.removeAt(i)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Tab Gruppen ---

  Widget _gruppenTab(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gruppen = [for (var g = 1; g < _p.gruppen; g++) gruppenName(g)];
    final alle = [for (final g in gruppen) ...?_p.gruppenPlaetze[g]];
    final fehlt = alle.where((g) => g.art == GruppenArt.fehlt).length;
    final ersatz = alle.where((g) => g.art == GruppenArt.ersatz || g.art == GruppenArt.ersatzTyp).length;
    final andererTyp = alle.where((g) => g.art == GruppenArt.ersatzTyp).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Gruppen gegen Abschreiben', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Jede Gruppe bekommt gleichwertige Aufgaben: zuerst eine Variante aus derselben Variantengruppe, '
          'dann dieselbe Vorlage mit anderen Zahlen, sonst einen Ersatz mit gleicher Kompetenz und ähnlicher '
          'Schwierigkeit (gleicher Aufgabentyp bevorzugt).',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('gruppen-weniger'),
                  tooltip: 'Weniger Gruppen',
                  onPressed: _p.gruppen > 1 ? () => _gruppenSetzen(_p.gruppen - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  _p.gruppen == 1 ? '1 Gruppe' : '${_p.gruppen} Gruppen',
                  key: const ValueKey('gruppen-zahl'),
                  style: text.titleMedium,
                ),
                IconButton(
                  key: const ValueKey('gruppen-mehr'),
                  tooltip: 'Mehr Gruppen',
                  onPressed: _p.gruppen < maxGruppen ? () => _gruppenSetzen(_p.gruppen + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                Text(gruppenNamenBis(_p.gruppen).join(' · '), style: text.bodySmall),
              ],
            ),
            if (_p.gruppen > 1) ...[
              FilterChip(
                key: const ValueKey('antworten-mischen'),
                label: const Text('Antworten ab Gruppe B mischen'),
                selected: _p.antwortenMischen,
                onSelected: (v) {
                  setState(() => _p.antwortenMischen = v);
                  _speichere();
                },
              ),
              TextButton.icon(
                key: const ValueKey('gruppen-neu'),
                onPressed: () => _gruppenSetzen(_p.gruppen),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Gruppen neu bilden'),
              ),
            ],
          ],
        ),
        if (_p.gruppen > 1 && (fehlt > 0 || ersatz > 0)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(6)),
            child: Text(
              [
                if (ersatz > 0)
                  '$ersatz ${ersatz == 1 ? 'Platz hat' : 'Plätze haben'} einen Ersatz statt einer echten Variante. Bitte kurz ansehen.',
                if (andererTyp > 0)
                  'Davon $andererTyp mit anderem Aufgabentyp, weil es zu dieser Kompetenz noch keine gleichartige Aufgabe gibt.',
                if (fehlt > 0)
                  '$fehlt ${fehlt == 1 ? 'Platz hat' : 'Plätze haben'} keinen Ersatz. Mit dem Tauschen-Knopf eine Aufgabe wählen.',
              ].join('\n'),
              key: const ValueKey('gruppen-warnung'),
              style: const TextStyle(color: hinweisGelb, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_p.plaetze.isEmpty)
          Text('Zuerst Aufgaben ins Paket legen.', style: text.bodySmall)
        else
          // Bei vielen Gruppen scrollt die Tabelle waagrecht.
          _GruppenTabelle(
            breit: _p.gruppen > 3,
            child: Table(
              border: TableBorder.all(color: linie),
              columnWidths: _p.gruppen <= 3
                  ? const {0: FixedColumnWidth(36)}
                  : {
                      0: const FixedColumnWidth(36),
                      for (var c = 1; c <= _p.gruppen; c++) c: const FixedColumnWidth(260),
                    },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: flaeche),
                  children: [
                    const SizedBox.shrink(),
                    for (final g in gruppenNamenBis(_p.gruppen))
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Gruppe $g', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                for (var i = 0; i < _p.plaetze.length; i++)
                  TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text('${i + 1}')),
                      _gruppenZelle('A', i, _p.plaetze[i].aufgabe, GruppenArt.original),
                      for (final g in gruppen)
                        _gruppenZelle(
                          g,
                          i,
                          _p.gruppenPlaetze[g]?.elementAtOrNull(i)?.aufgabe,
                          _p.gruppenPlaetze[g]?.elementAtOrNull(i)?.art ?? GruppenArt.fehlt,
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _gruppenZelle(String gruppe, int i, String? id, GruppenArt art) {
    final a = id == null ? null : z.nachId[id];
    final gewaehlt = _auswahl == (gruppe, i);
    final (farbe, grund) = switch (art) {
      GruppenArt.original => (grauText, const Color(0xFFEDEFF3)),
      GruppenArt.variante || GruppenArt.parameter => (tutoBlau, const Color(0xFFE4ECFA)),
      GruppenArt.ersatz || GruppenArt.ersatzTyp => (hinweisGelb, const Color(0xFFFFF4D6)),
      GruppenArt.fehlt => (fehlerRot, const Color(0xFFFBE6E4)),
    };
    return InkWell(
      key: ValueKey('zelle-$gruppe-$i'),
      onTap: a == null ? null : () => setState(() => _auswahl = (gruppe, i)),
      child: Container(
        color: gewaehlt ? const Color(0xFFEFF4FD) : null,
        padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a?.titel ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Marke(art.bezeichnung, farbe: farbe, grund: grund),
                ],
              ),
            ),
            if (gruppe != 'A')
              IconButton(
                key: ValueKey('gruppe-tauschen-$gruppe-$i'),
                tooltip: 'Andere Aufgabe wählen',
                onPressed: () => _gruppenAustauschen(gruppe, i),
                icon: const Icon(Icons.swap_horiz, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // --- Vorschau ---

  Widget _vorschau(BuildContext context) {
    final a = _auswahl;
    if (a == null || a.$2 >= _p.plaetze.length) {
      return const Center(child: Text('Platz antippen für die Vorschau'));
    }
    final (gruppe, i) = a;
    final gp = gruppe == 'A' ? null : _p.gruppenPlaetze[gruppe]?.elementAtOrNull(i);
    final id = gruppe == 'A' ? _p.plaetze[i].aufgabe : gp?.aufgabe;
    final aufgabe = id == null ? null : z.nachId[id];
    if (aufgabe == null) return const Center(child: Text('Keine Aufgabe auf diesem Platz'));
    final g = gruppe.codeUnitAt(0) - 65;
    final inhalt = gruppe != 'A' && _p.antwortenMischen
        ? mischeAntworten(aufgabe.inhalt, g * 7919 + i)
        : aufgabe.inhalt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gruppe $gruppe, Platz ${i + 1}${gruppe != 'A' && _p.antwortenMischen ? ' (Antworten gemischt)' : ''}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (gp?.art == GruppenArt.parameter)
            Text('Gleiche Vorlage, in der App mit anderen Zahlen', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(aufgabe.titel, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => widget.aktionen.oeffneAufgabe(aufgabe.id), child: const Text('Details')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: HandyVorschau(
                key: ValueKey('paket-vorschau-$gruppe-$i-${aufgabe.id}-${_p.antwortenMischen}'),
                inhalt: inhalt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog zur Auswahl einer Aufgabe: Vorschläge, Merkliste, alle Aufgaben.
Future<String?> waehleAufgabe(
  BuildContext context, {
  required LehreZustand zustand,
  required String titel,
  List<StoreAufgabe> vorschlaege = const [],
  String vorschlagTitel = 'Vorschläge',
  Set<String> ausgeschlossen = const {},
}) {
  return showDialog<String>(
    context: context,
    builder: (d) => Dialog(
      child: SizedBox(
        width: 760,
        height: 620,
        child: _AufgabenWahl(
          zustand: zustand,
          titel: titel,
          vorschlaege: vorschlaege,
          vorschlagTitel: vorschlagTitel,
          ausgeschlossen: ausgeschlossen,
        ),
      ),
    ),
  );
}

class _AufgabenWahl extends StatefulWidget {
  const _AufgabenWahl({
    required this.zustand,
    required this.titel,
    required this.vorschlaege,
    required this.vorschlagTitel,
    required this.ausgeschlossen,
  });

  final LehreZustand zustand;
  final String titel;
  final List<StoreAufgabe> vorschlaege;
  final String vorschlagTitel;
  final Set<String> ausgeschlossen;

  @override
  State<_AufgabenWahl> createState() => _AufgabenWahlState();
}

class _AufgabenWahlState extends State<_AufgabenWahl> {
  String _text = '';
  String _ordner = standardOrdner;

  bool _passt(StoreAufgabe a) => (StoreFilter()..text = _text).passt(a);

  Widget _liste(List<StoreAufgabe> liste, String leer) {
    final sichtbar = [
      for (final a in liste)
        if (!widget.ausgeschlossen.contains(a.id) && _passt(a)) a,
    ];
    if (sichtbar.isEmpty) return Center(child: Text(leer, style: Theme.of(context).textTheme.bodySmall));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sichtbar.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => AufgabenKarte(
        zustand: widget.zustand,
        aufgabe: sichtbar[i],
        onOeffnen: () => Navigator.pop(context, sichtbar[i].id),
        zusatz: Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: ValueKey('waehlen-${sichtbar[i].id}'),
            onPressed: () => Navigator.pop(context, sichtbar[i].id),
            child: const Text('Wählen'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zustand;
    final mitVorschlag = widget.vorschlaege.isNotEmpty || widget.vorschlagTitel != 'Vorschläge';
    final ordner = z.daten.ordnerMit(_ordner) ?? z.daten.ordnerMit(standardOrdner)!;
    return DefaultTabController(
      length: mitVorschlag ? 3 : 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text(widget.titel, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('wahl-suche'),
              decoration: const InputDecoration(hintText: 'Suchen', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _text = v),
            ),
          ),
          TabBar(
            tabs: [
              if (mitVorschlag) const Tab(text: 'Vorschläge'),
              Tab(text: 'Merkliste (${z.daten.gemerkt.length})'),
              const Tab(key: ValueKey('wahl-alle'), text: 'Alle Aufgaben'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (mitVorschlag)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Text(widget.vorschlagTitel, style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Expanded(
                        child: _liste(widget.vorschlaege, 'Kein passender Vorschlag. Im Tab „Alle Aufgaben“ suchen.'),
                      ),
                    ],
                  ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: ordner.id,
                        items: [
                          for (final o in z.daten.ordner)
                            DropdownMenuItem(value: o.id, child: Text('${o.name} (${o.aufgaben.length})')),
                        ],
                        onChanged: (v) => setState(() => _ordner = v ?? standardOrdner),
                      ),
                    ),
                    Expanded(
                      child: _liste([for (final id in ordner.aufgaben) ?z.nachId[id]], 'In diesem Ordner ist nichts.'),
                    ),
                  ],
                ),
                _liste(z.aufgaben, 'Nichts gefunden.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bis drei Gruppen füllt die Tabelle die Breite, darüber scrollt sie waagrecht.
class _GruppenTabelle extends StatelessWidget {
  const _GruppenTabelle({required this.breit, required this.child});

  final bool breit;
  final Widget child;

  @override
  Widget build(BuildContext context) => breit
      ? SingleChildScrollView(key: const ValueKey('gruppen-tabelle'), scrollDirection: Axis.horizontal, child: child)
      : child;
}
