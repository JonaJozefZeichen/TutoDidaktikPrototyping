import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/hilfe.dart';
import 'package:tuto_didaktik/thema.dart';

/// Stellt Befunde und Sprungziele für die Felder bereit.
class EditorScope extends InheritedWidget {
  const EditorScope({super.key, required this.befunde, required this.ziele, required super.child});

  final List<Befund> befunde;
  final Map<String, GlobalKey> ziele;

  static EditorScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EditorScope>()!;

  @override
  bool updateShouldNotify(EditorScope old) => true;
}

/// Beschriftung, "?" zum Bauplan, Eingabe und Befunde direkt am Feld. Überall
/// gleich, damit die Bedienung schnell gelernt ist.
class FeldRahmen extends StatelessWidget {
  const FeldRahmen({
    super.key,
    required this.label,
    required this.pfad,
    required this.child,
    this.pflicht = false,
    this.hilfe,
  });

  final String label;
  final String pfad;
  final bool pflicht;

  /// Suchbegriff im Bauplan, meist der Feldname.
  final String? hilfe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = EditorScope.of(context);
    final befunde = scope.befunde.where((b) => b.pfad == pfad).toList();
    final ziel = scope.ziele.putIfAbsent(pfad, GlobalKey.new);
    return Padding(
      key: ziel,
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(pflicht ? '$label *' : label, style: Theme.of(context).textTheme.labelMedium)),
              if (hilfe != null)
                InkWell(
                  onTap: () => HilfeScope.of(context).oeffne(
                    hilfeBegriffFuer(hilfe!),
                    pfad.startsWith('items/') ? 'Ein Item anlegen' : 'Eine Aufgabe anlegen',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Tooltip(
                    message: 'Im Bauplan nachsehen: ${hilfeBegriffFuer(hilfe!)}',
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.help_outline, size: 14, color: grauText),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          child,
          for (final b in befunde)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                b.text,
                style: TextStyle(
                  fontSize: 12,
                  color: b.istFehler ? fehlerRot : hinweisGelb,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Texteingabe; übernimmt neue Werte von außen, solange sie keinen Fokus hat.
class TextEingabe extends StatefulWidget {
  const TextEingabe({
    super.key,
    required this.wert,
    required this.onChanged,
    this.hint,
    this.mehrzeilig = false,
    this.mono = false,
  });

  final String wert;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool mehrzeilig;
  final bool mono;

  @override
  State<TextEingabe> createState() => _TextEingabeState();
}

class _TextEingabeState extends State<TextEingabe> {
  late final _c = TextEditingController(text: widget.wert);
  final _fokus = FocusNode();

  @override
  void didUpdateWidget(covariant TextEingabe old) {
    super.didUpdateWidget(old);
    if (!_fokus.hasFocus && _c.text != widget.wert) _c.text = widget.wert;
  }

  @override
  void dispose() {
    _c.dispose();
    _fokus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    focusNode: _fokus,
    minLines: widget.mehrzeilig ? 2 : 1,
    maxLines: widget.mehrzeilig ? 8 : 1,
    style: widget.mono ? const TextStyle(fontFamily: monoSchrift, fontSize: 12.5) : const TextStyle(fontSize: 13.5),
    decoration: InputDecoration(hintText: widget.hint),
    onChanged: widget.onChanged,
  );
}

/// Dropdown für feste Werte. Ein Wert außerhalb der Liste bleibt sichtbar,
/// damit nichts still verloren geht; die Prüfung meldet ihn.
class WahlFeld extends StatelessWidget {
  const WahlFeld({
    super.key,
    required this.wert,
    required this.werte,
    required this.onChanged,
    this.leer = '–',
    this.pflicht = false,
    this.name,
  });

  final Object? wert;
  final List<Object> werte;
  final ValueChanged<Object?> onChanged;
  final String leer;
  final bool pflicht;
  final String Function(Object)? name;

  @override
  Widget build(BuildContext context) {
    final fremd = wert != null && !werte.contains(wert);
    return InputDecorator(
      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Object?>(
          value: wert,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 13.5, color: tinte, fontFamily: 'Open Sans'),
          items: [
            if (!pflicht || wert == null) DropdownMenuItem<Object?>(value: null, child: Text(leer)),
            if (fremd) DropdownMenuItem<Object?>(value: wert, child: Text('$wert (ungültig)')),
            for (final w in werte)
              DropdownMenuItem<Object?>(
                value: w,
                child: Text(name?.call(w) ?? '$w', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class SuchOption {
  const SuchOption(this.wert, [this.text]);
  final String wert;
  final String? text;
}

/// Dropdown mit Suche für lange Listen, einfach oder mehrfach.
class SuchFeld extends StatelessWidget {
  const SuchFeld({
    super.key,
    required this.titel,
    required this.werte,
    required this.optionen,
    required this.onChanged,
    this.mehrfach = false,
    this.frei = false,
    this.hint = 'Auswählen …',
  });

  final String titel;
  final List<String> werte;
  final List<SuchOption> optionen;
  final ValueChanged<List<String>> onChanged;
  final bool mehrfach;

  /// Auch ein neuer Wert ist erlaubt (z. B. neue Kompetenz).
  final bool frei;
  final String hint;

  Future<void> _waehle(BuildContext context) async {
    final gewaehlt = await showDialog<String>(
      context: context,
      builder: (_) => _SuchDialog(titel: titel, optionen: optionen, frei: frei),
    );
    if (gewaehlt == null) return;
    if (mehrfach) {
      if (!werte.contains(gewaehlt)) onChanged([...werte, gewaehlt]);
    } else {
      onChanged([gewaehlt]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mehrfach) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final w in werte)
            InputChip(
              label: Text(w, style: const TextStyle(fontSize: 12)),
              onDeleted: () => onChanged([...werte]..remove(w)),
              visualDensity: VisualDensity.compact,
            ),
          OutlinedButton.icon(
            onPressed: () => _waehle(context),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Hinzufügen'),
          ),
        ],
      );
    }
    final wert = werte.isEmpty ? null : werte.first;
    return InkWell(
      onTap: () => _waehle(context),
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: wert == null
              ? const Icon(Icons.search, size: 16)
              : IconButton(
                  tooltip: 'Leeren',
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onChanged(const []),
                ),
        ),
        child: Text(
          wert ?? hint,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, color: wert == null ? const Color(0xFF9AA5B4) : tinte),
        ),
      ),
    );
  }
}

class _SuchDialog extends StatefulWidget {
  const _SuchDialog({required this.titel, required this.optionen, required this.frei});

  final String titel;
  final List<SuchOption> optionen;
  final bool frei;

  @override
  State<_SuchDialog> createState() => _SuchDialogState();
}

class _SuchDialogState extends State<_SuchDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final treffer = widget.optionen
        .where((o) => q.isEmpty || o.wert.toLowerCase().contains(q) || (o.text ?? '').toLowerCase().contains(q))
        .take(200)
        .toList();
    final neu = widget.frei && q.isNotEmpty && !widget.optionen.any((o) => o.wert == _q.trim());
    return AlertDialog(
      title: Text(widget.titel),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Suchen', prefixIcon: Icon(Icons.search, size: 18)),
              onChanged: (v) => setState(() => _q = v),
              onSubmitted: (_) {
                if (treffer.length == 1) Navigator.pop(context, treffer.first.wert);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  if (neu)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add, size: 18),
                      title: Text('"${_q.trim()}" übernehmen'),
                      subtitle: const Text('Neuer Wert, steht noch nicht in der Liste'),
                      onTap: () => Navigator.pop(context, _q.trim()),
                    ),
                  for (final o in treffer)
                    ListTile(
                      dense: true,
                      title: Text(o.wert, style: const TextStyle(fontFamily: monoSchrift, fontSize: 12.5)),
                      subtitle: o.text == null ? null : Text(o.text!),
                      onTap: () => Navigator.pop(context, o.wert),
                    ),
                  if (treffer.isEmpty && !neu)
                    const Padding(padding: EdgeInsets.all(12), child: Text('Nichts gefunden.')),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))],
    );
  }
}

