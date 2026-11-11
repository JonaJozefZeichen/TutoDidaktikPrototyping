import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/editor/bausteine.dart';
import 'package:tuto_didaktik/thema.dart';

/// Formular für `antwort`: Alle Antworten stehen in fester Reihenfolge da, die
/// richtigen sind markiert, und nur die falschen haben ein Fehlerbild-Feld. Das
/// Formular ändert nur die Schlüssel, die es zeigt. Passt die Zahl der
/// Markierungen nicht zum Format, meldet das die Prüfung.
class AntwortFormular extends StatelessWidget {
  const AntwortFormular({
    super.key,
    required this.format,
    required this.antwort,
    required this.fehlerbilder,
    required this.vorschlaege,
    required this.onAendern,
    required this.onFehlerbilder,
    required this.onJsonGueltig,
    required this.onNeuAufbauen,
  });

  final String format;
  final Map<String, dynamic> antwort;
  final Map<String, dynamic> fehlerbilder;

  /// Schon verwendete Fehlerbild-Namen.
  final List<String> vorschlaege;

  /// Änderung anwenden und neu aufbauen.
  final void Function(void Function(Map<String, dynamic>)) onAendern;
  final void Function(void Function(Map<String, dynamic>)) onFehlerbilder;
  final ValueChanged<bool> onJsonGueltig;

  /// Nach einem Rollentausch müssen die Felder neue Werte anzeigen.
  final VoidCallback onNeuAufbauen;

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

  void _setzeFehlerbild(String schluessel, String name) => onFehlerbilder((f) {
    final n = name.trim();
    if (n.isEmpty) {
      f.remove(schluessel);
    } else {
      f[schluessel] = n;
    }
  });

