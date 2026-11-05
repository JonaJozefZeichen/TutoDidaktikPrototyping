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

  @override
  void didUpdateWidget(covariant AufgabenSeite old) {
    super.didUpdateWidget(old);
    if (old.startStatus != widget.startStatus) _status = widget.startStatus;
  }

  List<Map<String, dynamic>> get _treffer {
    final q = _suche.trim().toLowerCase();
    return widget.zeilen.where((z) {
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
        style: const TextStyle(fontSize: 13, color: tinte),
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
              _filter('Status', _status, _werte('status'), (v) => _status = v, name: (s) => statusNamen[s] ?? s),
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
              _filter('Antwortformat', _format, _werte('formate'), (v) => _format = v),
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: linie),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.separated(
                itemCount: treffer.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) => AufgabenZeile(
                  zeile: treffer[i],
                  onTap: () => widget.onOeffnen(treffer[i]['id'] as String, reihenfolge),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPlakette(
                  zeile['status'] as String,
                  korrektur: zeile['korrektur'] as bool,
                  approvals: approvals,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${zeile['titel'] ?? '(ohne Titel)'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${zeile['id']}',
                    style: const TextStyle(fontFamily: monoSchrift, fontSize: 11, color: grauText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (zeile['level'] as List).join(', '),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (zeile['formate'] as List).join(', '),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 90, child: Text('Approvals $approvals/2', style: Theme.of(context).textTheme.bodySmall)),
            SizedBox(
              width: 80,
              child: fehler > 0
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
