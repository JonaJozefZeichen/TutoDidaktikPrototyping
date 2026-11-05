import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/editor/editor_seite.dart';
import 'package:tuto_didaktik/hilfe.dart';
import 'package:tuto_didaktik/seiten/aufgaben.dart';
import 'package:tuto_didaktik/seiten/import_seite.dart';
import 'package:tuto_didaktik/seiten/uebersicht.dart';
import 'package:tuto_didaktik/thema.dart';

/// Rahmen: Navigation links, Inhalt in der Mitte, Hilfe von überall rechts.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.api, required this.person, required this.onAbmelden, this.demo});

  final Api api;
  final Person person;
  final VoidCallback onAbmelden;
  final DemoClient? demo;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _hilfe = HilfeSteuerung();
  final _navigator = GlobalKey<NavigatorState>();
  int _seite = 0;
  String? _startStatus;
  List<Map<String, dynamic>>? _zeilen;
  Stammdaten? _stamm;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _hilfe.addListener(() => setState(() {}));
    _lade();
  }

  @override
  void dispose() {
    _hilfe.dispose();
    super.dispose();
  }

  Future<void> _lade() async {
    try {
      final stamm = await widget.api.stammdaten();
      final zeilen = await widget.api.aufgaben();
      if (!mounted) return;
      setState(() {
        _stamm = stamm;
        _zeilen = zeilen;
        _fehler = null;
      });
    } on ApiFehler catch (e) {
      if (mounted) setState(() => _fehler = e.text);
    }
  }

  Future<void> _wechsle(int i, {String? status}) async {
    final nav = _navigator.currentState;
    if (nav != null && nav.canPop()) {
      await nav.maybePop();
      if (nav.canPop()) return; // ungespeicherte Änderungen: Editor fragt selbst nach
    }
    setState(() {
      _seite = i;
      _startStatus = status;
    });
  }

  Future<void> _zuruecksetzen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Demo zurücksetzen?'),
        content: const Text('Alle Änderungen in diesem Browser gehen verloren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.demo!.zuruecksetzen();
    final nav = _navigator.currentState;
    nav?.popUntil((r) => r.isFirst);
    await _lade();
  }

  void _oeffne(String id, List<String> reihenfolge) {
    _navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => EditorSeite(
          api: widget.api,
          person: widget.person,
          stamm: _stamm!,
          id: id,
          reihenfolge: reihenfolge,
          onGeaendert: _lade,
        ),
      ),
    );
  }

  Widget _inhalt() {
    final z = _zeilen;
    if (z == null || _stamm == null) {
      return Center(
        child: _fehler == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fehler!, style: const TextStyle(color: fehlerRot)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _lade, child: const Text('Erneut versuchen')),
                ],
              ),
      );
    }
    return switch (_seite) {
      0 => UebersichtSeite(zeilen: z, person: widget.person, onOeffnen: _oeffne),
      1 => AufgabenSeite(zeilen: z, onOeffnen: _oeffne, startStatus: _startStatus),
      _ => ImportSeite(
        api: widget.api,
        onFertig: _lade,
        onZuDenEntwuerfen: () => _wechsle(1, status: 'entwurf'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return HilfeScope(
      steuerung: _hilfe,
      child: Scaffold(
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
                  Text('Tuto Didaktik-Tool', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 10),
                  // Schmale Fenster kürzen den Hinweis, statt überzulaufen.
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
                  const SizedBox(width: 12),
                  if (widget.demo != null)
                    TextButton(
                      key: const ValueKey('demo-zuruecksetzen'),
                      onPressed: _zuruecksetzen,
                      child: const Text('Zurücksetzen'),
                    ),
                  Tooltip(
                    message: 'Aufgaben: Bauplan und Datenmodell (PDF)',
                    child: TextButton.icon(
                      key: const ValueKey('leitfaden-knopf'),
                      onPressed: oeffneLeitfaden,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Leitfaden'),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('hilfe-knopf'),
                    onPressed: _hilfe.umschalten,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Hilfe'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.person.name} (${widget.person.rollenText})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Übersicht')),
                      NavigationRailDestination(icon: Icon(Icons.list_alt), label: Text('Aufgaben')),
                      NavigationRailDestination(icon: Icon(Icons.upload_file), label: Text('Import')),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: linie),
                  Expanded(
                    child: Navigator(
                      key: _navigator,
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => Builder(
                          builder: (_) => _ShellInhalt(builder: _inhalt, listenable: _aktualisierung),
                        ),
                      ),
                    ),
                  ),
                  if (_hilfe.offen) HilfeLeiste(steuerung: _hilfe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Der Navigator baut seine erste Seite nur einmal; so bekommt sie neue Daten.
  final _aktualisierung = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _aktualisierung.value++;
  }
}

class _ShellInhalt extends StatelessWidget {
  const _ShellInhalt({required this.builder, required this.listenable});

  final Widget Function() builder;
  final Listenable listenable;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (_, _) => Material(color: flaeche, child: builder()),
  );
}