  Widget _klein(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 3),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: grauText)),
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
      TextEingabe(
        wert: zahlAlsText(a[key]),
        hint: hint,
        onChanged: (v) => onAendern((m) => m[key] = zahlAusText(v)),
      ),
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
      for (var i = 0; i < kinder.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: kinder[i]),
      ],
    ],
  );

  /// Fehlerbild-Feld für eine falsche Antwort.
  Widget _fehlerbild(String schluessel) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: FehlerbildEingabe(
      key: ValueKey('fehlerbild-$schluessel'),
      wert: '${fehlerbilder[schluessel] ?? ''}',
      vorschlaege: vorschlaege,
      onChanged: (n) => _setzeFehlerbild(schluessel, n),
    ),
  );

  /// Fehlerbilder, deren Schlüssel zu keinem falschen Slot gehören, bleiben
  /// sichtbar und lassen sich entfernen, damit nichts still verschwindet.
  Widget _unpassende(Set<String> schluesselDerSlots) {
    final uebrig = fehlerbilder.keys.where((k) => !schluesselDerSlots.contains(k)).toList();
    if (uebrig.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _klein('Fehlerbilder ohne passende falsche Antwort'),
        for (final k in uebrig)
          Row(
            children: [
              Expanded(child: Text('$k: ${fehlerbilder[k]}', style: const TextStyle(fontSize: 12.5, color: hinweisGelb))),
              IconButton(
                tooltip: 'Fehlerbild entfernen',
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () => onFehlerbilder((f) => f.remove(k)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _ankreuzen() {
    final (n, richtige) = ankreuzFormate[format]!;
    final optionen = _liste('optionen', n);
    final markiert = richtigeIndizes(a['richtig']);

    void umschalten(int i) {
      final neu = markiert.contains(i)
          ? (markiert.where((x) => x != i).toList())
          // Bei 1-aus springt die Markierung; steht sie nach einem Wechsel auf
          // mehreren Antworten, muss man erst welche entfernen.
          : (richtige == 1 && markiert.length <= 1 ? [i] : [...markiert, i]);
      if (!markiert.contains(i)) onFehlerbilder((f) => f.remove('$i'));
      onAendern((m) => m['richtig'] = richtigFuerFormat(format, neu));
    }

    void entfernen(int i) {
      onFehlerbilder((f) {
        final neu = <String, dynamic>{};
        for (final e in f.entries) {
          final k = int.tryParse(e.key);
          if (k == i) continue;
          neu[k != null && k > i ? '${k - 1}' : e.key] = e.value;
        }
        f
          ..clear()
          ..addAll(neu);
      });
      onAendern((m) {
        m['optionen'] = [...optionen]..removeAt(i);
        m['richtig'] = richtigFuerFormat(format, [
          for (final x in markiert)
            if (x != i) x > i ? x - 1 : x,
        ]);
      });
      onNeuAufbauen();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < optionen.length; i++)
          _Slot(
            richtig: markiert.contains(i),
            label: 'Antwort ${i + 1}',
            hakenKey: ValueKey('richtig-$i'),
            onHaken: () => umschalten(i),
            aktion: optionen.length > n
                ? IconButton(
                    tooltip: 'Antwort entfernen',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: () => entfernen(i),
                  )
                : null,
            kinder: [
              TextEingabe(
                wert: '${optionen[i] ?? ''}',
                hint: 'Text eingeben',
                onChanged: (v) => _setzeListe('optionen', i, optionen.length, v),
              ),
              if (!markiert.contains(i)) _fehlerbild('$i'),
            ],
          ),
        _unpassende({
          for (var i = 0; i < optionen.length; i++)
            if (!markiert.contains(i)) '$i',
        }),
      ],
    );
  }

  Widget _luecke(int nr) {
    final key = 'luecke_$nr';
    final werte = _liste(key, 3);
    final richtigListe = a['richtig'] is List ? a['richtig'] as List : const [0, 0];
    final r = richtigListe.length >= nr && richtigListe[nr - 1] is int ? richtigListe[nr - 1] as int : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < werte.length; i++)
          _Slot(
            richtig: i == r,
            label: 'Lücke $nr, Antwort ${i + 1}',
            hakenKey: ValueKey('richtig-$nr-$i'),
            onHaken: () {
              if (i == r) return;
              onFehlerbilder((f) => f.remove('$nr:$i'));
              onAendern((m) {
                final neu = [...richtigListe];
                while (neu.length < 2) {
                  neu.add(0);
                }
                neu[nr - 1] = i;
                m['richtig'] = neu;
              });
            },
            kinder: [
              TextEingabe(
                wert: '${werte[i] ?? ''}',
                hint: 'Text eingeben',
                onChanged: (v) => _setzeListe(key, i, werte.length, v),
              ),
              if (i != r) _fehlerbild('$nr:$i'),
            ],
          ),
      ],
    );
  }

  Widget _zuordnung() {
    const buchstaben = ['A', 'B', 'C', 'D', 'E', 'F'];
    final elemente = _liste('elemente', 4);
    final optionen = _liste('optionen', 6);
    final richtig = a['richtig'] is Map ? a['richtig'] as Map : const {};
    final belegt = {for (var i = 0; i < 4; i++) richtig['$i']};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    werte: buchstaben,
                    onChanged: (v) {
                      if (v != null) onFehlerbilder((f) => f.remove('$v'));
                      onAendern((m) => m['richtig'] = {...richtig, '$i': v});
                    },
                  ),
                ),
              ],
            ),
          ),
        for (var i = 0; i < 6; i++)
          _Slot(
            richtig: belegt.contains(buchstaben[i]),
            label: 'Option ${buchstaben[i]}${belegt.contains(buchstaben[i]) ? ' (richtig)' : ''}',
            kinder: [
              TextEingabe(
                wert: '${optionen[i] ?? ''}',
                hint: 'Text eingeben',
                onChanged: (v) => _setzeListe('optionen', i, 6, v),
              ),
              if (!belegt.contains(buchstaben[i])) _fehlerbild(buchstaben[i]),
            ],
          ),
        _unpassende({
          for (final b in buchstaben)
            if (!belegt.contains(b)) b,
        }),
      ],
    );
  }

  Widget _einheitUndRundung() => _zeile([
    _text('Einheit', 'einheit', hint: 'km/h'),
    _wahl('Einheit Pflicht', 'einheit_pflicht', const ['ja', 'nein']),
    _zahl('Rundung', 'rundung', hint: 'Stellen'),
  ]);

  /// Freie Zeilen für offene Formate, bei Parametern nur ein Hinweis.
  Widget _falscheAntworten({required bool zahlen, required String beispiel}) {
    if (a['formel'] != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Bei Aufgaben mit Formel gibt es keine festen falschen Antworten, weil die Zahlen wechseln.',
          style: TextStyle(fontSize: 12, color: grauText.withValues(alpha: 0.95)),
        ),
      );
    }
    return FalscheAntwortenListe(
      fehlerbilder: fehlerbilder,
      vorschlaege: vorschlaege,
      zahlen: zahlen,
      beispiel: beispiel,
      onChanged: (neu) => onFehlerbilder((f) {
        f
          ..clear()
          ..addAll(neu);
      }),
    );
  }

  Widget _halboffen() {
    final wert = a['wert'];
    final istTerm = a['art'] == 'term';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Vorlage mit {x} als Eingabefeld', 'vorlage', hint: 'x = {x}'),
        _wahl('Art', 'art', const ['zahl', 'term'], pflicht: true),
        if (istTerm)
          _Slot(
            richtig: true,
            label: 'Richtiger Term',
            kinder: [
              TextEingabe(
                wert: '${a['term'] ?? ''}',
                hint: '2*x + 3',
                mono: true,
                onChanged: (v) => onAendern((m) => m['term'] = v.isEmpty ? null : v),
              ),
            ],
          )
        else if (a['pruefregel'] == null)
          _Slot(
            richtig: true,
            label: 'Richtiger Wert, bei mehreren Feldern mit ; trennen',
            kinder: [
              TextEingabe(
                wert: wert is List ? wert.map(zahlAlsText).join('; ') : zahlAlsText(wert),
                hint: '2; 3',
                onChanged: (v) => onAendern((m) {
                  final teile = v.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  m['wert'] = teile.length > 1 ? [for (final t in teile) zahlAusText(t)] : zahlAusText(v);
                }),
              ),
              _zeile([_zahl('Toleranz', 'toleranz', hint: '0,01'), _wahl('Reihenfolge egal', 'reihenfolge_egal', const ['ja', 'nein'])]),
              if (a['formel'] != null) _text('Formel', 'formel', mono: true),
            ],
          ),
        if (a['pruefregel'] != null) ...[
          _klein('Prüfregeln'),
          JsonFeld(
            wert: a['pruefregel'],
            onGueltig: onJsonGueltig,
            onChanged: (v) => onAendern((m) => m['pruefregel'] = v),
          ),
        ],
        if (!istTerm) _einheitUndRundung(),
        _falscheAntworten(zahlen: !istTerm, beispiel: istTerm ? 'x + 2' : '16'),
      ],
    );
  }

  Widget _terme() {
    final akzeptiert = a['akzeptiert'] is List ? (a['akzeptiert'] as List).cast<Object?>() : const <Object?>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Slot(
          richtig: true,
          label: 'Richtiger Term',
          kinder: [
            TextEingabe(
              wert: '${a['term'] ?? ''}',
              hint: '2*x + 3',
              mono: true,
              onChanged: (v) => onAendern((m) => m['term'] = v.isEmpty ? null : v),
            ),
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
        ),
        _falscheAntworten(zahlen: false, beispiel: 'x + 2'),
      ],
    );
  }

  Widget _selbstBewertet(List<Widget> kinder) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...kinder,
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Dieses Format bewerten die Lernenden selbst, deshalb gibt es keine falschen Antworten mit Fehlerbild.',
          style: TextStyle(fontSize: 12, color: grauText),
        ),
      ),
      _unpassende(const {}),
    ],
  );

  Widget _konstruktion() {
    final geometrieKey = a.containsKey('loesung') ? 'loesung' : 'geometrie';
    return _selbstBewertet([
      _wahl('Zeichenfläche', 'zeichenflaeche', const ['koordinatensystem', 'zahlengerade', 'einheitskreis', 'diagramm'], pflicht: true),
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
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      'mc_1aus5' || 'mc_1aus6' || 'mc_2aus5' => _ankreuzen(),
      'lueckentext' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _text('Satz mit {1} und {2}', 'satz', mehrzeilig: true),
          const SizedBox(height: 6),
          _luecke(1),
          _luecke(2),
          _unpassende({
            for (final n in [1, 2])
              for (final i in [0, 1, 2])
                if (!(a['richtig'] is List && (a['richtig'] as List).length >= n && (a['richtig'] as List)[n - 1] == i)) '$n:$i',
          }),
        ],
      ),
      'zuordnung' => _zuordnung(),
      'halboffen' => _halboffen(),
      'offen_zahl' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Slot(
            richtig: true,
            label: 'Richtiger Wert',
            kinder: [
              _zeile([_zahl('Wert', 'wert'), _zahl('Toleranz', 'toleranz', hint: '0,01')]),
              if (a['formel'] != null) _text('Formel', 'formel', mono: true),
            ],
          ),
          _einheitUndRundung(),
          _falscheAntworten(zahlen: true, beispiel: '16'),
        ],
      ),
      'offen_term' => _terme(),
      'offen_text' => _selbstBewertet([
        _text('Musterlösung', 'musterloesung', mehrzeilig: true),
        _text('Bewertungskriterium', 'bewertungskriterium', mehrzeilig: true),
      ]),
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

