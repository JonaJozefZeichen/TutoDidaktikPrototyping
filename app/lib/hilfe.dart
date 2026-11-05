import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:tuto_didaktik/thema.dart';

/// Steuert die Hilfe-Seitenleiste; von überall erreichbar.
class HilfeSteuerung extends ChangeNotifier {
  bool offen = false;
  String suche = '';

  /// Dieser Abschnitt steht bei der Suche ganz oben.
  String? zuerst;

  void oeffne([String begriff = '', String? abschnitt]) {
    offen = true;
    suche = begriff;
    zuerst = abschnitt;
    notifyListeners();
  }

  void umschalten() {
    offen = !offen;
    notifyListeners();
  }

  void schliessen() {
    offen = false;
    notifyListeners();
  }
}

class HilfeScope extends InheritedNotifier<HilfeSteuerung> {
  const HilfeScope({super.key, required HilfeSteuerung steuerung, required super.child}) : super(notifier: steuerung);

  static HilfeSteuerung of(BuildContext context) => context.getInheritedWidgetOfExactType<HilfeScope>()!.notifier!;
}

class _Abschnitt {
  _Abschnitt(this.titel, this.text);
  final String titel;
  final String text;
}

/// Teilt den Bauplan an den Überschriften (## und ###), damit die Suche ganze
/// Abschnitte zeigt.
List<_Abschnitt> _teile(String md) {
  final teile = <_Abschnitt>[];
  var titel = 'Einleitung';
  final puffer = StringBuffer();
  var inCode = false;
  void fertig() {
    final t = puffer.toString().trim();
    if (t.isNotEmpty) teile.add(_Abschnitt(titel, t));
    puffer.clear();
  }

  for (final zeile in md.split('\n')) {
    if (zeile.startsWith('```')) inCode = !inCode;
    if (!inCode && (zeile.startsWith('## ') || zeile.startsWith('### '))) {
      fertig();
      titel = zeile.replaceFirst(RegExp(r'^#+ '), '');
    } else if (!zeile.startsWith('# ') || inCode) {
      puffer.writeln(zeile);
    }
  }
  fertig();
  return teile;
}

/// Bauplan für Aufgaben als durchsuchbare Seitenleiste.
class HilfeLeiste extends StatefulWidget {
  const HilfeLeiste({super.key, required this.steuerung});
  final HilfeSteuerung steuerung;

  @override
  State<HilfeLeiste> createState() => _HilfeLeisteState();
}

class _HilfeLeisteState extends State<HilfeLeiste> {
  final _suche = TextEditingController();
  List<_Abschnitt>? _abschnitte;

  @override
  void initState() {
    super.initState();
    _suche.text = widget.steuerung.suche;
    widget.steuerung.addListener(_vonAussen);
    rootBundle.loadString('assets/hilfe/bauplan.md').then((md) {
      if (mounted) setState(() => _abschnitte = _teile(md));
    });
  }

  void _vonAussen() {
    if (_suche.text != widget.steuerung.suche) {
      setState(() => _suche.text = widget.steuerung.suche);
    }
  }

  @override
  void dispose() {
    widget.steuerung.removeListener(_vonAussen);
    _suche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final begriff = _suche.text.trim().toLowerCase();
    final alle = _abschnitte ?? const <_Abschnitt>[];
    final treffer = begriff.isEmpty
        ? alle
        : (alle.where((a) => a.titel.toLowerCase().contains(begriff) || a.text.toLowerCase().contains(begriff)).toList()
            ..sort(
              (x, y) => (y.titel == widget.steuerung.zuerst ? 1 : 0) - (x.titel == widget.steuerung.zuerst ? 1 : 0),
            ));
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: linie)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text('Hilfe: Bauplan für Aufgaben', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Hilfe schließen',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.steuerung.schliessen,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _suche,
              decoration: InputDecoration(
                hintText: 'Im Bauplan suchen',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _suche.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Suche leeren',
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(_suche.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(),
          Expanded(
            child: treffer.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _abschnitte == null ? 'Lädt …' : 'Nichts gefunden für "${_suche.text}".',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: treffer.length,
                    separatorBuilder: (_, _) =>
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                    itemBuilder: (context, i) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(treffer[i].titel, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        MarkdownBody(
                          data: treffer[i].text,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 13, height: 1.45, color: tinte),
                            listBullet: const TextStyle(fontSize: 13, color: tinte),
                            tableBody: const TextStyle(fontSize: 12, color: tinte),
                            tableHead: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tinte),
                            code: const TextStyle(fontFamily: monoSchrift, fontSize: 12, color: tinte),
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
