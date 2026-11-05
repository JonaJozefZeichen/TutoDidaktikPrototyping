import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/seiten/aufgaben.dart';
import 'package:tuto_didaktik/thema.dart';

/// Arbeitsliste: was als Nächstes zu tun ist.
class UebersichtSeite extends StatelessWidget {
  const UebersichtSeite({super.key, required this.zeilen, required this.person, required this.onOeffnen});

  final List<Map<String, dynamic>> zeilen;
  final Person person;
  final void Function(String id, List<String> reihenfolge) onOeffnen;

  bool _offen(Map<String, dynamic> z) =>
      z['status'] != 'zurueckgezogen' && (z['status'] != 'live' || z['korrektur'] == true);

  @override
  Widget build(BuildContext context) {
    final zweites = [
      for (final z in zeilen)
        if (_offen(z) && z['approvals'] == 1 && !(z['approval_von'] as List).contains(person.id)) z,
    ];
    final zuPruefen = [
      for (final z in zeilen)
        if (_offen(z) && z['approvals'] == 0 && z['fehler'] == 0) z,
    ];
    final mitFehlern = [
      for (final z in zeilen)
        if (_offen(z) && z['fehler'] != 0) z,
    ];
    final meine = [
      for (final z in zeilen)
        if ((z['bearbeitet_von'] as List).contains(person.id)) z,
    ];
    int zahl(String s) => zeilen.where((z) => z['status'] == s).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Übersicht', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in statusNamen.keys) _Kachel(titel: statusNamen[s]!, zahl: zahl(s))],
        ),
        const SizedBox(height: 20),
        _Abschnitt(
          titel: 'Wartet auf dein Approval',
          hilfe: 'Eine andere Person hat schon freigegeben.',
          zeilen: zweites,
          onOeffnen: onOeffnen,
        ),
        _Abschnitt(
          titel: 'Zu prüfen',
          hilfe: 'Keine Fehler, noch kein Approval.',
          zeilen: zuPruefen,
          onOeffnen: onOeffnen,
        ),
        _Abschnitt(
          titel: 'Mit Fehlern',
          hilfe: 'Vor einem Approval zu beheben.',
          zeilen: mitFehlern,
          onOeffnen: onOeffnen,
        ),
        _Abschnitt(
          titel: 'Von dir bearbeitet',
          hilfe: 'Aufgaben, an denen du eine Fassung gespeichert hast.',
          zeilen: meine,
          onOeffnen: onOeffnen,
        ),
      ],
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({required this.titel, required this.zahl});
  final String titel;
  final int zahl;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: linie),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$zahl',
          style: const TextStyle(fontFamily: monoSchrift, fontSize: 22, fontWeight: FontWeight.w600, color: tinte),
        ),
        Text(titel, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _Abschnitt extends StatefulWidget {
  const _Abschnitt({required this.titel, required this.hilfe, required this.zeilen, required this.onOeffnen});

  final String titel;
  final String hilfe;
  final List<Map<String, dynamic>> zeilen;
  final void Function(String id, List<String> reihenfolge) onOeffnen;

  @override
  State<_Abschnitt> createState() => _AbschnittState();
}

class _AbschnittState extends State<_Abschnitt> {
  static const _kurz = 5;
  bool _alle = false;

  @override
  Widget build(BuildContext context) {
    final z = widget.zeilen;
    final sichtbar = _alle ? z : z.take(_kurz).toList();
    final reihenfolge = [for (final x in z) x['id'] as String];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.titel} (${z.length})', style: Theme.of(context).textTheme.titleMedium),
          Text(widget.hilfe, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (z.isEmpty)
            Text('Nichts offen.', style: Theme.of(context).textTheme.bodySmall)
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: linie),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < sichtbar.length; i++) ...[
                    if (i > 0) const Divider(),
                    AufgabenZeile(
                      zeile: sichtbar[i],
                      onTap: () => widget.onOeffnen(sichtbar[i]['id'] as String, reihenfolge),
                    ),
                  ],
                  if (z.length > _kurz) ...[
                    const Divider(),
                    TextButton(
                      onPressed: () => setState(() => _alle = !_alle),
                      child: Text(_alle ? 'Weniger zeigen' : 'Alle ${z.length} zeigen'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
