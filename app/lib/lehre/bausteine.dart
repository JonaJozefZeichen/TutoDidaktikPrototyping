import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

/// Kleine Plakette für Werte wie Aufgabentyp oder Dauer.
class Marke extends StatelessWidget {
  const Marke(this.text, {super.key, this.farbe = grauText, this.grund = const Color(0xFFEDEFF3), this.icon});

  final String text;
  final Color farbe;
  final Color grund;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: grund, borderRadius: BorderRadius.circular(4)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: farbe), const SizedBox(width: 3)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: farbe),
          ),
        ),
      ],
    ),
  );
}

/// Schwierigkeit 1-5 als Punkte, mit Text für Screenreader und Tooltip.
class SchwierigkeitPunkte extends StatelessWidget {
  const SchwierigkeitPunkte(this.wert, {super.key});

  final int? wert;

  @override
  Widget build(BuildContext context) {
    final w = wert;
    final text = w == null ? 'Schwierigkeit unbekannt' : 'Schwierigkeit ${schwierigkeitNamen[w]}';
    return Tooltip(
      message: text,
      child: Semantics(
        label: text,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: w != null && i <= w ? tutoBlau : const Color(0xFFD5DBE4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String minutenText(double m) => m < 1 ? '< 1 min' : '${m.round()} min';

/// Werte einer Aufgabe in einer Zeile: Klasse, Themenbereich, Level.
String eckdaten(StoreAufgabe a) =>
    [if (a.klasse != null) '${a.klasse}. Klasse', ...a.themenbereiche, ...a.levels.take(2)].join(' · ');

/// Herz zum Merken. Ein Klick merkt im Standardordner oder nimmt die Aufgabe
/// aus allen Ordnern; das Menü daneben wählt einen bestimmten Ordner.
class MerkKnopf extends StatelessWidget {
  const MerkKnopf({super.key, required this.zustand, required this.id});

  final LehreZustand zustand;
  final String id;

  Future<void> _melde(BuildContext context, Future<String?> f) async {
    final fehler = await f;
    if (fehler != null && context.mounted) await zeigeMeldung(context, fehler, fehler: true);
  }

  Future<void> _neuerOrdner(BuildContext context) async {
    final name = await frageText(context, titel: 'Neuer Ordner', hinweis: 'z. B. Schularbeit 2');
    if (name == null || !context.mounted) return;
    await _melde(context, zustand.neuerOrdner(name, mitAufgabe: id));
  }

  @override
  Widget build(BuildContext context) {
    final gemerkt = zustand.istGemerkt(id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('merken-$id'),
          tooltip: gemerkt ? 'Nicht mehr merken' : 'Merken',
          visualDensity: VisualDensity.compact,
          onPressed: () => _melde(context, gemerkt ? zustand.entmerken(id) : zustand.merken(id)),
          icon: Icon(gemerkt ? Icons.favorite : Icons.favorite_border, color: gemerkt ? fehlerRot : grauText, size: 20),
        ),
        PopupMenuButton<String>(
          tooltip: 'In Ordner merken',
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: grauText),
          padding: EdgeInsets.zero,
          itemBuilder: (_) => [
            for (final o in zustand.daten.ordner)
              CheckedPopupMenuItem(value: o.id, checked: o.aufgaben.contains(id), child: Text(o.name)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: '+', child: Text('Neuer Ordner ...')),
          ],
          onSelected: (v) {
            if (v == '+') {
              _neuerOrdner(context);
            } else if (zustand.daten.ordnerMit(v)!.aufgaben.contains(id)) {
              _melde(context, zustand.entmerken(id, ordner: v));
            } else {
              _melde(context, zustand.merken(id, ordner: v));
            }
          },
        ),
      ],
    );
  }
}

Future<String?> frageText(BuildContext context, {required String titel, String? hinweis, String start = ''}) {
  final c = TextEditingController(text: start);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titel),
      content: SizedBox(
        width: 360,
        child: TextField(
          key: const ValueKey('text-dialog-feld'),
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hinweis),
          onSubmitted: (v) => Navigator.pop(d, v.trim().isEmpty ? null : v.trim()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Abbrechen')),
        FilledButton(
          key: const ValueKey('text-dialog-ok'),
          onPressed: () => Navigator.pop(d, c.text.trim().isEmpty ? null : c.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Karte einer Aufgabe im Store, in der Merkliste und in Auswahl-Dialogen.
class AufgabenKarte extends StatelessWidget {
  const AufgabenKarte({
    super.key,
    required this.zustand,
    required this.aufgabe,
    required this.onOeffnen,
    this.onInsPaket,
    this.imPaket = false,
    this.zusatz,
  });

  final LehreZustand zustand;
  final StoreAufgabe aufgabe;
  final VoidCallback onOeffnen;
  final VoidCallback? onInsPaket;
  final bool imPaket;
  final Widget? zusatz;

  @override
  Widget build(BuildContext context) {
    final a = aufgabe;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: linie),
      ),
      child: InkWell(
        key: ValueKey('karte-${a.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onOeffnen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eckdaten(a), style: text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(a.titel, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  MerkKnopf(zustand: zustand, id: a.id),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  a.vorschauText.replaceAll(RegExp(r'\s+'), ' '),
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final f in a.formate) Marke(formatNamen[f] ?? f),
                  Marke('${a.sekundenGeschaetzt ? '≈ ' : ''}${minutenText(a.minuten)}', icon: Icons.schedule),
                  SchwierigkeitPunkte(a.schwierigkeitGerundet),
                  if (a.kontext != null && a.kontext != 'innermathematisch')
                    Marke(kontextNamen[a.kontext] ?? a.kontext!),
                  if (hatVarianten(a, zustand.varianten))
                    const Marke('Varianten', farbe: tutoBlau, grund: Color(0xFFE4ECFA), icon: Icons.copy_all),
                  if (a.hatMedien) const Marke('Grafik', icon: Icons.image_outlined),
                  if (a.status != 'live')
                    Marke(
                      '${statusNamen[a.status] ?? a.status} (nur Test)',
                      farbe: hinweisGelb,
                      grund: const Color(0xFFFFF4D6),
                    ),
                ],
              ),
              if (zusatz != null) ...[const SizedBox(height: 6), zusatz!],
              if (onInsPaket != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('ins-paket-${a.id}'),
                    onPressed: imPaket ? null : onInsPaket,
                    icon: Icon(imPaket ? Icons.check : Icons.add, size: 18),
                    label: Text(imPaket ? 'Im Paket' : 'Ins Paket'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filterspalte wie bei bekannten Such-Portalen: aufklappbare Gruppen mit
/// Häkchen und Trefferzahl, Regler für Schwierigkeit, Dauer und Schalter.
class FilterSpalte extends StatefulWidget {
  const FilterSpalte({
    super.key,
    required this.zustand,
    required this.filter,
    required this.alle,
    required this.onChanged,
    this.ohneText = false,
  });

  final LehreZustand zustand;
  final StoreFilter filter;
  final List<StoreAufgabe> alle;
  final VoidCallback onChanged;

  /// Im Generator gibt es kein eigenes Suchfeld.
  final bool ohneText;

  @override
  State<FilterSpalte> createState() => _FilterSpalteState();
}

class _FilterSpalteState extends State<FilterSpalte> {
  final _offen = <String>{'klasse', 'themenbereich', 'format'};
  final _suche = <String, String>{};
  final _alleZeigen = <String>{};

  String _name(Facette f, String wert) => switch (f.schluessel) {
    'level' => widget.zustand.levelName(wert),
    _ => f.name(wert),
  };

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    final text = Theme.of(context).textTheme;
    final varianten = widget.zustand.varianten;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        for (final fac in facetten) _gruppe(fac, f, varianten),
        _rahmen(
          'schwierigkeit',
          'Schwierigkeit',
          aktiv: f.schwierigkeitVon > 1 || f.schwierigkeitBis < 5,
          kind: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RangeSlider(
                values: RangeValues(f.schwierigkeitVon.toDouble(), f.schwierigkeitBis.toDouble()),
                min: 1,
                max: 5,
                divisions: 4,
                labels: RangeLabels(schwierigkeitNamen[f.schwierigkeitVon]!, schwierigkeitNamen[f.schwierigkeitBis]!),
                onChanged: (r) {
                  f.schwierigkeitVon = r.start.round();
                  f.schwierigkeitBis = r.end.round();
                  widget.onChanged();
                },
              ),
              Text(
                'von ${schwierigkeitNamen[f.schwierigkeitVon]} bis ${schwierigkeitNamen[f.schwierigkeitBis]}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        _rahmen(
          'dauer',
          'Dauer pro Aufgabe',
          aktiv: f.maxMinuten != null,
          kind: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in [null, 2, 3, 5, 10, 15])
                ChoiceChip(
                  label: Text(m == null ? 'egal' : 'bis $m min'),
                  selected: f.maxMinuten == m,
                  onSelected: (_) {
                    f.maxMinuten = m;
                    widget.onChanged();
                  },
                ),
            ],
          ),
        ),
        _rahmen(
          'extras',
          'Weitere',
          aktiv: f.nurMitVarianten || f.nurMitGrafik,
          kind: Column(
            children: [
              _haken(
                'Mit Varianten (für A/B/C)',
                f.nurMitVarianten,
                widget.alle.where((a) => hatVarianten(a, varianten)).length,
                (v) => f.nurMitVarianten = v,
              ),
              _haken(
                'Mit Grafik',
                f.nurMitGrafik,
                widget.alle.where((a) => a.hatMedien).length,
                (v) => f.nurMitGrafik = v,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _haken(String titel, bool wert, int zahl, void Function(bool) setze) => InkWell(
    onTap: () {
      setze(!wert);
      widget.onChanged();
    },
    child: Row(
      children: [
        Checkbox(
          value: wert,
          onChanged: (v) {
            setze(v ?? false);
            widget.onChanged();
          },
        ),
        Expanded(child: Text(titel)),
        Text('$zahl', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _gruppe(Facette fac, StoreFilter f, Map<String, int> varianten) {
    final zahlen = f.zaehle(fac, widget.alle, varianten: varianten);
    final gewaehlt = f.auswahl[fac.schluessel] ?? const <String>{};
    if (zahlen.isEmpty && gewaehlt.isEmpty) return const SizedBox.shrink();
    final werte = {...zahlen.keys, ...gewaehlt}.toList();
    if (fac.namen.isNotEmpty) {
      final reihenfolge = fac.namen.keys.toList();
      werte.sort((a, b) {
        final ia = reihenfolge.indexOf(a), ib = reihenfolge.indexOf(b);
        return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
      });
    } else {
      werte.sort();
    }
    final suche = (_suche[fac.schluessel] ?? '').toLowerCase();
    var sichtbar = [
      for (final w in werte)
        if (suche.isEmpty || _name(fac, w).toLowerCase().contains(suche)) w,
    ];
    final gekuerzt = sichtbar.length > 8 && !_alleZeigen.contains(fac.schluessel);
    if (gekuerzt) {
      // Gewählte zuerst, dann die häufigsten.
      sichtbar.sort((a, b) {
        final g = (gewaehlt.contains(b) ? 1 : 0).compareTo(gewaehlt.contains(a) ? 1 : 0);
        return g != 0 ? g : (zahlen[b] ?? 0).compareTo(zahlen[a] ?? 0);
      });
      sichtbar = sichtbar.take(8).toList();
    }
    return _rahmen(
      fac.schluessel,
      fac.titel,
      aktiv: gewaehlt.isNotEmpty,
      kind: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fac.suche && werte.length > 8)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextField(
                key: ValueKey('filtersuche-${fac.schluessel}'),
                decoration: InputDecoration(
                  hintText: '${fac.titel} suchen',
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: (v) => setState(() => _suche[fac.schluessel] = v),
              ),
            ),
          for (final w in sichtbar)
            InkWell(
              key: ValueKey('filter-${fac.schluessel}-$w'),
              onTap: () {
                f.umschalten(fac.schluessel, w);
                widget.onChanged();
              },
              child: Row(
                children: [
                  Checkbox(
                    value: gewaehlt.contains(w),
                    onChanged: (_) {
                      f.umschalten(fac.schluessel, w);
                      widget.onChanged();
                    },
                  ),
                  Expanded(child: Text(_name(fac, w), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  Text('${zahlen[w] ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          if (gekuerzt || _alleZeigen.contains(fac.schluessel))
            TextButton(
              onPressed: () => setState(() {
                if (!_alleZeigen.remove(fac.schluessel)) _alleZeigen.add(fac.schluessel);
              }),
              child: Text(gekuerzt ? 'Alle ${werte.length} anzeigen' : 'Weniger anzeigen'),
            ),
        ],
      ),
    );
  }

  Widget _rahmen(String schluessel, String titel, {required bool aktiv, required Widget kind}) {
    final offen = _offen.contains(schluessel) || aktiv;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: linie)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (!_offen.remove(schluessel)) _offen.add(schluessel);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titel,
                      style: TextStyle(fontWeight: FontWeight.w700, color: aktiv ? tutoBlau : tinte),
                    ),
                  ),
                  Icon(offen ? Icons.expand_less : Icons.expand_more, size: 20, color: grauText),
                ],
              ),
            ),
          ),
          if (offen) Padding(padding: const EdgeInsets.only(bottom: 8), child: kind),
        ],
      ),
    );
  }
}

/// Die aktiven Filter als Chips zum Entfernen, wie über Suchergebnissen üblich.
class AktiveFilter extends StatelessWidget {
  const AktiveFilter({super.key, required this.zustand, required this.filter, required this.onChanged});

  final LehreZustand zustand;
  final StoreFilter filter;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filter;
    Widget chip(String text, VoidCallback weg) => InputChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onDeleted: () {
        weg();
        onChanged();
      },
      deleteIconColor: grauText,
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (f.text.trim().isNotEmpty) chip('„${f.text.trim()}“', () => f.text = ''),
        for (final e in f.auswahl.entries)
          for (final w in e.value)
            chip(e.key == 'level' ? zustand.levelName(w) : facette(e.key).name(w), () => f.umschalten(e.key, w)),
        if (f.schwierigkeitVon > 1 || f.schwierigkeitBis < 5)
          chip(
            'Schwierigkeit ${f.schwierigkeitVon}-${f.schwierigkeitBis}',
            () => f
              ..schwierigkeitVon = 1
              ..schwierigkeitBis = 5,
          ),
        if (f.maxMinuten != null) chip('bis ${f.maxMinuten} min', () => f.maxMinuten = null),
        if (f.nurMitVarianten) chip('mit Varianten', () => f.nurMitVarianten = false),
        if (f.nurMitGrafik) chip('mit Grafik', () => f.nurMitGrafik = false),
        if (!f.istLeer)
          TextButton(
            key: const ValueKey('filter-zuruecksetzen'),
            onPressed: () {
              f.zuruecksetzen();
              onChanged();
            },
            child: const Text('Alle zurücksetzen'),
          ),
      ],
    );
  }
}
