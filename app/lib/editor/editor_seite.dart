import 'dart:convert';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/editor/antwort_formular.dart';
import 'package:tuto_didaktik/editor/bausteine.dart';
import 'package:tuto_didaktik/editor/verlauf.dart';
import 'package:tuto_didaktik/editor/vorschau.dart';
import 'package:tuto_didaktik/thema.dart';

/// Aufgaben-Editor: Tags links, Handy-Vorschau in der Mitte, Items rechts,
/// oben Status, Approvals und Aktionen.
class EditorSeite extends StatefulWidget {
  const EditorSeite({
    super.key,
    required this.api,
    required this.person,
    required this.stamm,
    required this.id,
    required this.reihenfolge,
    required this.onGeaendert,
  });

  final Api api;
  final Person person;
  final Stammdaten stamm;
  final String id;
  final List<String> reihenfolge;
  final VoidCallback onGeaendert;

  @override
  State<EditorSeite> createState() => _EditorSeiteState();
}

class _EditorSeiteState extends State<EditorSeite> {
  late String _id = widget.id;
  Eintrag? _eintrag;
  Map<String, dynamic> _inhalt = {};
  String _gespeichert = '';
  String? _ladeFehler;
  bool _beschaeftigt = false;
  bool _weiterNachApproval = true;
  int _ladeZaehler = 0;
  final _offeneItems = <int>{0};
  final _jsonUngueltig = <String>{};