/// Eine Antwort: grün für richtig, neutral für falsch, immer gleich aufgebaut.
/// Mit [onHaken] lässt sie sich als richtig markieren.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.richtig,
    required this.label,
    required this.kinder,
    this.aktion,
    this.onHaken,
    this.hakenKey,
  });

  final bool richtig;
  final String label;
  final List<Widget> kinder;
  final Widget? aktion;
  final VoidCallback? onHaken;
  final Key? hakenKey;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
    decoration: BoxDecoration(
      color: richtig ? const Color(0xFFE9F6EC) : flaeche,
      border: Border.all(color: richtig ? const Color(0xFFB4DDBE) : linie),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onHaken != null)
              Tooltip(
                message: richtig ? 'Ist als richtig markiert' : 'Als richtig markieren',
                child: Checkbox(
                  key: hakenKey,
                  value: richtig,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: const Color(0xFF1B6B32),
                  onChanged: (_) => onHaken!(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  richtig ? Icons.check_circle_outline : Icons.highlight_off,
                  size: 15,
                  color: richtig ? const Color(0xFF1B6B32) : grauText,
                ),
              ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: richtig ? const Color(0xFF1B6B32) : grauText),
              ),
            ),
            ?aktion,
          ],
        ),
        const SizedBox(height: 4),
        ...kinder,
      ],
    ),
  );
}

