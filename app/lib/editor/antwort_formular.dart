import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/bausteine.dart';
import 'package:tuto_didaktik/thema.dart';

/// Formular für `antwort`, je nach `antwortformat` andere Felder. Es ändert nur
/// die Schlüssel, die es zeigt; alles andere im JSON bleibt erhalten.
class AntwortFormular extends StatelessWidget {
  const AntwortFormular({
    super.key,
    required this.format,
    required this.antwort,
    required this.onAendern,
    required this.onJsonGueltig,
  });

  final String format;
  final Map<String, dynamic> antwort;

  /// Änderung anwenden und neu aufbauen.
  final void Function(void Function(Map<String, dynamic>)) onAendern;
  final ValueChanged<bool> onJsonGueltig;

  Map<String, dynamic> get a => antwort;

  List<Object?> _liste(String key, int laenge) {
    final v = a[key];
    final l = v is List ? [...v] : <Object?>[];
    while (l.length < laenge) {
      l.add('');
    }
    return l;
  }

  void _setzeListe(String key, int i, int laenge, Object? wert) => onAendern((m) {
    final l = _liste(key, laenge);
    l[i] = wert;
    m[key] = l;
  });

  Widget _klein(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 3),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: grauText),
    ),
  );

  Widget _text(String label, String key, {String? hint, bool mehrzeilig = false, bool mono = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _klein(label),
      TextEingabe(
        wert: a[key] is String ? a[key] as String : (a[key]?.toString() ?? ''),
        hint: hint,
        mehrzeilig: mehrzeilig,
        mono: mono,
        onChanged: (v) => onAendern((m) => m[key] = v.isEmpty ? null : v),
      ),
    ],
  );

  Widget _zahl(String label, String key, {String? hint}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _klein(label),
      TextEingabe(wert: zahlAlsText(a[key]), hint: hint, onChanged: (v) => onAendern((m) => m[key] = zahlAusText(v))),
    ],
  );

  Widget _wahl(String label, String key, List<Object> werte, {bool pflicht = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _klein(label),
      WahlFeld(wert: a[key], werte: werte, pflicht: pflicht, onChanged: (v) => onAendern((m) => m[key] = v)),
    ],
  );

  Widget _zeile(List<Widget> kinder) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < kinder.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: kinder[i])],
    ],
  );

  Widget _mc(int n, {required bool zwei}) {
    final optionen = _liste('optionen', n);
    final richtig = a['richtig'];
    final gewaehlt = zwei ? {...(richtig is List ? richtig : const [])} : {richtig};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _klein(zwei ? 'Optionen, genau zwei als richtig markieren' : 'Optionen, die richtige markieren'),
        for (var i = 0; i < n; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Tooltip(
                  message: 'Als richtig markieren',
                  child: Checkbox(
                    value: gewaehlt.contains(i),
                    onChanged: (_) => onAendern((m) {
                      if (zwei) {
                        final s = {...gewaehlt};
                        s.contains(i) ? s.remove(i) : s.add(i);
                        m['richtig'] = s.toList()..sort((x, y) => (x as int).compareTo(y as int));
                      } else {
                        m['richtig'] = i;
                      }
                    }),
                  ),
                ),
                Expanded(
                  child: TextEingabe(
                    wert: '${optionen[i] ?? ''}',
                    hint: 'Option ${i + 1}',
                    onChanged: (v) => _setzeListe('optionen', i, n, v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _luecke(int nr) {
    final key = 'luecke_$nr';
    final werte = _liste(key, 3);
    final richtig = a['richtig'] is List ? a['richtig'] as List : const [0, 0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _klein('Lücke $nr, die richtige markieren'),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Checkbox(
                  value: richtig.length >= nr && richtig[nr - 1] == i,
                  onChanged: (_) => onAendern((m) {
                    final r = [...richtig];
                    while (r.length < 2) {
                      r.add(0);
                    }
                    r[nr - 1] = i;
                    m['richtig'] = r;
                  }),
                ),
                Expanded(
                  child: TextEingabe(wert: '${werte[i] ?? ''}', onChanged: (v) => _setzeListe(key, i, 3, v)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _zuordnung() {
    final elemente = _liste('elemente', 4);
    final optionen = _liste('optionen', 6);
    final richtig = a['richtig'] is Map ? a['richtig'] as Map : const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _klein('Optionen A-F'),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text(String.fromCharCode(65 + i))),
                Expanded(
                  child: TextEingabe(wert: '${optionen[i] ?? ''}', onChanged: (v) => _setzeListe('optionen', i, 6, v)),
                ),
              ],
            ),
          ),
        _klein('Elemente und ihre richtige Option'),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextEingabe(
                    wert: '${elemente[i] ?? ''}',
                    hint: 'Element ${i + 1}',
                    onChanged: (v) => _setzeListe('elemente', i, 4, v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: WahlFeld(
                    wert: richtig['$i'],
                    werte: const ['A', 'B', 'C', 'D', 'E', 'F'],
                    onChanged: (v) => onAendern((m) {
                      m['richtig'] = {...richtig, '$i': v};
                    }),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _einheitUndRundung() => _zeile([
    _text('Einheit', 'einheit', hint: 'km/h'),
    _wahl('Einheit Pflicht', 'einheit_pflicht', const ['ja', 'nein']),
    _zahl('Rundung', 'rundung', hint: 'Stellen'),
  ]);

  Widget _halboffen() {
    final wert = a['wert'];
    final istTerm = a['art'] == 'term';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Vorlage mit {x} als Eingabefeld', 'vorlage', hint: 'x = {x}'),
        _wahl('Art', 'art', const ['zahl', 'term'], pflicht: true),
        if (istTerm)
          _text('Term', 'term', hint: '2*x + 3', mono: true)
        else if (a['pruefregel'] == null) ...[
          _klein('Wert, bei mehreren Feldern mit ; trennen'),
          TextEingabe(
            wert: wert is List ? wert.map(zahlAlsText).join('; ') : zahlAlsText(wert),
            hint: '2; 3',
            onChanged: (v) => onAendern((m) {
              final teile = v.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              m['wert'] = teile.length > 1 ? [for (final t in teile) zahlAusText(t)] : zahlAusText(v);
            }),
          ),
          _zeile([
            _zahl('Toleranz', 'toleranz', hint: '0,01'),
            _wahl('Reihenfolge egal', 'reihenfolge_egal', const ['ja', 'nein']),
          ]),
          if (a['formel'] != null) _text('Formel', 'formel', mono: true),
        ],
        if (a['pruefregel'] != null) ...[
          _klein('Prüfregeln'),
          JsonFeld(
            wert: a['pruefregel'],
            onGueltig: onJsonGueltig,
            onChanged: (v) => onAendern((m) => m['pruefregel'] = v),
          ),
        ],
        if (!istTerm) _einheitUndRundung(),
      ],
    );
  }

  Widget _terme() {
    final akzeptiert = a['akzeptiert'] is List ? (a['akzeptiert'] as List).cast<Object?>() : const <Object?>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Term', 'term', hint: '2*x + 3', mono: true),
        _klein('Weitere gültige Schreibweisen, eine pro Zeile'),
        TextEingabe(
          wert: akzeptiert.join('\n'),
          mehrzeilig: true,
          mono: true,
          onChanged: (v) => onAendern((m) {
            final l = v.split('\n').where((s) => s.trim().isNotEmpty).toList();
            if (l.isEmpty) {
              m.remove('akzeptiert');
            } else {
              m['akzeptiert'] = l;
            }
          }),
        ),
      ],
    );
  }

  Widget _konstruktion() {
    final geometrieKey = a.containsKey('loesung') ? 'loesung' : 'geometrie';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wahl('Zeichenfläche', 'zeichenflaeche', const [
          'koordinatensystem',
          'zahlengerade',
          'einheitskreis',
          'diagramm',
        ], pflicht: true),
        _wahl('Ziel', 'ziel', const ['punkt', 'vektor', 'gerade', 'graph', 'flaeche', 'saeule'], pflicht: true),
        _zahl('Toleranz', 'toleranz', hint: '0,1'),
        _text('Musterlösung als Text', 'musterloesung', mehrzeilig: true),
        _klein('Bereich [x min, x max, y min, y max]'),
        JsonFeld(wert: a['bereich'], onGueltig: onJsonGueltig, onChanged: (v) => onAendern((m) => m['bereich'] = v)),
        _klein('Zielgeometrie ($geometrieKey)'),
        JsonFeld(
          wert: a[geometrieKey],
          hint: '{ }',
          onGueltig: onJsonGueltig,
          onChanged: (v) => onAendern((m) => m[geometrieKey] = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      'mc_1aus5' => _mc(5, zwei: false),
      'mc_1aus6' => _mc(6, zwei: false),
      'mc_2aus5' => _mc(5, zwei: true),
      'lueckentext' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_text('Satz mit {1} und {2}', 'satz', mehrzeilig: true), _luecke(1), _luecke(2)],
      ),
      'zuordnung' => _zuordnung(),
      'halboffen' => _halboffen(),
      'offen_zahl' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _zeile([_zahl('Wert', 'wert'), _zahl('Toleranz', 'toleranz', hint: '0,01')]),
          if (a['formel'] != null) _text('Formel', 'formel', mono: true),
          _einheitUndRundung(),
        ],
      ),
      'offen_term' => _terme(),
      'offen_text' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text('Musterlösung', 'musterloesung', mehrzeilig: true),
          _text('Bewertungskriterium', 'bewertungskriterium', mehrzeilig: true),
        ],
      ),
      'konstruktion' => _konstruktion(),
      _ => JsonFeld(
        wert: a,
        onGueltig: onJsonGueltig,
        onChanged: (v) => onAendern((m) {
          m
            ..clear()
            ..addAll(v is Map<String, dynamic> ? v : const {});
        }),
      ),
    };
  }
}

