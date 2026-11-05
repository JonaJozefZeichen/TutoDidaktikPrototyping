// Kopie aus dem Prototyp (TutoPrototyping, Commit c4d4e8d): lib/features/aufgaben/widgets/antwort_eingabe.dart

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:tuto_didaktik/vorschau/design_system.dart';
import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_chip.dart';
import 'package:tuto_didaktik/vorschau/widgets/design_system_selectable_card.dart';
import 'package:didaktik_kern/didaktik_kern.dart';

/// Antwort-Eingabe für ein Item, je nach `antwortformat`. Meldet jede
/// Änderung mit der Antwort im Format, das `AnswerChecker` erwartet, und
/// einer Textfassung fürs Log. Selbst bewertete Formate (offen_text,
/// konstruktion) zeigen nur einen Hinweis; bewertet wird nach dem Aufdecken
/// der Lösung. Terme (`offen_term`, `halboffen` mit `art: term`) bekommen
/// ein Textfeld, `halboffen` mit mehreren Platzhaltern (`{x}`, `{y}`) ein
/// Zahlenfeld pro Platzhalter. [werte] füllt die Platzhalter
/// parametrisierter Aufgaben.
class AntwortEingabe extends StatefulWidget {
  const AntwortEingabe({
    super.key,
    required this.item,
    required this.enabled,
    required this.onChanged,
    this.werte = const {},
  });

  final Item item;
  final bool enabled;
  final Map<String, num> werte;
  final void Function(Object? antwort, String text) onChanged;

  @override
  State<AntwortEingabe> createState() => _AntwortEingabeState();
}

class _AntwortEingabeState extends State<AntwortEingabe> {
  int? _einfach;
  final _mehrfach = <int>{};
  final _luecken = <int?>[null, null];
  final _zuordnung = <int, String>{};
  final _text = TextEditingController();
  final _felder = <String, TextEditingController>{};

  Map<String, dynamic> get a => widget.item.antwort;

  @override
  void didUpdateWidget(covariant AntwortEingabe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _leeren();
  }

