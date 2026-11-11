import 'package:didaktik_kern/didaktik_kern.dart' show formatNamen;
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/thema.dart';

/// Filterbare Aufgabenliste. Filter: Status, Lernwelt, Themenbereich, Level,
/// Kompetenz, Format, Herkunft.
class AufgabenSeite extends StatefulWidget {
  const AufgabenSeite({super.key, required this.zeilen, required this.onOeffnen, this.startStatus});

  final List<Map<String, dynamic>> zeilen;
  final void Function(String id, List<String> reihenfolge) onOeffnen;
  final String? startStatus;

  @override
  State<AufgabenSeite> createState() => _AufgabenSeiteState();
}

class _AufgabenSeiteState extends State<AufgabenSeite> {
  String _suche = '';
  late String? _status = widget.startStatus;
  int? _lernwelt;
  String? _themenbereich;
  String? _level;
  String? _kompetenz;
  String? _format;
  String? _herkunft;
  Spalte? _sortiert;
  bool _absteigend = false;

  void _sortiereNach(Spalte s) => setState(() {
    if (_sortiert == s) {
      // Dritter Klick hebt die Sortierung wieder auf.
      if (_absteigend) {
        _sortiert = null;
        _absteigend = false;
      } else {
        _absteigend = true;
      }
    } else {
      _sortiert = s;
      _absteigend = false;
    }
  });

  @override
  void didUpdateWidget(covariant AufgabenSeite old) {
    super.didUpdateWidget(old);
    if (old.startStatus != widget.startStatus) _status = widget.startStatus;
  }

  List<Map<String, dynamic>> get _treffer {
    final q = _suche.trim().toLowerCase();
    final liste = widget.zeilen.where((z) {
      if (_status != null && z['status'] != _status) return false;
      if (_lernwelt != null && z['lernwelt'] != _lernwelt) return false;
      if (_themenbereich != null && !(z['themenbereiche'] as List).contains(_themenbereich)) return false;
      if (_level != null && !(z['level'] as List).contains(_level)) return false;
      if (_kompetenz != null && !(z['kompetenzen'] as List).contains(_kompetenz)) return false;
      if (_format != null && !(z['formate'] as List).contains(_format)) return false;
      if (_herkunft != null && z['herkunft'] != _herkunft) return false;
      if (q.isEmpty) return true;
      return '${z['id']} ${z['titel']} ${z['aufgabenstellung']}'.toLowerCase().contains(q);
    }).toList();
    final s = _sortiert;
    if (s == null) return liste;
    // Stabil sortieren, damit gleiche Werte ihre Lernplan-Reihenfolge behalten.
    final indiziert = [for (var i = 0; i < liste.length; i++) (i, liste[i])];
    indiziert.sort((a, b) {
      final c = s.vergleiche(a.$2, b.$2);
      return c != 0 ? (_absteigend ? -c : c) : a.$1.compareTo(b.$1);
    });
    return [for (final (_, z) in indiziert) z];
  }

  List<String> _werte(String key) {
    final s = <String>{};
    for (final z in widget.zeilen) {
      final v = z[key];
      if (v is List) {
        s.addAll(v.cast<String>());
      } else if (v != null) {
        s.add('$v');
      }
    }
    return s.toList()..sort();
  }

