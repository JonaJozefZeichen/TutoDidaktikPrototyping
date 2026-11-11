import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/lehre/klassen_seite.dart';
import 'package:tuto_didaktik/lehre/merkliste_seite.dart';
import 'package:tuto_didaktik/lehre/schueler_ansicht.dart';
import 'package:tuto_didaktik/lehre/paket_editor.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/lehre/zuweisen_seite.dart';
import 'package:tuto_didaktik/thema.dart';

/// Rahmen des Bereichs für Lehrende: Klassen, Aufgabenkatalog, Merkliste,
/// Pakete. Läuft im selben Programm wie das Didaktik-Tool, mit eigenen Rechten.
class LehreShell extends StatefulWidget {
  const LehreShell({super.key, required this.api, required this.person, required this.onAbmelden, this.demo});

  final Api api;
  final Person person;
  final VoidCallback onAbmelden;
  final DemoClient? demo;

  @override
  State<LehreShell> createState() => _LehreShellState();
}

class _LehreShellState extends State<LehreShell> {
  late final LehreZustand _z = LehreZustand(api: widget.api, person: widget.person);
  final _navigator = GlobalKey<NavigatorState>();
  final _filter = StoreFilter();
  int _seite = 0;
  final _seitenWechsel = ValueNotifier<int>(0);

  late final _aktionen = LehreAktionen(
    oeffneAufgabe: _oeffneAufgabe,
    oeffnePaket: _oeffnePaket,
    oeffneZuweisen: _oeffneZuweisen,
    oeffne: _push,
  );

  void _oeffneSchuelerAnsicht() => _push(SchuelerAnsicht(zustand: _z));

  void _oeffneZuweisen({String? paketId, Map<String, Set<String>>? auswahl}) =>
      _push(ZuweisenSeite(zustand: _z, paketId: paketId, auswahl: auswahl));

  @override
  void initState() {
    super.initState();
    _z.laden();
  }

  @override
  void dispose() {
    _z.dispose();
    _seitenWechsel.dispose();
    super.dispose();
  }

  void _push(Widget seite) => _navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => Material(color: flaeche, child: seite),
    ),
  );

  void _oeffneAufgabe(String id) => _push(AufgabeDetailSeite(zustand: _z, aktionen: _aktionen, id: id));

  void _oeffnePaket(String id) {
    if (_z.paket(id) == null) return;
    _push(PaketEditor(key: ValueKey('editor-$id'), zustand: _z, aktionen: _aktionen, paketId: id));
  }

  void _wechsle(int i) {
    _navigator.currentState?.popUntil((r) => r.isFirst);
    setState(() => _seite = i);
    _seitenWechsel.value++;
  }

  void _zeigeSuche(StoreFilter f) {
    _filter
      ..zuruecksetzen()
      ..text = f.text
      ..schwierigkeitVon = f.schwierigkeitVon
      ..schwierigkeitBis = f.schwierigkeitBis
      ..maxMinuten = f.maxMinuten
      ..nurMitVarianten = f.nurMitVarianten
      ..nurMitGrafik = f.nurMitGrafik
      ..sortierung = f.sortierung;
    _filter.auswahl.addAll({
      for (final e in f.auswahl.entries) e.key: {...e.value},
    });
    _wechsle(1);
  }

  Future<void> _zuruecksetzen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Demo zurücksetzen?'),
        content: const Text('Alle Änderungen in diesem Browser gehen verloren, auch Merkliste und Pakete.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.demo!.zuruecksetzen();
    _navigator.currentState?.popUntil((r) => r.isFirst);
    _z.offenesPaket = null;
    await _z.laden();
  }

  Widget _inhalt() {
    if (_z.laedt && _z.stamm == null) return const Center(child: CircularProgressIndicator());
    if (_z.fehler != null && _z.stamm == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_z.fehler!, style: const TextStyle(color: fehlerRot)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _z.laden, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }
    return switch (_seite) {
      0 => KlassenSeite(
        zustand: _z,
        onSchuelerAnsicht: _oeffneSchuelerAnsicht,
        onKlasse: (k) => _push(
          KlasseSeite(
            zustand: _z,
            aktionen: _aktionen,
            klasse: k,
            onSchuelerin: (s) => _push(SchuelerinSeite(zustand: _z, klasse: k, person: s, oeffne: _push)),
          ),
        ),
      ),
      1 => KatalogSeite(zustand: _z, aktionen: _aktionen, filter: _filter),
      2 => MerklisteSeite(zustand: _z, aktionen: _aktionen, onSucheZeigen: _zeigeSuche),
      _ => PaketeSeite(zustand: _z, aktionen: _aktionen),
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          // Kopfzeile ohne Leiste, wie im Didaktik-Tool.
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Text('Tuto für Lehrende', style: text.titleMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const ShapeDecoration(color: Color(0xFFFFF1CC), shape: StadiumBorder()),
                      child: Text(
                        widget.demo == null ? 'Testmodus' : 'Demo: Änderungen bleiben nur in diesem Browser',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: hinweisGelb),
                      ),
                    ),
                  ),
                ),
                if (widget.demo != null)
                  TextButton(
                    key: const ValueKey('demo-zuruecksetzen'),
                    onPressed: _zuruecksetzen,
                    child: const Text('Zurücksetzen'),
                  ),
                ListenableBuilder(
                  listenable: _z,
                  builder: (_, _) => Tooltip(
                    message: 'Nur im Teststand: Entwürfe im Katalog zeigen, solange wenig freigegeben ist',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Entwürfe zeigen', style: text.bodySmall),
                        Switch(
                          key: const ValueKey('entwuerfe-zeigen'),
                          value: _z.auchUnfreigegebene,
                          onChanged: _z.setzeAuchUnfreigegebene,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PersonPill(name: widget.person.name, rolle: widget.person.rollenText, onWechseln: widget.onAbmelden),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Navigation flach links, gleich breit wie im Didaktik-Tool.
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      // Nur so hoch wie die Einträge.
                      child: SizedBox(
                        height: 8 + 4 * 68.0,
                        child: NavigationRail(
                          selectedIndex: _seite,
                          labelType: NavigationRailLabelType.all,
                          minWidth: 72,
                          groupAlignment: -1,
                          onDestinationSelected: _wechsle,
                          destinations: const [
                            NavigationRailDestination(icon: Icon(Icons.groups_outlined), label: Text('Klassen')),
                            NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), label: Text('Katalog')),
                            NavigationRailDestination(icon: Icon(Icons.favorite_border), label: Text('Merkliste')),
                            NavigationRailDestination(icon: Icon(Icons.post_add), label: Text('Pakete')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Navigator(
                    key: _navigator,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => ListenableBuilder(
                        listenable: Listenable.merge([_z, _seitenWechsel]),
                        builder: (_, _) => Material(color: flaeche, child: _inhalt()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
