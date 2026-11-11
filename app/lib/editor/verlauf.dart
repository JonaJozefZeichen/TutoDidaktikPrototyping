import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:tuto_didaktik/thema.dart';

const _artNamen = {
  'import': 'Importiert',
  'bearbeitung': 'Bearbeitet',
  'wiederherstellung': 'Frühere Fassung wiederhergestellt',
  'wiederaufnahme': 'Wieder aufgenommen',
  'approval': 'Approval gegeben',
  'approval_zurueck': 'Approval zurückgenommen',
  'live': 'Live geschaltet',
  'zurueckgezogen': 'Zurückgezogen',
};

String _datum(DateTime d) {
  String z(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${z(l.day)}.${z(l.month)}.${l.year} ${z(l.hour)}:${z(l.minute)}';
}

/// Verlauf und frühere Fassungen. Liefert die Nummer der Fassung, die
/// wiederhergestellt werden soll.
class VerlaufDialog extends StatefulWidget {
  const VerlaufDialog({super.key, required this.eintrag, required this.personName});

  final Eintrag eintrag;
  final String Function(String?) personName;

  @override
  State<VerlaufDialog> createState() => _VerlaufDialogState();
}

class _VerlaufDialogState extends State<VerlaufDialog> {
  late int _ansicht = widget.eintrag.aktuell.nr;

  @override
  Widget build(BuildContext context) {
    final e = widget.eintrag;
    final text = Theme.of(context).textTheme;
    final fassung = e.fassungen.firstWhere((f) => f.nr == _ansicht);
    return AlertDialog(
      title: const Text('Verlauf'),
      content: SizedBox(
        width: 880,
        height: 800,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text('Fassungen', style: text.titleMedium),
                  const SizedBox(height: 6),
                  for (final f in e.fassungen.reversed)
                    ListTile(
                      dense: true,
                      selected: f.nr == _ansicht,
                      title: Text(
                        'Fassung ${f.nr}${f.nr == e.liveFassung ? ' (live)' : ''}${f.nr == e.aktuell.nr ? ' (aktuell)' : ''}',
                      ),
                      subtitle: Text('${widget.personName(f.von)}, ${_datum(f.am)}, Approvals ${f.approvals.length}/2'),
                      onTap: () => setState(() => _ansicht = f.nr),
                      trailing: f.nr == e.aktuell.nr
                          ? null
                          : TextButton(
                              onPressed: () => Navigator.pop(context, f.nr),
                              child: const Text('Wiederherstellen'),
                            ),
                    ),
                  const SizedBox(height: 12),
                  Text('Ereignisse', style: text.titleMedium),
                  const SizedBox(height: 6),
                  for (final v in e.ereignisse.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${_datum(v.am)}  ${_artNamen[v.art] ?? v.art} (Fassung ${v.fassung}), ${widget.personName(v.person)}'
                        '${v.text == null || v.text!.isEmpty ? '' : ': ${v.text}'}',
                        style: const TextStyle(fontSize: 12.5, color: tinte),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 620,
              child: HandyVorschau(key: ValueKey('verlauf-$_ansicht'), inhalt: fassung.inhalt),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
    );
  }
}