  Widget _filter(
    String label,
    String? wert,
    List<String> werte,
    ValueChanged<String?> setze, {
    String Function(String)? name,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$wert'),
        isExpanded: true,
        initialValue: werte.contains(wert) ? wert : null,
        decoration: InputDecoration(labelText: label),
        style: const TextStyle(fontFamily: schrift, fontSize: 13, color: tinte),
        items: [
          const DropdownMenuItem(value: null, child: Text('Alle')),
          for (final w in werte)
            DropdownMenuItem(
              value: w,
              child: Text(name?.call(w) ?? w, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => setze(v)),
      ),
    );
  }

  bool get _hatFilter =>
      _status != null ||
      _lernwelt != null ||
      _themenbereich != null ||
      _level != null ||
      _kompetenz != null ||
      _format != null ||
      _herkunft != null ||
      _suche.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final treffer = _treffer;
    final reihenfolge = [for (final z in treffer) z['id'] as String];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aufgaben', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          // Status als Zähler-Chips: ein Klick filtert, die Zahlen zeigen den Bestand.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ZaehlerChip(
                key: const ValueKey('status-alle'),
                label: 'Alle',
                zahl: widget.zeilen.length,
                aktiv: _status == null,
                onTap: () => setState(() => _status = null),
              ),
              for (final st in statusNamen.keys)
                ZaehlerChip(
                  key: ValueKey('status-$st'),
                  label: statusNamen[st]!,
                  zahl: widget.zeilen.where((z) => z['status'] == st).length,
                  aktiv: _status == st,
                  onTap: () => setState(() => _status = _status == st ? null : st),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  key: const ValueKey('aufgaben-suche'),
                  decoration: const InputDecoration(
                    hintText: 'Suche in ID, Titel, Text',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (v) => setState(() => _suche = v),
                ),
              ),
              _filter(
                'Lernwelt',
                _lernwelt?.toString(),
                _werte('lernwelt'),
                (v) => _lernwelt = v == null ? null : int.parse(v),
                name: (s) => '$s. Klasse',
              ),
              _filter('Themenbereich', _themenbereich, _werte('themenbereiche'), (v) => _themenbereich = v),
              _filter('Level', _level, _werte('level'), (v) => _level = v),
              _filter('Kompetenz', _kompetenz, _werte('kompetenzen'), (v) => _kompetenz = v),
              _filter(
                'Antwortformat',
                _format,
                _werte('formate'),
                (v) => _format = v,
                name: (f) => formatNamen[f] ?? f,
              ),
              _filter('Herkunft', _herkunft, _werte('herkunft'), (v) => _herkunft = v),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${treffer.length} von ${widget.zeilen.length} Aufgaben${_hatFilter ? ' (gefiltert)' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            // Tabelle flach auf weiß, nur Haarlinien zwischen den Zeilen.
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: linie)),
              ),
              child: Column(
                children: [
                  AufgabenKopfzeile(sortiert: _sortiert, absteigend: _absteigend, onSortiere: _sortiereNach),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: treffer.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, i) => AufgabenZeile(
                        zeile: treffer[i],
                        onTap: () => widget.onOeffnen(treffer[i]['id'] as String, reihenfolge),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spalten der Aufgabenliste. Kopfzeile und Zeilen nutzen dieselben Breiten.
enum Spalte {
  status('Status', breite: 150),
  titel('Titel', flex: 3),
  level('Level', flex: 2),
  typ('Typ', flex: 2),
  approvals('Approvals', breite: 90),
  fehler('Fehler', breite: 80);

  const Spalte(this.ueberschrift, {this.breite, this.flex = 1});

  final String ueberschrift;
  final double? breite;
  final int flex;

  static const _statusReihe = ['entwurf', 'geprueft', 'live', 'zurueckgezogen'];

  int vergleiche(Map<String, dynamic> a, Map<String, dynamic> b) => switch (this) {
    Spalte.status => _statusReihe.indexOf(a['status'] as String).compareTo(_statusReihe.indexOf(b['status'] as String)),
    Spalte.titel => '${a['titel'] ?? ''}'.toLowerCase().compareTo('${b['titel'] ?? ''}'.toLowerCase()),
    Spalte.level => _erstes(a['level']).compareTo(_erstes(b['level'])),
    Spalte.typ => _typText(a).compareTo(_typText(b)),
    Spalte.approvals => (a['approvals'] as int).compareTo(b['approvals'] as int),
    Spalte.fehler => (a['fehler'] as int).compareTo(b['fehler'] as int),
  };

  static String _erstes(Object? liste) => liste is List && liste.isNotEmpty ? '${liste.first}' : '';

  /// Lesbare Typen wie im Katalog ("1 aus 6" statt "mc_1aus6").
  static String _typText(Map<String, dynamic> z) =>
      [for (final f in z['formate'] as List) formatNamen[f] ?? '$f'].join(', ');

  Widget zelle(Widget kind) =>
      breite != null ? SizedBox(width: breite, child: kind) : Expanded(flex: flex, child: kind);
}

/// Spaltenüberschriften; Klick sortiert auf-, dann absteigend, dann wieder nach Lernplan.
class AufgabenKopfzeile extends StatelessWidget {
  const AufgabenKopfzeile({super.key, this.sortiert, this.absteigend = false, this.onSortiere});

  final Spalte? sortiert;
  final bool absteigend;

  /// `null` = nur Überschriften, nicht sortierbar (z. B. in der Übersicht).
  final ValueChanged<Spalte>? onSortiere;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final s in Spalte.values)
            s.zelle(
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  key: ValueKey('sortiere-${s.name}'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: onSortiere == null ? null : () => onSortiere!(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            s.ueberschrift,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sortiert == s ? stil?.copyWith(color: tinte) : stil,
                          ),
                        ),
                        if (onSortiere != null) ...[
                          const SizedBox(width: 2),
                          Icon(
                            sortiert != s
                                ? Icons.unfold_more
                                : absteigend
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 13,
                            color: sortiert == s ? tinte : const Color(0xFFB0B8C4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AufgabenZeile extends StatelessWidget {
  const AufgabenZeile({super.key, required this.zeile, required this.onTap});

  final Map<String, dynamic> zeile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fehler = zeile['fehler'] as int;
    final approvals = zeile['approvals'] as int;
    final klein = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Spalte.status.zelle(
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPlakette(
                  zeile['status'] as String,
                  korrektur: zeile['korrektur'] as bool,
                  approvals: approvals,
                ),
              ),
            ),
            Spalte.titel.zelle(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${zeile['titel'] ?? '(ohne Titel)'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${zeile['id']}',
                    style: const TextStyle(fontFamily: schrift, fontFeatures: ziffern, fontSize: 11.5, color: tutoBlau),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Spalte.level.zelle(
              Text((zeile['level'] as List).join(', '), style: klein, overflow: TextOverflow.ellipsis),
            ),
            Spalte.typ.zelle(
              Tooltip(
                message: (zeile['formate'] as List).join(', '),
                child: Text(Spalte._typText(zeile), style: klein, overflow: TextOverflow.ellipsis),
              ),
            ),
            Spalte.approvals.zelle(Text('$approvals/2', style: klein)),
            Spalte.fehler.zelle(
              fehler > 0
                  ? Text(
                      '$fehler Fehler',
                      style: const TextStyle(fontSize: 12, color: fehlerRot, fontWeight: FontWeight.w600),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