/// Die drei Hilfen mit Text und Freigabe. Geänderter Text ist kein KI-Entwurf mehr.
class HilfenFormular extends StatelessWidget {
  const HilfenFormular({super.key, required this.hilfen, required this.onAendern});

  final List<dynamic> hilfen;
  final void Function(void Function(List<Map<String, dynamic>>)) onAendern;

  static const _namen = {1: 'Orientierung', 2: 'Strategie', 3: 'Lösungsansatz'};

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> hilfe(int stufe) {
      for (final h in hilfen) {
        if (h is Map<String, dynamic> && h['stufe'] == stufe) return h;
      }
      return {'stufe': stufe, 'text': ''};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stufe in [1, 2, 3])
          Builder(
            builder: (context) {
              final h = hilfe(stufe);
              final freigabe = h['freigabe'] is Map ? h['freigabe'] as Map : const {};
              final art = freigabe.containsKey('nach_fehlversuchen') ? 'nach_fehlversuchen' : 'nach_sekunden';
              void aendern(void Function(Map<String, dynamic>) f) => onAendern((l) {
                var ziel = l.where((x) => x['stufe'] == stufe).firstOrNull;
                if (ziel == null) {
                  ziel = {'stufe': stufe, 'text': ''};
                  l.add(ziel);
                  l.sort((x, y) => (x['stufe'] as int).compareTo(y['stufe'] as int));
                }
                f(ziel);
              });
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Hilfe $stufe: ${_namen[stufe]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: grauText),
                        ),
                        if (h['entwurf'] == 'ki') ...[
                          const SizedBox(width: 6),
                          const Text(
                            'KI-Entwurf',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hinweisGelb),
                          ),
                          TextButton(
                            onPressed: () => aendern((z) => z.remove('entwurf')),
                            child: const Text('als geprüft markieren', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    TextEingabe(
                      wert: '${h['text'] ?? ''}',
                      mehrzeilig: true,
                      onChanged: (v) => aendern((z) {
                        z['text'] = v;
                        z.remove('entwurf');
                      }),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 170,
                          child: WahlFeld(
                            wert: art,
                            werte: const ['nach_sekunden', 'nach_fehlversuchen'],
                            pflicht: true,
                            name: (w) => w == 'nach_sekunden' ? 'nach Sekunden' : 'nach Fehlversuchen',
                            onChanged: (v) => aendern((z) => z['freigabe'] = {'$v': freigabe[art] ?? 1}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextEingabe(
                            wert: '${freigabe[art] ?? ''}',
                            hint: '20',
                            onChanged: (v) => aendern((z) => z['freigabe'] = {art: int.tryParse(v.trim()) ?? v}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