  /// Zweiter Versuch: Eingabe zurücksetzen.
  void _leeren() {
    _einfach = null;
    _mehrfach.clear();
    _luecken.setAll(0, [null, null]);
    _zuordnung.clear();
    _text.clear();
    for (final c in _felder.values) {
      c.clear();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    for (final c in _felder.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _melde(Object? antwort, String text) {
    setState(() {});
    widget.onChanged(antwort, text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designSystem;
    final gap = SizedBox(height: tokens.spacingScale[0]);
    switch (widget.item.format) {
      case 'mc_1aus5' || 'mc_1aus6':
        final optionen = (a['optionen'] as List).cast<String>();
        return Column(
          children: [
            for (var i = 0; i < optionen.length; i++) ...[
              DesignSystemSelectableCard(
                label: optionen[i],
                selected: _einfach == i,
                onTap: widget.enabled
                    ? () {
                        _einfach = i;
                        _melde(i, optionen[i]);
                      }
                    : null,
              ),
              gap,
            ],
          ],
        );
      case 'mc_2aus5':
        final optionen = (a['optionen'] as List).cast<String>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kreuze genau zwei Aussagen an.', style: tokens.body(size: 14).copyWith(color: tokens.inkMuted)),
            gap,
            for (var i = 0; i < optionen.length; i++) ...[
              DesignSystemSelectableCard(
                label: optionen[i],
                icon: PhosphorIconsRegular.square,
                selected: _mehrfach.contains(i),
                onTap: widget.enabled
                    ? () {
                        if (!_mehrfach.remove(i)) {
                          if (_mehrfach.length >= 2) _mehrfach.remove(_mehrfach.first);
                          _mehrfach.add(i);
                        }
                        _melde({..._mehrfach}, _mehrfach.map((x) => optionen[x]).join(' | '));
                      }
                    : null,
              ),
              gap,
            ],
          ],
        );
      case 'lueckentext':
        final satz = a['satz'] as String;
        final l = [(a['luecke_1'] as List).cast<String>(), (a['luecke_2'] as List).cast<String>()];
        String fuell(int n) => _luecken[n] == null ? '___(${n + 1})___' : '[${l[n][_luecken[n]!]}]';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(satz.replaceAll('{1}', fuell(0)).replaceAll('{2}', fuell(1)), style: tokens.body(size: 17)),
            gap,
            for (var n = 0; n < 2; n++) ...[
              Text('Lücke ${n + 1}', style: tokens.body(size: 14, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < l[n].length; i++)
                    DesignSystemChip(
                      label: l[n][i],
                      selected: _luecken[n] == i,
                      onTap: widget.enabled
                          ? () {
                              _luecken[n] = i;
                              _melde(
                                List<int?>.of(_luecken),
                                '${_luecken[0] == null ? '' : l[0][_luecken[0]!]} | ${_luecken[1] == null ? '' : l[1][_luecken[1]!]}',
                              );
                            }
                          : null,
                    ),
                ],
              ),
              gap,
            ],
          ],
        );
      case 'zuordnung':
        final elemente = (a['elemente'] as List).cast<String>();
        final optionen = (a['optionen'] as List).cast<String>();
        const buchstaben = 'ABCDEF';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < optionen.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${buchstaben[i]}  ${optionen[i]}', style: tokens.body(size: 15)),
              ),
            gap,
            for (var e = 0; e < elemente.length; e++) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: tokens.glassCard(radius: tokens.chipRadius),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(elemente[e], style: tokens.body(weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < optionen.length; i++)
                          DesignSystemChip(
                            label: buchstaben[i],
                            selected: _zuordnung[e] == buchstaben[i],
                            onTap: widget.enabled
                                ? () {
                                    _zuordnung[e] = buchstaben[i];
                                    _melde(
                                      Map<int, String>.of(_zuordnung),
                                      [
                                        for (var k = 0; k < elemente.length; k++) '${k + 1}→${_zuordnung[k] ?? '-'}',
                                      ].join(' '),
                                    );
                                  }
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              gap,
            ],
          ],
        );
      case 'offen_zahl':
        return _zahlFeld(tokens, praefix: null, suffix: a['einheit'] as String?);
      case 'offen_term':
        return _termFeld(tokens, praefix: null, suffix: null);
      case 'halboffen':
        final vorlage = fuelleParameter(a['vorlage'] as String, widget.werte);
        final felder = eingabeFelder(vorlage);
        if (felder.length > 1) return _mehrereFelder(tokens, vorlage, felder);
        final teile = vorlage.split('{${felder.first}}');
        final suffix = teile.length > 1 && teile[1].trim().isNotEmpty ? teile[1] : (a['einheit'] as String?);
        if (a['art'] == 'term') return _termFeld(tokens, praefix: teile.first, suffix: suffix);
        return _zahlFeld(tokens, praefix: teile.first, suffix: suffix);
      case 'offen_text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _text,
              enabled: widget.enabled,
              maxLines: 4,
              style: tokens.body(),
              decoration: _deko(tokens, 'Deine Antwort (optional)'),
              onChanged: (t) => widget.onChanged(null, t),
            ),
            gap,
            _selbstHinweis(tokens),
          ],
        );
      default:
        return _selbstHinweis(tokens);
    }
  }

  Widget _selbstHinweis(DesignSystemTokens tokens) => Text(
    'Löse die Aufgabe auf Papier oder im Kopf. Danach deckst du die Lösung auf und bewertest dich selbst.',
    style: tokens.body(size: 14).copyWith(color: tokens.inkMuted),
  );

  InputDecoration _deko(DesignSystemTokens tokens, String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: tokens.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: tokens.glassBorder),
    ),
  );

  /// Zahlenpaar oder Lösungsliste: Vorlagentext mit einem Feld pro Platzhalter.
  Widget _mehrereFelder(DesignSystemTokens tokens, String vorlage, List<String> felder) {
    final teile = vorlage.split(RegExp(r'\{[xyz]\}'));
    void melde() {
      final werte = [for (final f in felder) _felder[f]!.text];
      _melde(werte, werte.join(' | '));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < felder.length; i++) ...[
          if (teile[i].trim().isNotEmpty) Text(teile[i].trim(), style: tokens.body(size: 17)),
          SizedBox(
            width: 110,
            child: TextField(
              key: ValueKey('zahl-eingabe-${felder[i]}'),
              controller: _felder.putIfAbsent(felder[i], TextEditingController.new),
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              style: tokens.body(size: 18, weight: FontWeight.w600),
              decoration: _deko(tokens, 'Zahl'),
              onChanged: (_) => melde(),
            ),
          ),
        ],
        if (teile.length > felder.length && teile.last.trim().isNotEmpty)
          Text(teile.last.trim(), style: tokens.body(size: 17)),
      ],
    );
  }

  /// Term oder Gleichung: normale Tastatur, Schreibweise egal (Vergleich an Zufallsstellen).
  Widget _termFeld(DesignSystemTokens tokens, {required String? praefix, required String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (praefix != null && praefix.trim().isNotEmpty) ...[
              Text(praefix.trim(), style: tokens.body(size: 17)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                key: const ValueKey('term-eingabe'),
                controller: _text,
                enabled: widget.enabled,
                autocorrect: false,
                enableSuggestions: false,
                style: tokens.body(size: 18, weight: FontWeight.w600),
                decoration: _deko(tokens, 'z. B. 2x + 3'),
                onChanged: (t) => _melde(t, t),
              ),
            ),
            if (suffix != null && suffix.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(suffix.trim(), style: tokens.body(size: 17)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Symbolleiste: fügt an der Cursor-Position ein (Handy-Tastaturen haben diese Zeichen kaum).
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final z in const ['x', 'y', '²', '^', '√', 'π', '(', ')', '·', '/', '−'])
              DesignSystemChip(
                key: ValueKey('symbol-$z'),
                label: z,
                selected: false,
                onTap: widget.enabled ? () => _einfuegen(z) : null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Schreibweise egal: 2x + 3, 3 + 2·x und f(x) = 2x + 3 zählen gleich. Hochzahl mit ^ oder ², z. B. x^3.',
          style: tokens.body(size: 13).copyWith(color: tokens.inkMuted),
        ),
      ],
    );
  }

  /// Fügt ein Zeichen der Symbolleiste an der Cursor-Position ein.
  void _einfuegen(String z) {
    final v = _text.value;
    final start = v.selection.isValid ? v.selection.start : v.text.length;
    final ende = v.selection.isValid ? v.selection.end : v.text.length;
    final text = v.text.replaceRange(start, ende, z);
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + z.length),
    );
    _melde(text, text);
  }

  Widget _zahlFeld(DesignSystemTokens tokens, {required String? praefix, required String? suffix}) {
    return Row(
      children: [
        if (praefix != null && praefix.trim().isNotEmpty) ...[
          Flexible(child: Text(praefix.trim(), style: tokens.body(size: 17))),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 150,
          child: TextField(
            key: const ValueKey('zahl-eingabe'),
            controller: _text,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            style: tokens.body(size: 18, weight: FontWeight.w600),
            decoration: _deko(tokens, 'Zahl'),
            onChanged: (t) => widget.onChanged(t, t),
          ),
        ),
        if (suffix != null && suffix.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(child: Text(suffix.trim(), style: tokens.body(size: 17))),
        ],
      ],
    );
  }
}

