import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/lehre/klassen_seite.dart';
import 'package:tuto_didaktik/lehre/merkliste_seite.dart';
import 'package:tuto_didaktik/lehre/paket_editor.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

/// Rahmen des Bereichs für Lehrende: Klassen, Aufgaben-Store, Merkliste,
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

  late final _aktionen = LehreAktionen(oeffneAufgabe: _oeffneAufgabe, oeffnePaket: _oeffnePaket);

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
        onKlasse: (k) => _push(
          KlasseSeite(
            zustand: _z,
            aktionen: _aktionen,
            klasse: k,
            onSchuelerin: (s) => _push(SchuelerinSeite(zustand: _z, klasse: k, person: s, oeffne: _push)),
          ),
        ),
      ),
      1 => StoreSeite(zustand: _z, aktionen: _aktionen, filter: _filter),
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
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: linie)),
            ),
            child: Row(
              children: [
                Text('Tuto für Lehrende', style: text.titleMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        widget.demo == null ? 'Testmodus' : 'Demo: Änderungen bleiben nur in diesem Browser',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hinweisGelb),
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
                    message: 'Nur im Teststand: Entwürfe im Store zeigen, solange wenig freigegeben ist',
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
                Text('${widget.person.name} (${widget.person.rollenText})', style: text.bodySmall),
                const SizedBox(width: 4),
                TextButton(onPressed: widget.onAbmelden, child: const Text('Wechseln')),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _seite,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  onDestinationSelected: _wechsle,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.groups_outlined), label: Text('Klassen')),
                    NavigationRailDestination(icon: Icon(Icons.storefront_outlined), label: Text('Aufgaben')),
                    NavigationRailDestination(icon: Icon(Icons.favorite_border), label: Text('Merkliste')),
                    NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Pakete')),
                  ],
                ),
                const VerticalDivider(width: 1, color: linie),
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