/// Name des Fehlerbilds mit Vorschlägen aus den schon verwendeten Namen.
class FehlerbildEingabe extends StatelessWidget {
  const FehlerbildEingabe({super.key, required this.wert, required this.vorschlaege, required this.onChanged});

  final String wert;
  final List<String> vorschlaege;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: wert),
    optionsBuilder: (v) {
      final q = v.text.trim().toLowerCase();
      if (q.isEmpty) return const Iterable<String>.empty();
      return vorschlaege.where((s) => s.contains(q) && s != q);
    },
    onSelected: onChanged,
    fieldViewBuilder: (context, controller, fokus, _) => TextField(
      controller: controller,
      focusNode: fokus,
      style: const TextStyle(fontFamily: schrift, fontFeatures: ziffern, fontSize: 12.5),
      decoration: const InputDecoration(hintText: 'Fehlerbild, z. B. vorzeichenfehler'),
      onChanged: onChanged,
    ),
  );
}

/// Freie Zeilen für offene Formate: falsches Ergebnis und Fehlerbild. Am Ende
/// steht immer eine leere Zeile. Gespeichert wird eine Zeile erst mit beiden
/// Angaben.
class FalscheAntwortenListe extends StatefulWidget {
  const FalscheAntwortenListe({
    super.key,
    required this.fehlerbilder,
    required this.vorschlaege,
    required this.zahlen,
    required this.beispiel,
    required this.onChanged,
  });

  final Map<String, dynamic> fehlerbilder;
  final List<String> vorschlaege;

  /// Falsche Antworten sind Zahlen: Komma erlaubt, gespeichert wird mit Punkt.
  final bool zahlen;
  final String beispiel;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<FalscheAntwortenListe> createState() => _FalscheAntwortenListeState();
}

class _Zeile {
  _Zeile(this.antwort, this.name);
  String antwort;
  String name;
  bool get leer => antwort.trim().isEmpty && name.trim().isEmpty;
  bool get vollstaendig => antwort.trim().isNotEmpty && name.trim().isNotEmpty;
}

class _FalscheAntwortenListeState extends State<FalscheAntwortenListe> {
  late final List<_Zeile> _zeilen = [
    for (final e in widget.fehlerbilder.entries)
      _Zeile(widget.zahlen ? e.key.replaceAll('.', ',') : e.key, '${e.value}'),
  ];
  int _naechste = 0;
  late final List<int> _ids = [for (final _ in _zeilen) _naechste++];

  @override
  void initState() {
    super.initState();
    _ids;
    _leereDazu();
  }

  void _leereDazu() {
    if (_zeilen.isEmpty || !_zeilen.last.leer) {
      _zeilen.add(_Zeile('', ''));
      _ids.add(_naechste++);
    }
  }

  String _schluessel(String eingabe) {
    final t = eingabe.trim();
    if (!widget.zahlen) return t;
    return t.split(';').map((s) {
      final z = zahlAusText(s);
      return z is num ? '$z' : s.trim();
    }).join('; ');
  }

  void _melden() {
    setState(_leereDazu);
    widget.onChanged({
      for (final z in _zeilen)
        if (z.vollstaendig) _schluessel(z.antwort): z.name.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < _zeilen.length; i++)
        KeyedSubtree(
          key: ValueKey(_ids[i]),
          child: _Slot(
            richtig: false,
            label: 'Falsche Antwort ${i + 1}',
            aktion: _zeilen[i].leer
                ? null
                : IconButton(
                    tooltip: 'Zeile entfernen',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: () {
                      _zeilen.removeAt(i);
                      _ids.removeAt(i);
                      _melden();
                    },
                  ),
            kinder: [
              TextEingabe(
                wert: _zeilen[i].antwort,
                hint: widget.beispiel,
                mono: !widget.zahlen,
                onChanged: (v) {
                  _zeilen[i].antwort = v;
                  _melden();
                },
              ),
              const SizedBox(height: 4),
              FehlerbildEingabe(
                wert: _zeilen[i].name,
                vorschlaege: widget.vorschlaege,
                onChanged: (v) {
                  _zeilen[i].name = v;
                  _melden();
                },
              ),
              if (!_zeilen[i].leer && !_zeilen[i].vollstaendig)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Wird erst mit beiden Angaben gespeichert.',
                    style: TextStyle(fontSize: 11.5, color: hinweisGelb),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
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