  /// Antworten aus anderen Formaten, pro Item und Formatfamilie, bis zum nächsten Laden.
  final _antwortMerk = <String, Map<String, Map<String, dynamic>>>{};
  final _ziele = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _lade(_id);
  }

  bool get _geaendert => jsonEncode(_inhalt) != _gespeichert;

  int get _position => widget.reihenfolge.indexOf(_id);

  static Map<String, dynamic> _kopie(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  void _uebernimm(Eintrag e, {bool neuAufbauen = true}) {
    setState(() {
      _eintrag = e;
      _inhalt = _kopie(e.aktuell.inhalt);
      _gespeichert = jsonEncode(_inhalt);
      _ladeFehler = null;
      _jsonUngueltig.clear();
      if (neuAufbauen) {
        _ladeZaehler++;
        _antwortMerk.clear();
      }
    });
  }

  Future<void> _lade(String id) async {
    try {
      final d = await widget.api.aufgabe(id);
      if (!mounted) return;
      _id = id;
      _offeneItems
        ..clear()
        ..add(0);
      _ziele.clear();
      _uebernimm(d.eintrag);
    } on ApiFehler catch (e) {
      if (mounted) setState(() => _ladeFehler = e.text);
    }
  }

  /// Fragt bei ungespeicherten Änderungen nach. `true` = weitermachen.
  Future<bool> _darfVerlassen() async {
    if (!_geaendert) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text('Die Änderungen an dieser Aufgabe gehen verloren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Weiter bearbeiten')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Verwerfen')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _gehe(int richtung) async {
    final p = _position + richtung;
    if (p < 0 || p >= widget.reihenfolge.length) return;
    if (await _darfVerlassen()) await _lade(widget.reihenfolge[p]);
  }

  Future<T?> _aktion<T>(Future<T> Function() f) async {
    if (_beschaeftigt) return null;
    setState(() => _beschaeftigt = true);
    try {
      return await f();
    } on ApiFehler catch (e) {
      if (mounted) zeigeMeldung(context, e.text, fehler: true);
      return null;
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  Future<void> _speichere() async {
    final e = _eintrag;
    if (e == null || !_geaendert || _jsonUngueltig.isNotEmpty || _beschaeftigt) return;
    final approvals = e.aktuell.approvals.length;
    final warnung = e.status == 'live'
        ? 'Die Fassung in der App bleibt unverändert, bis diese Korrektur zwei Approvals hat.'
        : approvals > 0
        ? 'Speichern setzt ${approvals == 1 ? 'das vorhandene Approval' : 'die vorhandenen Approvals'} zurück.'
        : null;
    if (warnung != null && !await _bestaetige('Neue Fassung speichern?', warnung, 'Speichern')) return;
    await _sende(e, trotzdem: false);
  }

  Future<void> _sende(Eintrag e, {required bool trotzdem}) async {
    if (_beschaeftigt) return;
    setState(() => _beschaeftigt = true);
    try {
      final d = await widget.api.speichere(_id, _inhalt, basis: e.aktuell.nr, trotzdem: trotzdem);
      if (!mounted) return;
      _uebernimm(d.eintrag, neuAufbauen: false);
      widget.onGeaendert();
      zeigeMeldung(context, 'Fassung ${d.eintrag.aktuell.nr} gespeichert');
    } on ApiFehler catch (f) {
      if (!mounted) return;
      if (f.code != 'konflikt') {
        zeigeMeldung(context, f.text, fehler: true);
        return;
      }
      setState(() => _beschaeftigt = false);
      final trotzdemSpeichern = await _bestaetige(
        'Jemand war schneller',
        '${f.text}\n\nWenn du trotzdem speicherst, wird deine Fassung die aktuelle. Die andere bleibt im Verlauf erhalten.',
        'Trotzdem speichern',
      );
      if (trotzdemSpeichern && mounted) await _sende(e, trotzdem: true);
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  Future<bool> _bestaetige(String titel, String text, String knopf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titel),
        content: SizedBox(width: 420, child: Text(text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(knopf)),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Warum gerade kein Approval geht; `null` = es geht.
  String? _approvalGesperrt(List<Befund> befunde) {
    final e = _eintrag!;
    if (!widget.person.darfFreigeben) return 'Nur das Didaktik-Team gibt Approvals';
    if (e.status == 'zurueckgezogen') return 'Erst wieder aufnehmen';
    if (e.status == 'live' && !e.hatKorrektur) return 'Diese Fassung ist schon freigegeben';
    if (_geaendert) return 'Erst speichern';
    if (befunde.any((b) => b.istFehler)) return 'Erst die Fehler beheben';
    if (e.aktuell.approvals.any((a) => a.person == widget.person.id)) {
      return 'Das zweite Approval muss von einer anderen Person kommen';
    }
    return null;
  }

  Future<void> _approval() async {
    final e = _eintrag;
    if (e == null || _approvalGesperrt(_befunde) != null) return;
    final d = await _aktion(() => widget.api.approval(_id, e.aktuell.nr));
    if (d == null || !mounted) return;
    _uebernimm(d.eintrag, neuAufbauen: false);
    widget.onGeaendert();
    zeigeMeldung(
      context,
      d.eintrag.status == 'live' && !d.eintrag.hatKorrektur ? 'Aufgabe ist live' : 'Approval gegeben',
    );
    if (_weiterNachApproval && _position + 1 < widget.reihenfolge.length) await _gehe(1);
  }

  Future<void> _zurueckziehen() async {
    final grund = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Aufgabe zurückziehen?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sie verschwindet sofort aus der App. Gelöscht wird nichts. Zurück kommt sie nur mit zwei neuen Approvals.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: grund,
                decoration: const InputDecoration(hintText: 'Grund (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: fehlerRot),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Zurückziehen'),
          ),
        ],
      ),
    );
    final text = grund.text.trim();
    grund.dispose();
    if (ok != true) return;
    final d = await _aktion(() => widget.api.zurueckziehen(_id, text.isEmpty ? null : text));
    if (d != null && mounted) {
      _uebernimm(d.eintrag);
      widget.onGeaendert();
    }
  }

  Future<void> _wiederaufnehmen() async {
    final d = await _aktion(() => widget.api.wiederaufnehmen(_id));
    if (d != null && mounted) {
      _uebernimm(d.eintrag);
      widget.onGeaendert();
    }
  }

  Future<void> _verlauf() async {
    final e = _eintrag!;
    final nr = await showDialog<int>(
      context: context,
      builder: (_) => VerlaufDialog(eintrag: e, personName: _personName),
    );
    if (nr == null || !mounted || !await _darfVerlassen()) return;
    final d = await _aktion(() => widget.api.wiederherstellen(_id, nr));
    if (d != null && mounted) {
      _uebernimm(d.eintrag);
      widget.onGeaendert();
      zeigeMeldung(context, 'Fassung $nr als Fassung ${d.eintrag.aktuell.nr} wiederhergestellt');
    }
  }

  String _personName(String? id) {
    if (id == null) return 'Startbestand';
    return switch (id) {
      'didaktik-a' => 'Test-Didaktik A',
      'didaktik-b' => 'Test-Didaktik B',
      'admin' => 'Test-Admin',
      _ => id,
    };
  }

  List<Befund> get _befunde => pruefeAufgabe(_inhalt, kontext: widget.stamm.kontext);

  void _springe(String pfad) {
    final m = RegExp(r'^items/(\d+)').firstMatch(pfad);
    if (m != null) setState(() => _offeneItems.add(int.parse(m.group(1)!)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ziel = _ziele[pfad]?.currentContext;
      if (ziel != null) Scrollable.ensureVisible(ziel, duration: const Duration(milliseconds: 200), alignment: 0.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = _eintrag;
    final Widget koerper;
    if (e == null) {
      koerper = Center(
        child: _ladeFehler == null
            ? const CircularProgressIndicator()
            : Text(_ladeFehler!, style: const TextStyle(color: fehlerRot)),
      );
    } else {
      final befunde = _befunde;
      koerper = EditorScope(
        befunde: befunde,
        ziele: _ziele,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _speichere,
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): _speichere,
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): _approval,
            const SingleActivator(LogicalKeyboardKey.enter, control: true): _approval,
            const SingleActivator(LogicalKeyboardKey.period, control: true): () => _gehe(1),
            const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _gehe(-1),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                _kopf(e, befunde),
                const Divider(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final inhalt = KeyedSubtree(key: ValueKey('$_id-$_ladeZaehler'), child: _spalten(befunde));
                      if (c.maxWidth >= 1100) return inhalt;
                      return Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: 1100, height: c.maxHeight, child: inhalt),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: e == null || !_geaendert,
      onPopInvokedWithResult: (hatGepoppt, _) async {
        if (hatGepoppt) return;
        final nav = Navigator.of(context);
        if (await _darfVerlassen()) {
          setState(() => _gespeichert = jsonEncode(_inhalt));
          WidgetsBinding.instance.addPostFrameCallback((_) => nav.pop());
        }
      },
      child: Material(color: flaeche, child: koerper),
    );
  }

  Widget _kopf(Eintrag e, List<Befund> befunde) {
    final gesperrt = _approvalGesperrt(befunde);
    final approvals = e.aktuell.approvals;
    final korrektur = e.hatKorrektur;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          IconButton(
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          SelectableText(
            _id,
            style: const TextStyle(fontFamily: monoSchrift, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          StatusPlakette(e.status, korrektur: korrektur, approvals: approvals.length),
          Tooltip(
            message: approvals.isEmpty
                ? 'Noch keine Approvals auf dieser Fassung'
                : approvals.map((a) => _personName(a.person)).join(', '),
            child: Text('Approvals ${approvals.length}/2', style: Theme.of(context).textTheme.bodySmall),
          ),
          Text('Fassung ${e.aktuell.nr}', style: Theme.of(context).textTheme.bodySmall),
          if (_geaendert)
            const Text(
              'Nicht gespeichert',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hinweisGelb),
            ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Cmd/Strg + S',
            child: FilledButton(
              key: const ValueKey('speichern'),
              onPressed: _geaendert && _jsonUngueltig.isEmpty && !_beschaeftigt ? _speichere : null,
              child: const Text('Speichern'),
            ),
          ),
          Tooltip(
            message: gesperrt ?? 'Cmd/Strg + Enter',
            child: FilledButton(
              key: const ValueKey('approval'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B6B32)),
              onPressed: gesperrt == null && !_beschaeftigt ? _approval : null,
              child: const Text('Approval geben'),
            ),
          ),
          if (e.status == 'live')
            OutlinedButton(
              key: const ValueKey('zurueckziehen'),
              style: OutlinedButton.styleFrom(foregroundColor: fehlerRot),
              onPressed: _beschaeftigt ? null : _zurueckziehen,
              child: const Text('Zurückziehen'),
            ),
          if (e.status == 'zurueckgezogen')
            OutlinedButton(
              key: const ValueKey('wiederaufnehmen'),
              onPressed: _beschaeftigt ? null : _wiederaufnehmen,
              child: const Text('Wieder aufnehmen'),
            ),
          OutlinedButton(key: const ValueKey('verlauf'), onPressed: _verlauf, child: const Text('Verlauf')),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Vorherige Aufgabe (Strg + ,)',
            child: IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: _position > 0 ? () => _gehe(-1) : null,
            ),
          ),
          Text(
            _position >= 0 ? '${_position + 1} / ${widget.reihenfolge.length}' : '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Tooltip(
            message: 'Nächste Aufgabe (Strg + .)',
            child: IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: _position >= 0 && _position + 1 < widget.reihenfolge.length ? () => _gehe(1) : null,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(value: _weiterNachApproval, onChanged: (v) => setState(() => _weiterNachApproval = v ?? false)),
              Text('Nach Approval zur nächsten', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spalten(List<Befund> befunde) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 300, child: _aufgabeSpalte(befunde)),
      const VerticalDivider(width: 1, color: linie),
      // Die Vorschau scrollt nie; sie passt sich der Höhe an.
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Center(child: HandyVorschau(inhalt: _inhalt)),
        ),
      ),
      const VerticalDivider(width: 1, color: linie),
      SizedBox(width: 380, child: _itemSpalte()),
    ],
  );

  // --- Felder ---

  Widget _feld(FeldDef def, Map<String, dynamic> ziel, String pfad, {List<SuchOption> optionen = const []}) {
    final wert = ziel[def.key];
    void setze(Object? v) => setState(() => ziel[def.key] = v);
    final Widget eingabe = switch (def.art) {
      FeldArt.nurLesbar => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectableText(
          wert == null ? 'wird von der App berechnet' : '$wert',
          style: const TextStyle(fontFamily: monoSchrift, fontSize: 12, color: grauText),
        ),
      ),
      FeldArt.dropdown => WahlFeld(
        wert: wert,
        werte: def.werte,
        pflicht: def.pflicht,
        leer: def.key == 'unterwegs' || def.key == 'lernpfad_geeignet' ? 'automatisch' : '–',
        onChanged: setze,
      ),
      FeldArt.suche => SuchFeld(
        titel: def.label,
        werte: wert is List ? wert.cast<String>() : (wert == null ? const [] : ['$wert']),
        optionen: optionen,
        mehrfach: def.mehrfach,
        frei: def.key == 'kompetenz' || def.key == 'kompetenz_sekundaer',
        onChanged: (l) => setze(def.mehrfach ? l : (l.isEmpty ? null : l.first)),
      ),
      FeldArt.beispiel => TextEingabe(
        wert: wert == null ? '' : '$wert',
        hint: def.beispiel,
        onChanged: (v) {
          final t = v.trim();
          setze(t.isEmpty ? null : (def.key == 'erwartete_sekunden' ? (int.tryParse(t) ?? t) : t));
        },
      ),
      FeldArt.text => TextEingabe(
        wert: def.mehrfach && wert is List ? wert.join('\n') : (wert == null ? '' : '$wert'),
        mehrzeilig: def.mehrzeilig,
        hint: def.mehrfach ? 'Ein Schritt pro Zeile' : null,
        onChanged: (v) => setze(def.mehrfach ? v.split('\n').where((s) => s.trim().isNotEmpty).toList() : v),
      ),
      FeldArt.formular => JsonFeld(
        wert: wert,
        hint: '[ ]',
        onGueltig: (ok) => setState(() => ok ? _jsonUngueltig.remove(pfad) : _jsonUngueltig.add(pfad)),
        onChanged: (v) => setze(v ?? <dynamic>[]),
      ),
    };
    return FeldRahmen(label: def.label, pfad: pfad, pflicht: def.pflicht, hilfe: def.key, child: eingabe);
  }

  FeldDef _def(List<FeldDef> liste, String key) => liste.firstWhere((f) => f.key == key);

  Widget _aufgabeSpalte(List<Befund> befunde) {
    final fehler = befunde.where((b) => b.istFehler).toList();
    final hinweise = befunde.where((b) => !b.istFehler).toList();
    const komplex = {'externe_referenzen', 'medien', 'loesung_medien', 'parameter', 'teilaufgaben'};
    final felder = ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('Aufgabe', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final def in aufgabeFelder)
          if (def.key != 'status' && !komplex.contains(def.key))
            _feld(
              def,
              _inhalt,
              def.key,
              optionen: switch (def.key) {
                'level' => [for (final l in widget.stamm.levels) SuchOption(l['id'] as String, l['titel'] as String?)],
                'matura_thema' => [
                  for (final t in widget.stamm.maturaThemen) SuchOption(t['id'] as String, t['titel'] as String?),
                ],
                _ => const [],
              },
            ),
        if (_inhalt['verwendung'] != null)
          FeldRahmen(
            label: 'Verwendung',
            pfad: 'verwendung',
            child: Text(
              '${_inhalt['verwendung']}',
              style: const TextStyle(fontFamily: monoSchrift, fontSize: 12, color: grauText),
            ),
          ),
        ExpansionTile(
          title: Text('Weitere Felder als JSON', style: Theme.of(context).textTheme.labelMedium),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 4),
          initiallyExpanded: befunde.any((b) => komplex.contains(b.pfad)),
          children: [
            for (final def in aufgabeFelder)
              if (komplex.contains(def.key)) _feld(def, _inhalt, def.key),
          ],
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: felder),
        const Divider(),
        Container(
          key: const ValueKey('fehlerliste'),
          constraints: const BoxConstraints(maxHeight: 170),
          padding: const EdgeInsets.all(10),
          color: fehler.isEmpty ? const Color(0xFFE2F3E6) : const Color(0xFFFBE6E4),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fehler.isEmpty ? 'Keine Fehler' : '${fehler.length} Fehler',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fehler.isEmpty ? const Color(0xFF1B6B32) : fehlerRot,
                  ),
                ),
                for (final b in [...fehler, ...hinweise])
                  InkWell(
                    onTap: () => _springe(b.pfad),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_ortText(b.pfad)}${b.text}',
                        style: TextStyle(
                          fontSize: 12,
                          color: b.istFehler ? fehlerRot : hinweisGelb,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _ortText(String pfad) {
    final m = RegExp(r'^items/(\d+)').firstMatch(pfad);
    return m == null ? '' : 'Item ${int.parse(m.group(1)!) + 1}: ';
  }

  // --- Items ---

  List<dynamic> get _items {
    final v = _inhalt['items'];
    if (v is List) return v;
    return _inhalt['items'] = <dynamic>[];
  }

  void _itemHinzu() {
    final vergeben = <String>{
      for (final f in _eintrag!.fassungen)
        for (final i in alleItems(f.inhalt)) i['item_id'] as String,
      for (final i in alleItems(_inhalt)) i['item_id'] as String,
    };
    var n = _items.length + 1;
    while (vergeben.contains('$_id-i$n')) {
      n++;
    }
    setState(() {
      _items.add(leeresItem('$_id-i$n'));
      _offeneItems.add(_items.length - 1);
    });
  }

  Future<void> _itemWeg(int i) async {
    final iid = (_items[i] as Map)['item_id'];
    final ok = await _bestaetige(
      'Item entfernen?',
      'Item ${i + 1} ($iid) wird aus dieser Fassung entfernt.',
      'Entfernen',
    );
    if (!ok) return;
    setState(() {
      _items.removeAt(i);
      _offeneItems
        ..clear()
        ..add(0);
      _ladeZaehler++; // Felder gehören nach dem Entfernen zu anderen Items
    });
  }

  /// Antworten bleiben beim Wechsel stehen. Zwischen Ankreuzformaten ändert sich
  /// nichts; passt die Zahl nicht, meldet das die Prüfung. Zu anderen Formaten
  /// wandert die Antwort in einen Merkspeicher, damit sie beim Zurückwechseln
  /// wieder da ist.
  void _formatWechsel(Map<String, dynamic> item, Object? neu) {
    final alt = item['antwortformat'];
    if (neu is! String || neu == alt) return;
    String familie(Object? f) => ankreuzFormate.containsKey(f) ? 'ankreuzen' : '$f';
    final antwort = item['antwort'] is Map<String, dynamic>
        ? item['antwort'] as Map<String, dynamic>
        : <String, dynamic>{};
    setState(() {
      if (familie(alt) == familie(neu)) {
        item['antwort'] = antwortFuerFormat(neu, antwort);
      } else {
        final merk = _antwortMerk.putIfAbsent('${item['item_id']}', () => {});
        merk[familie(alt)] = {'antwort': antwort, 'fehlerbilder': item['fehlerbilder'] ?? <String, dynamic>{}};
        final frueher = merk[familie(neu)];
        item['antwort'] = antwortFuerFormat(neu, frueher?['antwort'] ?? antwort);
        item['fehlerbilder'] = frueher?['fehlerbilder'] ?? <String, dynamic>{};
      }
      item['antwortformat'] = neu;
      _ladeZaehler++;
    });
  }

  Widget _itemSpalte() {
    final items = _items;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Expanded(child: Text('Items', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              key: const ValueKey('item-hinzu'),
              onPressed: _itemHinzu,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Item hinzufügen'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (items.isEmpty) Text('Noch keine Items.', style: Theme.of(context).textTheme.bodySmall),
        for (var i = 0; i < items.length; i++)
          if (items[i] is Map<String, dynamic>) _itemKarte(i, items[i] as Map<String, dynamic>, items),
      ],
    );
  }

  Widget _itemKarte(int i, Map<String, dynamic> item, List<dynamic> items) {
    final offen = _offeneItems.contains(i);
    final fruehere = [
      for (var k = 0; k < i; k++)
        if (items[k] is Map)
          SuchOption(
            '${(items[k] as Map)['item_id']}',
            'Item ${k + 1}: ${(items[k] as Map)['aufgabenstellung'] ?? ''}',
          ),
    ];
    final abhaengig = item['abhaengig_von'];
    final vonNr = abhaengig == null ? -1 : items.indexWhere((x) => x is Map && x['item_id'] == abhaengig);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: linie),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => offen ? _offeneItems.remove(i) : _offeneItems.add(i)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
              child: Row(
                children: [
                  Icon(offen ? Icons.expand_more : Icons.chevron_right, size: 18),
                  const SizedBox(width: 4),
                  Text('Item ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (abhaengig != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.link, size: 15, color: tutoBlau),
                    const SizedBox(width: 2),
                    Text(
                      vonNr >= 0 ? 'hängt von Item ${vonNr + 1} ab' : 'hängt von $abhaengig ab',
                      style: const TextStyle(fontSize: 12, color: tutoBlau),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Item entfernen',
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: () => _itemWeg(i),
                  ),
                ],
              ),
            ),
          ),
          if (offen) Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 4), child: _itemFelder(i, item, fruehere)),
        ],
      ),
    );
  }

  Widget _itemFelder(int i, Map<String, dynamic> item, List<SuchOption> fruehere) {
    final pfad = 'items/$i';
    final format = item['antwortformat'];
    final kompetenzen = [for (final k in widget.stamm.kompetenzen) SuchOption(k)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final def in itemFelder)
          ...switch (def.key) {
            'operator' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/operator',
                pflicht: true,
                hilfe: 'operator',
                child: WahlFeld(
                  wert: item['operator'],
                  werte: operatorenFuer(item['handlungsbereich'] as String?),
                  pflicht: true,
                  onChanged: (v) => setState(() => item['operator'] = v),
                ),
              ),
            ],
            'antwortformat' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/antwortformat',
                pflicht: true,
                hilfe: 'antwortformat',
                child: WahlFeld(
                  wert: format,
                  werte: def.werte,
                  pflicht: true,
                  onChanged: (v) => _formatWechsel(item, v),
                ),
              ),
            ],
            'antwort' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/antwort',
                pflicht: true,
                hilfe: 'antwort',
                child: AntwortFormular(
                  key: ValueKey('$pfad/antwort/$format'),
                  format: '${format ?? ''}',
                  antwort: item['antwort'] is Map<String, dynamic>
                      ? item['antwort'] as Map<String, dynamic>
                      : (item['antwort'] = <String, dynamic>{}),
                  fehlerbilder: item['fehlerbilder'] is Map<String, dynamic>
                      ? item['fehlerbilder'] as Map<String, dynamic>
                      : const {},
                  vorschlaege: widget.stamm.fehlerbilder,
                  onAendern: (f) => setState(() => f(item['antwort'] as Map<String, dynamic>)),
                  onFehlerbilder: (f) => setState(() {
                    if (item['fehlerbilder'] is! Map<String, dynamic>) item['fehlerbilder'] = <String, dynamic>{};
                    f(item['fehlerbilder'] as Map<String, dynamic>);
                  }),
                  onJsonGueltig: (ok) =>
                      setState(() => ok ? _jsonUngueltig.remove('$pfad/antwort') : _jsonUngueltig.add('$pfad/antwort')),
                  onNeuAufbauen: () => setState(() => _ladeZaehler++),
                ),
              ),
            ],
            'hilfen' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/hilfen',
                pflicht: true,
                hilfe: 'Hilfen',
                child: HilfenFormular(
                  hilfen: item['hilfen'] is List ? item['hilfen'] as List : const [],
                  onAendern: (f) => setState(() {
                    final l = [
                      for (final h in (item['hilfen'] is List ? item['hilfen'] as List : const []))
                        if (h is Map<String, dynamic>) h,
                    ];
                    f(l);
                    item['hilfen'] = l;
                  }),
                ),
              ),
            ],
            // Fehlerbilder stehen direkt bei den falschen Antworten; hier nur Befunde und Hilfe.
            'fehlerbilder' => [
              FeldRahmen(
                label: 'Fehlerbilder',
                pfad: '$pfad/fehlerbilder',
                hilfe: 'fehlerbilder',
                child: Text('Stehen oben bei den falschen Antworten.', style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            'halbpunkt_regel' => [
              if (item['punkteschema'] == '0/½/1' || item['halbpunkt_regel'] != null)
                _feld(def, item, '$pfad/${def.key}'),
            ],
            'punkteschema' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/punkteschema',
                pflicht: true,
                hilfe: 'punkteschema',
                child: WahlFeld(
                  wert: item['punkteschema'],
                  werte: def.werte,
                  pflicht: true,
                  onChanged: (v) => setState(() {
                    item['punkteschema'] = v;
                    if (v != '0/½/1') item['halbpunkt_regel'] = null;
                  }),
                ),
              ),
            ],
            'abhaengig_von' => [
              FeldRahmen(
                label: def.label,
                pfad: '$pfad/abhaengig_von',
                hilfe: 'abhaengig_von',
                child: SuchFeld(
                  titel: def.label,
                  werte: item['abhaengig_von'] == null ? const [] : ['${item['abhaengig_von']}'],
                  optionen: fruehere,
                  hint: fruehere.isEmpty ? 'Kein früheres Item' : 'Keine Abhängigkeit',
                  onChanged: (l) => setState(() {
                    item['abhaengig_von'] = l.isEmpty ? null : l.first;
                    if (l.isEmpty) item['folgefehler'] = null;
                  }),
                ),
              ),
            ],
            'folgefehler' => [
              if (item['abhaengig_von'] != null || item['folgefehler'] != null) _feld(def, item, '$pfad/${def.key}'),
            ],
            'kompetenz' || 'kompetenz_sekundaer' => [_feld(def, item, '$pfad/${def.key}', optionen: kompetenzen)],
            _ => [_feld(_def(itemFelder, def.key), item, '$pfad/${def.key}')],
          },
      ],
    );
  }
}