/// Richtige Lösung als lesbarer Text (Feedback nach dem zweiten Versuch,
/// Lösung bei Selbstbewertung und Selbstkontrolle).
String loesungAlsText(Item item, {Map<String, num> werte = const {}}) {
  final a = item.antwort;
  String zahl(num v) => zahlText(v);
  String fuelleFelder(String vorlage, List<dynamic> zahlen) {
    var t = fuelleParameter(vorlage, werte);
    final felder = eingabeFelder(t);
    for (var i = 0; i < felder.length && i < zahlen.length; i++) {
      t = t.replaceFirst('{${felder[i]}}', zahl(zahlen[i] as num));
    }
    return t;
  }

  switch (item.format) {
    case 'mc_1aus5' || 'mc_1aus6':
      return (a['optionen'] as List)[a['richtig'] as int] as String;
    case 'mc_2aus5':
      return [for (final i in a['richtig'] as List) (a['optionen'] as List)[i as int]].join('\n');
    case 'lueckentext':
      final r = (a['richtig'] as List).cast<int>();
      return '${(a['luecke_1'] as List)[r[0]]} / ${(a['luecke_2'] as List)[r[1]]}';
    case 'zuordnung':
      final el = (a['elemente'] as List).cast<String>();
      final opt = (a['optionen'] as List).cast<String>();
      final r = (a['richtig'] as Map);
      return [for (var i = 0; i < el.length; i++) '${el[i]} → ${opt['ABCDEF'.indexOf('${r['$i']}')]}'].join('\n');
    case 'offen_zahl' || 'halboffen':
      if (a['art'] == 'term') return '${a['term'] ?? a['wert']}';
      final vorlage = a['vorlage'] as String?;
      if (a['pruefregel'] is List) {
        final beispiel = a['beispiel'] as List?;
        final text = beispiel == null || vorlage == null ? '' : 'Zum Beispiel: ${fuelleFelder(vorlage, beispiel)}';
        return [text, 'Es gibt mehrere richtige Antworten.'].where((t) => t.isNotEmpty).join('\n');
      }
      final w = loesungsWert(item, werte);
      if (w is List) {
        final t = vorlage == null ? w.map((v) => zahl(v as num)).join(' | ') : fuelleFelder(vorlage, w);
        final egal = a['reihenfolge_egal'] == 'ja' || a['reihenfolge_egal'] == true;
        return egal ? '$t (Reihenfolge egal)' : t;
      }
      final e = a['einheit'] as String?;
      return w is num ? '${zahl(w)}${e == null ? '' : ' $e'}' : '';
    case 'offen_text':
      final m = a['musterloesung'];
      return m is List ? m.join('\n') : (m as String? ?? '');
    case 'offen_term':
      return a['term'] as String? ?? '';
    case 'konstruktion':
      return a['musterloesung'] as String? ?? '';
    default:
      return '';
  }
}