/// JSON-Feld für seltene, verschachtelte Angaben. Nur gültiges JSON wird
/// übernommen; solange es ungültig ist, bleibt Speichern gesperrt.
class JsonFeld extends StatefulWidget {
  const JsonFeld({super.key, required this.wert, required this.onChanged, required this.onGueltig, this.hint});

  final Object? wert;
  final ValueChanged<Object?> onChanged;
  final ValueChanged<bool> onGueltig;
  final String? hint;

  @override
  State<JsonFeld> createState() => _JsonFeldState();
}

class _JsonFeldState extends State<JsonFeld> {
  static const _einzug = JsonEncoder.withIndent('  ');
  late final _c = TextEditingController(text: _text(widget.wert));
  String? _fehler;

  String _text(Object? v) {
    if (v == null || (v is List && v.isEmpty) || (v is Map && v.isEmpty)) return '';
    return _einzug.convert(v);
  }

  void _geaendert(String s) {
    if (s.trim().isEmpty) {
      setState(() => _fehler = null);
      widget.onGueltig(true);
      widget.onChanged(null);
      return;
    }
    try {
      final v = jsonDecode(s);
      setState(() => _fehler = null);
      widget.onGueltig(true);
      widget.onChanged(v);
    } on FormatException catch (e) {
      setState(() => _fehler = 'Kein gültiges JSON: ${e.message}');
      widget.onGueltig(false);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    minLines: 2,
    maxLines: 10,
    style: const TextStyle(fontFamily: monoSchrift, fontSize: 12),
    decoration: InputDecoration(hintText: widget.hint ?? '[ ]', errorText: _fehler, errorMaxLines: 3),
    onChanged: _geaendert,
  );
}

/// Zahl aus einer Eingabe: deutsches Komma erlaubt, ganze Zahlen bleiben ganz.
/// Unlesbares bleibt Text, damit die Prüfung es meldet.
Object? zahlAusText(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final d = double.tryParse(t);
  if (d == null) return s.trim();
  return d == d.roundToDouble() && !t.contains('.') ? d.toInt() : d;
}

String zahlAlsText(Object? v) => v == null ? '' : '$v'.replaceAll('.', ',');
