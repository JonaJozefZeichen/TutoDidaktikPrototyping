import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/lehre/lehre_shell.dart';
import 'package:tuto_didaktik/seiten/anmelden.dart';
import 'package:tuto_didaktik/shell.dart';
import 'package:tuto_didaktik/thema.dart';

/// Gebaut mit `--dart-define=DEMO=true`: läuft ohne Server, siehe `DemoClient`.
const istDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  if (!istDemo) {
    runApp(DidaktikApp(api: Api.ausAdresse(Uri.base)));
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  final demo = await DemoClient.lade();
  runApp(DidaktikApp(api: Api(basis: 'http://demo.local/api', client: demo), demo: demo));
}

class DidaktikApp extends StatefulWidget {
  const DidaktikApp({super.key, required this.api, this.demo});
  final Api api;
  final DemoClient? demo;

  @override
  State<DidaktikApp> createState() => _DidaktikAppState();
}

class _DidaktikAppState extends State<DidaktikApp> {
  Person? _person;

  void _setze(Person? p) => setState(() {
    _person = p;
    widget.api.person = p;
  });

  @override
  Widget build(BuildContext context) {
    final p = _person;
    return MaterialApp(
      title: 'Tuto Didaktik-Tool und Bereich für Lehrende',
      debugShowCheckedModeBanner: false,
      theme: baueThema(),
      home: p == null
          ? AnmeldenSeite(api: widget.api, demo: widget.demo != null, onAngemeldet: _setze)
          : p.istLehrbereich
          ? LehreShell(key: ValueKey(p.id), api: widget.api, person: p, demo: widget.demo, onAbmelden: () => _setze(null))
          : Shell(key: ValueKey(p.id), api: widget.api, person: p, demo: widget.demo, onAbmelden: () => _setze(null)),
    );
  }
}
