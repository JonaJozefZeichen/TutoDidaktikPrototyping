import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/thema.dart';
import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/antwort_eingabe.dart';
import 'package:tuto_didaktik/vorschau/widgets/medien.dart';

/// Aufgabe so, wie sie auf dem Handy aussieht: gleicher Loader, gleiche
/// Antwort-Widgets, gleiche Prüfung wie in der App.
class HandyVorschau extends StatefulWidget {
  const HandyVorschau({super.key, required this.inhalt});

  final Map<String, dynamic> inhalt;

  @override
  State<HandyVorschau> createState() => _HandyVorschauState();
}

class _HandyVorschauState extends State<HandyVorschau> {
  int _item = 0;
  int _hilfen = 0;
  bool _loesung = false;
  Object? _antwort;
  String _antwortText = '';
  CheckResult? _ergebnis;
  String _letzterStand = '';
  ({Aufgabe? aufgabe, List<String> fehler})? _geladen;

  ({Aufgabe? aufgabe, List<String> fehler}) _lade() {
    final stand = jsonEncode(widget.inhalt);
    if (stand != _letzterStand || _geladen == null) {
      _letzterStand = stand;
      _geladen = ladeZurVorschau(widget.inhalt);
      _ergebnis = null;
    }
    return _geladen!;
  }

  void _waehleItem(int i) => setState(() {
    _item = i;
    _hilfen = 0;
    _loesung = false;
    _antwort = null;
    _ergebnis = null;
  });

  void _pruefe(Item item, Map<String, num> werte) {
    setState(() {
      _ergebnis = const AnswerChecker().check(item, _antwort, werte: werte);
    });
  }

  @override
  Widget build(BuildContext context) {
    final (:aufgabe, :fehler) = _lade();
    final items = aufgabe?.items ?? const <Item>[];
    final index = _item.clamp(0, items.isEmpty ? 0 : items.length - 1);
    final item = items.isEmpty ? null : items[index];
    final werte = <String, num>{for (final p in aufgabe?.parameter ?? const <Parameter>[]) p.name: p.min};
    return Column(
      children: [
        Container(
          width: 390,
          height: 720,
          decoration: BoxDecoration(
            color: tinte,
            borderRadius: BorderRadius.circular(38),
            boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x22000000), offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(9),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: item == null ? _nichtLadbar(fehler) : _bildschirm(context, aufgabe!, item, werte),
          ),
        ),
        const SizedBox(height: 10),
        if (items.length > 1)
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < items.length; i++)
                ChoiceChip(label: Text('Item ${i + 1}'), selected: i == index, onSelected: (_) => _waehleItem(i)),
            ],
          ),
        if (item != null) _testLeiste(item, werte),
      ],
    );
  }

  Widget _nichtLadbar(List<String> fehler) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.phone_android, color: grauText),
        const SizedBox(height: 8),
        const Text('In dieser Form kann die App die Aufgabe nicht zeigen.', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (final f in fehler.take(4))
          Text(
            f,
            style: const TextStyle(fontSize: 12, color: fehlerRot),
            textAlign: TextAlign.center,
          ),
      ],
    ),
  );

  Widget _bildschirm(BuildContext context, Aufgabe aufgabe, Item item, Map<String, num> werte) {
    final tokens = context.designSystem;
    String text(String t) => fuelleParameter(t, werte);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(372, 702), padding: EdgeInsets.zero),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
            children: [
              Text(aufgabe.titel, style: tokens.label()),
              const SizedBox(height: 12),
              if (aufgabe.stamm.isNotEmpty) ...[
                Text(text(aufgabe.stamm), style: tokens.body()),
                const SizedBox(height: 12),
              ],
              if (aufgabe.medien.isNotEmpty) ...[AufgabenMedien(medien: aufgabe.medien), const SizedBox(height: 12)],
              Text(text(item.aufgabenstellung), style: tokens.heading(size: 20)),
              const SizedBox(height: 12),
              AntwortEingabe(
                key: ValueKey(item.id),
                item: item,
                enabled: true,
                werte: werte,
                onChanged: (a, t) => setState(() {
                  _antwort = a;
                  _antwortText = t;
                  _ergebnis = null;
                }),
              ),
              const SizedBox(height: 12),
              for (final h in item.hilfen.take(_hilfen))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Hilfe ${h.stufe}: ${text(h.text)}', style: tokens.body(size: 14)),
                ),
              if (_loesung) ...[
                Text(
                  'Lösung: ${loesungAlsText(item, werte: werte)}',
                  style: tokens.body(size: 14, weight: FontWeight.w700),
                ),
                for (final s in item.loesungsweg) Text(text(s), style: tokens.body(size: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _testLeiste(Item item, Map<String, num> werte) {
    final e = _ergebnis;
    return SizedBox(
      width: 390,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              FilledButton(
                key: const ValueKey('antwort-testen'),
                onPressed: item.automatischGeprueft ? () => _pruefe(item, werte) : null,
                child: const Text('Antwort testen'),
              ),
              OutlinedButton(
                onPressed: _hilfen < item.hilfen.length
                    ? () => setState(() => _hilfen++)
                    : () => setState(() => _hilfen = 0),
                child: Text(_hilfen < item.hilfen.length ? 'Hilfe ${_hilfen + 1} zeigen' : 'Hilfen ausblenden'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _loesung = !_loesung),
                child: Text(_loesung ? 'Lösung ausblenden' : 'Lösung zeigen'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!item.automatischGeprueft)
            Text('Dieses Format bewerten die Lernenden selbst.', style: Theme.of(context).textTheme.bodySmall)
          else if (e != null)
            Text(
              e.richtig
                  ? 'Richtig: "$_antwortText" gilt als richtig.'
                  : e.r > 0
                  ? 'Teilweise richtig (${zahlText(e.r)} Punkte).'
                  : 'Falsch${e.fehlerbild == null ? '' : ', Fehlerbild: ${e.fehlerbild}'}.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: e.richtig ? const Color(0xFF1B6B32) : fehlerRot,
              ),
            ),
        ],
      ),
    );
  }
}
