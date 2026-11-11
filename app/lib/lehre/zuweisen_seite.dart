import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

String datumText(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Klassen zum Aufklappen wie eine Ordneransicht: pro Klasse ein Häkchen für
/// alle, darunter einzelne Personen. Auswahl über mehrere Klassen möglich.
class KlassenBaum extends StatefulWidget {
  const KlassenBaum({super.key, required this.klassen, required this.auswahl, required this.onChanged});

  final List<TestKlasse> klassen;

  /// Klasse → gewählte Personen.
  final Map<String, Set<String>> auswahl;
  final VoidCallback onChanged;

  @override
  State<KlassenBaum> createState() => _KlassenBaumState();
}

class _KlassenBaumState extends State<KlassenBaum> {
  late final _offen = <String>{
    for (final e in widget.auswahl.entries)
      if (e.value.isNotEmpty) e.key,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in widget.klassen) ...[
          _klasse(k, text),
          if (_offen.contains(k.id))
            for (final s in k.schueler)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: InkWell(
                  key: ValueKey('baum-person-${s.id}'),
                  onTap: () => _umschalten(k, s.id),
                  child: Row(
                    children: [
                      Checkbox(
                        value: widget.auswahl[k.id]?.contains(s.id) ?? false,
                        onChanged: (_) => _umschalten(k, s.id),
                      ),
                      Expanded(child: Text(s.name)),
                      Text(s.gesamt, style: text.bodySmall),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _klasse(TestKlasse k, TextTheme text) {
    final gewaehlt = widget.auswahl[k.id]?.length ?? 0;
    final wert = gewaehlt == 0 ? false : (gewaehlt == k.schueler.length ? true : null);
    return InkWell(
      key: ValueKey('baum-klasse-${k.id}'),
      onTap: () => setState(() => _offen.contains(k.id) ? _offen.remove(k.id) : _offen.add(k.id)),
      child: Row(
        children: [
          Icon(_offen.contains(k.id) ? Icons.expand_more : Icons.chevron_right, color: grauText),
          Checkbox(
            key: ValueKey('baum-alle-${k.id}'),
            tristate: true,
            value: wert,
            onChanged: (_) {
              setState(() {
                if (wert == true) {
                  widget.auswahl.remove(k.id);
                } else {
                  widget.auswahl[k.id] = {for (final s in k.schueler) s.id};
                }
              });
              widget.onChanged();
            },
          ),
          const Icon(Icons.groups_outlined, size: 18, color: grauText),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${k.name} · ${k.lernwelt}. Klasse', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('$gewaehlt von ${k.schueler.length}', style: text.bodySmall),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _umschalten(TestKlasse k, String id) {
    setState(() {
      final s = widget.auswahl.putIfAbsent(k.id, () => {});
      if (!s.remove(id)) s.add(id);
      if (s.isEmpty) widget.auswahl.remove(k.id);
    });
    widget.onChanged();
  }
}

/// Zentrale Zuweisen-Ansicht: Paket, Empfänger\*innen aus einer oder mehreren
/// Klassen, Gruppen und Abgabedatum wählen, dann überprüfen und senden.
class ZuweisenSeite extends StatefulWidget {
  const ZuweisenSeite({super.key, required this.zustand, this.paketId, this.auswahl});

  final LehreZustand zustand;
  final String? paketId;

  /// Vorauswahl (z. B. alle Personen einer Klasse); sonst die vorgesehenen
  /// Empfänger\*innen des Pakets.
  final Map<String, Set<String>>? auswahl;

  @override
  State<ZuweisenSeite> createState() => _ZuweisenSeiteState();
}

class _ZuweisenSeiteState extends State<ZuweisenSeite> {
  String? _paketId;
  Map<String, Set<String>> _auswahl = {};
  int _gruppen = 1;
  DateTime? _abgabe;
  bool _pruefen = false;
  int _baumSchluessel = 0;

  LehreZustand get z => widget.zustand;
  Paket? get _paket => z.paket(_paketId);

  @override
  void initState() {
    super.initState();
    _waehle(widget.paketId, widget.auswahl);
  }

  void _waehle(String? id, [Map<String, Set<String>>? vor]) {
    _paketId = id;
    final p = z.paket(id);
    _gruppen = p?.gruppen ?? 1;
    if (vor != null) {
      _auswahl = {
        for (final e in vor.entries) e.key: {...e.value},
      };
    } else if (p != null && p.empfaenger.isNotEmpty) {
      _auswahl = {
        for (final e in p.empfaenger.entries) e.key: {...e.value},
      };
    } else if (p?.foerderung case final f?) {
      _auswahl = {
        f.klasse: {...f.schueler},
      };
    } else if (vor == null && p != null) {
      _auswahl = {};
    }
    _baumSchluessel++;
  }

  int get _anzahl => _auswahl.values.fold(0, (n, s) => n + s.length);

  /// Empfänger\*innen in der Reihenfolge der Klassenliste.
  Map<String, List<String>> get _empfaenger => {
    for (final k in z.klassen)
      if (_auswahl[k.id]?.isNotEmpty ?? false)
        k.id: [
          for (final s in k.schueler)
            if (_auswahl[k.id]!.contains(s.id)) s.id,
        ],
  };

  Future<void> _datum() async {
    final heute = LehreZustand.uhr();
    final d = await showDatePicker(
      context: context,
      initialDate: _abgabe ?? heute.add(const Duration(days: 7)),
      firstDate: DateTime(heute.year, heute.month, heute.day),
      lastDate: heute.add(const Duration(days: 365)),
      helpText: 'Abgabe bis',
    );
    if (d != null) setState(() => _abgabe = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _senden() async {
    final original = _paket;
    if (original == null) return;
    final p = Paket.fromJson(original.toJson());
    if (_gruppen > 1 && (p.gruppen != _gruppen || p.gruppenPlaetze.length != _gruppen - 1)) {
      p.gruppenPlaetze
        ..clear()
        ..addAll(bildeGruppen(p.plaetze, _gruppen, z.nachId));
    }
    final empfaenger = _empfaenger;
    p.empfaenger
      ..clear()
      ..addAll(empfaenger);
    versende(p, empfaenger, gruppen: _gruppen, abgabe: _abgabe, jetzt: LehreZustand.uhr());
    final fehler = await z.speicherePaket(p);
    if (!mounted) return;
    if (fehler != null) {
      await zeigeMeldung(context, fehler, fehler: true);
      return;
    }
    await zeigeMeldung(
      context,
      '„${p.anzeigeName()}“ an ${empfaenger.values.fold(0, (n, l) => n + l.length)} Personen verschickt. '
      'Im Test wird nichts verschickt.',
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _paket;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('zuweisen-zurueck'),
                tooltip: 'Zurück',
                onPressed: () => _pruefen ? setState(() => _pruefen = false) : Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Text(_pruefen ? 'Überprüfen und senden' : 'Paket zuweisen', style: text.titleMedium),
            ],
          ),
        ),
        const Divider(),
        Expanded(child: _pruefen && p != null ? _uebersicht(context, p) : _auswahlAnsicht(context, p)),
      ],
    );
  }

  Widget _auswahlAnsicht(BuildContext context, Paket? p) {
    final text = Theme.of(context).textTheme;
    final pakete = [
      for (final x in z.daten.pakete)
        if (x.plaetze.isNotEmpty) x,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Paket', style: text.labelMedium),
              DropdownButton<String>(
                key: const ValueKey('zuweisen-paket'),
                isExpanded: true,
                value: pakete.any((x) => x.id == _paketId) ? _paketId : null,
                hint: const Text('Paket wählen'),
                items: [
                  for (final x in pakete)
                    DropdownMenuItem(
                      value: x.id,
                      child: Text(
                        '${x.anzeigeName()} · ${x.plaetze.length} Aufgaben${x.foerderung != null ? ' · Förderpaket' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(() => _waehle(id, widget.auswahl)),
              ),
              if (p != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${p.plaetze.length} Aufgaben · ${minutenText(z.minuten(p.plaetze.map((x) => x.aufgabe)))}'
                  '${p.code == null ? '' : ' · Code ${p.code}'}',
                  style: text.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              Text('Gruppen', style: text.labelMedium),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('zuweisen-gruppen-weniger'),
                    onPressed: _gruppen > 1 ? () => setState(() => _gruppen--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    _gruppen == 1 ? '1 Gruppe' : '$_gruppen Gruppen',
                    key: const ValueKey('zuweisen-gruppen'),
                    style: text.titleMedium,
                  ),
                  IconButton(
                    key: const ValueKey('zuweisen-gruppen-mehr'),
                    onPressed: _gruppen < maxGruppen ? () => setState(() => _gruppen++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      gruppenNamenBis(_gruppen).join(' · '),
                      style: text.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Abgabe bis', style: text.labelMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('zuweisen-datum'),
                    onPressed: _datum,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_abgabe == null ? 'Kein Abgabedatum' : datumText(_abgabe!)),
                  ),
                  if (_abgabe != null)
                    TextButton(onPressed: () => setState(() => _abgabe = null), child: const Text('Entfernen')),
                ],
              ),
              const SizedBox(height: 4),
              Text('Nach dem Abgabedatum bringen die Aufgaben keine Punkte mehr.', style: text.bodySmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('zuweisen-pruefen'),
                onPressed: p == null || _anzahl == 0 ? null : () => setState(() => _pruefen = true),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Überprüfen ($_anzahl ${_anzahl == 1 ? 'Person' : 'Personen'})'),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: linie),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('An wen?', style: text.titleMedium),
              Text('Ganze Klassen oder einzelne Personen, auch aus mehreren Klassen.', style: text.bodySmall),
              const SizedBox(height: 8),
              KlassenBaum(
                key: ValueKey('baum-$_baumSchluessel'),
                klassen: z.klassen,
                auswahl: _auswahl,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _uebersicht(BuildContext context, Paket p) {
    final text = Theme.of(context).textTheme;
    final empfaenger = _empfaenger;
    final schon = schonVerschickt(p, empfaenger);
    final version = naechsteVersion(p);
    final namen = {
      for (final k in z.klassen)
        for (final s in k.schueler) s.id: s.name,
    };
    String zeile(String k, String v) => '$k: $v';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(p.anzeigeName(version), style: text.titleLarge),
        const SizedBox(height: 8),
        for (final t in [
          zeile('Aufgaben', '${p.plaetze.length} (${minutenText(z.minuten(p.plaetze.map((x) => x.aufgabe)))})'),
          zeile(
            'Gruppen',
            _gruppen == 1 ? '1 (alle bekommen dieselben Aufgaben)' : gruppenNamenBis(_gruppen).join(', '),
          ),
          zeile('Abgabe bis', _abgabe == null ? 'kein Datum' : datumText(_abgabe!)),
          zeile('Empfänger*innen', '$_anzahl'),
          if (p.version > 0)
            zeile('Version', version == p.version ? '$version (unverändert)' : '$version (Aufgaben geändert)'),
        ])
          Text(t),
        if (schon.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('zuweisen-warnung'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF1CC), borderRadius: BorderRadius.circular(14)),
            child: Text(
              '${schon.length} ${schon.length == 1 ? 'Person hat' : 'Personen haben'} genau diese Aufgaben schon bekommen: '
              '${schon.map((s) => namen[s] ?? s).join(', ')}. Trotzdem senden?',
              style: const TextStyle(color: hinweisGelb, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final e in empfaenger.entries) ...[
          Text(
            '${z.klassen.where((k) => k.id == e.key).firstOrNull?.name ?? e.key} (${e.value.length})',
            style: text.titleMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (s, g) in [for (final x in verteileGruppen(e.value, _gruppen).entries) (x.key, x.value)])
                Chip(
                  label: Text(_gruppen > 1 ? '${namen[s] ?? s} · $g' : namen[s] ?? s),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(onPressed: () => setState(() => _pruefen = false), child: const Text('Ändern')),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('zuweisen-senden'),
              onPressed: _senden,
              icon: const Icon(Icons.send_outlined),
              label: Text(schon.isEmpty ? 'Senden' : 'Trotzdem senden'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Eine Zuweisung an eine Klasse: wer das Paket bekommen hat und wer schon
/// fertig ist. Ein Klick auf eine fertige Person zeigt ihre Antworten.
class ZuweisungSeite extends StatefulWidget {
  const ZuweisungSeite({
    super.key,
    required this.zustand,
    required this.paket,
    required this.zuweisung,
    required this.klasse,
    required this.onPerson,
  });

  final LehreZustand zustand;
  final Paket paket;
  final Zuweisung zuweisung;
  final TestKlasse klasse;
  final void Function(TestSchuelerin person, String gruppe) onPerson;

  @override
  State<ZuweisungSeite> createState() => _ZuweisungSeiteState();
}

class _ZuweisungSeiteState extends State<ZuweisungSeite> {
  TestKlasse get klasse => widget.klasse;
  Paket get paket => widget.paket;
  Zuweisung get zuweisung => widget.zuweisung;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: widget.zustand, builder: (context, _) => _inhalt(context));

  Widget _inhalt(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final jetzt = LehreZustand.uhr();
    final personen = [
      for (final s in klasse.schueler)
        if (zuweisung.verteilung.containsKey(s.id)) s,
    ];
    final stand = {for (final s in personen) s.id: abgabeStand(s.id, zuweisung, widget.zustand.daten.abgaben, jetzt)};
    final fertig = stand.values.where((x) => x.fertig).length;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('zuweisung-zurueck'),
                tooltip: 'Zurück',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${paket.anzeigeName(zuweisung.version)} · ${klasse.name}',
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$fertig von ${personen.length} fertig', key: const ValueKey('zuweisung-stand')),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: const Color(0xFFFFF1CC),
          child: Text(
            'Verschickt am ${datumText(zuweisung.am)} · '
            '${zuweisung.abgabe == null ? 'ohne Abgabedatum' : 'Abgabe bis ${datumText(zuweisung.abgabe!)}'} · '
            '${zuweisung.gruppen == 1 ? 'alle dieselben Aufgaben' : '${zuweisung.gruppen} Gruppen'} · Testklasse',
            style: const TextStyle(fontSize: 12, color: hinweisGelb, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final s in personen)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: linie),
                  ),
                  child: ListTile(
                    key: ValueKey('zuweisung-person-${s.id}'),
                    title: Text(s.name),
                    subtitle: zuweisung.gruppen > 1 ? Text('Gruppe ${zuweisung.verteilung[s.id]}') : null,
                    trailing: _status(stand[s.id]!),
                    onTap: stand[s.id]!.fertig ? () => widget.onPerson(s, zuweisung.verteilung[s.id]!) : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _status(({bool fertig, DateTime? am, bool zuSpaet}) x) {
    if (x.fertig) {
      return Marke(
        x.zuSpaet ? 'fertig am ${datumText(x.am!)}, zu spät' : 'fertig am ${datumText(x.am!)}',
        farbe: x.zuSpaet ? hinweisGelb : const Color(0xFF1B6B32),
        grund: x.zuSpaet ? const Color(0xFFFFF1CC) : const Color(0xFFE2F3E6),
      );
    }
    return x.zuSpaet
        ? const Marke('nicht abgegeben', farbe: fehlerRot, grund: Color(0xFFFBE6E4))
        : const Marke('offen');
  }
}
