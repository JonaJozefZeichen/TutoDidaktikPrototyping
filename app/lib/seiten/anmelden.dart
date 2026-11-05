import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/thema.dart';

/// Startseite im Testmodus: Testperson wählen statt echtem Login.
class AnmeldenSeite extends StatefulWidget {
  const AnmeldenSeite({super.key, required this.api, required this.onAngemeldet, this.demo = false});

  final Api api;
  final bool demo;
  final void Function(Person) onAngemeldet;

  @override
  State<AnmeldenSeite> createState() => _AnmeldenSeiteState();
}

class _AnmeldenSeiteState extends State<AnmeldenSeite> {
  late Future<List<Person>> _personen = widget.api.personen();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: linie),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FutureBuilder<List<Person>>(
            future: _personen,
            builder: (context, s) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tuto Didaktik-Tool', style: text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.demo
                      ? 'Demo mit Beispielaufgaben: kein echter Login, Änderungen bleiben nur in diesem Browser. Um zwei Approvals zu testen, oben rechts die Testperson wechseln.'
                      : 'Testmodus: kein echter Login. Um zwei Approvals zu testen, zwei Fenster mit verschiedenen Testpersonen öffnen.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                if (s.hasError) ...[
                  Text('${s.error}', style: const TextStyle(color: fehlerRot)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => _personen = widget.api.personen()),
                    child: const Text('Erneut versuchen'),
                  ),
                ] else if (!s.hasData)
                  const Center(child: CircularProgressIndicator())
                else
                  for (final p in s.data!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => widget.onAngemeldet(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('${p.name} (${p.rollenText})'),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
