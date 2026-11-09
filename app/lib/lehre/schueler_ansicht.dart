import 'dart:math';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/lehre/klassen_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/lehre/zuweisen_seite.dart';
import 'package:tuto_didaktik/thema.dart';
import 'package:tuto_didaktik/vorschau/design_system_controller.dart';
import 'package:tuto_didaktik/vorschau/widgets/antwort_eingabe.dart';

/// Schüler\*innen-Ansicht: ein Handy wie in der App, angemeldet mit einem
/// Testkonto der Testklasse. Die Lehrperson sieht, wie Pakete ankommen, und
/// löst sie selbst; die Antworten landen als echte Versuche in der Klasse.
/// Die Gamification ist hier aus, die Insel ist nur ein 2D-Bild.
class SchuelerAnsicht extends StatefulWidget {
  const SchuelerAnsicht({super.key, required this.zustand});

  final LehreZustand zustand;

  @override
  State<SchuelerAnsicht> createState() => _SchuelerAnsichtState();
}

enum _Bildschirm { insel, postfach, loesen, fertig }

class _SchuelerAnsichtState extends State<SchuelerAnsicht> {
  late String _konto = widget.zustand.klassen.first.schueler.first.id;
  _Bildschirm _bildschirm = _Bildschirm.insel;

  // Laufendes Paket
  Paket? _paket;
  Zuweisung? _zuweisung;
  String _gruppe = 'A';
  List<({String aufgabe, Map<String, dynamic> inhalt, Item item})> _items = const [];
  int _index = 0;
  Object? _antwort;
  String _antwortText = '';
  CheckResult? _ergebnis;
  int _hilfen = 0;
  final _uhr = Stopwatch();
  final _versuche = <SchuelerVersuch>[];

  LehreZustand get z => widget.zustand;
  TestKlasse get _klasse => z.klassen.first;

  /// Pakete dieses Kontos, neueste zuerst.
  List<(Paket, Zuweisung)> get _post => [
    for (final p in z.daten.pakete)
      for (final w in p.zuweisungen)
        if (w.verteilung.containsKey(_konto)) (p, w),
  ]..sort((a, b) => b.$2.am.compareTo(a.$2.am));

  bool _erledigt(Zuweisung w) => abgabeStand(_konto, w, z.daten.abgaben, LehreZustand.uhr()).fertig;

  void _starte(Paket p, Zuweisung w) {
    final gruppe = w.verteilung[_konto] ?? 'A';
    final g = gruppe.codeUnitAt(0) - 65;
    final ids = aufgabenDerGruppe(p, gruppe);
    final items = <({String aufgabe, Map<String, dynamic> inhalt, Item item})>[];
    for (var i = 0; i < ids.length; i++) {
      final a = z.nachId[ids[i]];
      if (a == null) continue;
      final inhalt = g > 0 && p.antwortenMischen ? mischeAntworten(a.inhalt, g * 7919 + i) : a.inhalt;
      final geladen = ladeZurVorschau(inhalt).aufgabe;
      for (final it in geladen?.items ?? const <Item>[]) {
        items.add((aufgabe: a.id, inhalt: inhalt, item: it));
      }
    }
    setState(() {
      _paket = p;
      _zuweisung = w;
      _gruppe = gruppe;
      _items = items;
      _index = 0;
      _versuche.clear();
      _bildschirm = _Bildschirm.loesen;
      _neuesItem();
    });
  }

  void _neuesItem() {
    _antwort = null;
    _antwortText = '';
    _ergebnis = null;
    _hilfen = 0;
    _uhr
      ..reset()
      ..start();
  }

  void _pruefe({bool weissNicht = false}) {
    final x = _items[_index];
    final r = weissNicht ? const CheckResult(0) : const AnswerChecker().check(x.item, _antwort);
    _uhr.stop();
    setState(() {
      _ergebnis = r;
      _versuche.add(
        SchuelerVersuch(
          konto: _konto,
          paket: _paket!.id,
          zuweisung: _zuweisung!.id,
          aufgabe: x.aufgabe,
          itemId: x.item.id,
          antwort: weissNicht ? '' : _antwortText,
          r: r.r.toDouble(),
          fehlerbild: r.fehlerbild,
          hilfen: _hilfen,
          sekunden: max(1, _uhr.elapsed.inSeconds),
          am: LehreZustand.uhr(),
          selbstBewertet: !x.item.automatischGeprueft && !weissNicht,
        ),
      );
    });
  }

  Future<void> _weiter() async {
    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
        _neuesItem();
      });
      return;
    }
    final f = await z.speichereVersuche([..._versuche]);
    final g = f ?? await z.gibAb(_konto, _zuweisung!.id);
    if (!mounted) return;
    if (g != null) {
      await zeigeMeldung(context, g, fehler: true);
      return;
    }
    setState(() => _bildschirm = _Bildschirm.fertig);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: z,
      builder: (context, _) => Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('ansicht-zurueck'),
                  tooltip: 'Zurück',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Schüler*innen-Ansicht · Testklasse', style: text.titleMedium),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final skala = (c.maxHeight / 720).clamp(0.55, 1.0);
                      return SizedBox(
                        width: 390 * skala,
                        height: 720 * skala,
                        child: FittedBox(child: _handy(context)),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  SizedBox(width: 320, child: _seitenleiste(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seitenleiste(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        Text('Angemeldet als', style: text.labelMedium),
        const SizedBox(height: 4),
        for (final s in _klasse.schueler)
          ListTile(
            key: ValueKey('konto-${s.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            selected: s.id == _konto,
            leading: Icon(s.id == _konto ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(s.name),
            subtitle: Text(_offenText(_postFuer(s.id)), style: text.bodySmall),
            onTap: () => setState(() {
              _konto = s.id;
              _bildschirm = _Bildschirm.insel;
            }),
          ),
        const SizedBox(height: 12),
        Text(
          'So sehen Lernende Tuto am Handy. Zugewiesene Pakete kommen ins Postfach auf der Insel. '
          'Was du hier löst, erscheint in der Testklasse als Antworten und Lernstand.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Die Gamification ist in der Testansicht aus: Die Insel ist nur ein Bild, es gibt keine Punkte, '
          'keinen Baum und keine Gebäude.',
          style: text.bodySmall,
        ),
        if (_bildschirm == _Bildschirm.loesen && _zuweisung != null) ...[
          const SizedBox(height: 12),
          Text('Gruppe $_gruppe · Aufgabe ${_index + 1} von ${_items.length}', style: text.labelMedium),
        ],
      ],
    );
  }

  String _offenText(int n) => n == 1 ? '1 offenes Paket' : '$n offene Pakete';

  int _postFuer(String konto) => [
    for (final p in z.daten.pakete)
      for (final w in p.zuweisungen)
        if (w.verteilung.containsKey(konto) && !abgabeStand(konto, w, z.daten.abgaben, LehreZustand.uhr()).fertig) w,
  ].length;

  Widget _handy(BuildContext context) {
    final tokens = context.designSystem;
    return Container(
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
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: const Size(372, 702), padding: EdgeInsets.zero),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: tokens.backgroundGradient),
            child: Material(
              type: MaterialType.transparency,
              child: switch (_bildschirm) {
                _Bildschirm.insel => _insel(context),
                _Bildschirm.postfach => _postfach(context),
                _Bildschirm.loesen => _loesen(context),
                _Bildschirm.fertig => _fertig(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _kopf(BuildContext context, String titel, {VoidCallback? zurueck}) {
    final tokens = context.designSystem;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
      child: Row(
        children: [
          if (zurueck != null) IconButton(onPressed: zurueck, icon: const Icon(Icons.arrow_back)),
          if (zurueck == null) const SizedBox(width: 10),
          Expanded(child: Text(titel, style: tokens.heading(size: 20))),
        ],
      ),
    );
  }

  Widget _insel(BuildContext context) {
    final tokens = context.designSystem;
    final offen = _postFuer(_konto);
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _TestInsel())),
        Positioned(
          left: 18,
          top: 22,
          right: 18,
          child: Row(
            children: [
              Expanded(child: Text(_klasse.schueler.firstWhere((s) => s.id == _konto).name, style: tokens.label())),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Test-Insel · Gamification aus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 28,
          child: Badge(
            isLabelVisible: offen > 0,
            label: Text('$offen'),
            child: FloatingActionButton.extended(
              key: const ValueKey('postfach'),
              heroTag: null,
              onPressed: () => setState(() => _bildschirm = _Bildschirm.postfach),
              icon: const Icon(Icons.markunread_mailbox_outlined),
              label: const Text('Post'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _postfach(BuildContext context) {
    final tokens = context.designSystem;
    final post = _post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kopf(context, 'Post', zurueck: () => setState(() => _bildschirm = _Bildschirm.insel)),
        Expanded(
          child: post.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Noch keine Pakete. Weise im Lehrbereich ein Paket der Testklasse zu.',
                      style: tokens.body(size: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final (p, w) in post)
                      Card(
                        child: ListTile(
                          key: ValueKey('post-${w.id}'),
                          title: Text(p.anzeigeName(w.version)),
                          subtitle: Text(
                            [
                              '${p.plaetze.length} Aufgaben',
                              if (w.abgabe != null) 'bis ${datumText(w.abgabe!)}',
                              if (_erledigt(w)) 'erledigt',
                            ].join(' · '),
                          ),
                          trailing: _erledigt(w) ? const Icon(Icons.check_circle, color: Color(0xFF1B6B32)) : null,
                          onTap: _erledigt(w) ? null : () => _starte(p, w),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _loesen(BuildContext context) {
    final tokens = context.designSystem;
    if (_items.isEmpty) {
      return Column(
        children: [
          _kopf(context, _paket?.titel ?? '', zurueck: () => setState(() => _bildschirm = _Bildschirm.postfach)),
          const Expanded(child: Center(child: Text('Dieses Paket hat keine Aufgaben.'))),
        ],
      );
    }
    final x = _items[_index];
    final item = x.item;
    final geladen = ladeZurVorschau(x.inhalt).aufgabe;
    final r = _ergebnis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kopf(
          context,
          '${_index + 1}/${_items.length}',
          zurueck: () => setState(() => _bildschirm = _Bildschirm.postfach),
        ),
        LinearProgressIndicator(value: (_index + (r == null ? 0 : 1)) / _items.length, minHeight: 3),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            children: [
              Text(geladen?.titel ?? '', style: tokens.label()),
              const SizedBox(height: 10),
              if ((geladen?.stamm ?? '').isNotEmpty) ...[
                Text(geladen!.stamm, style: tokens.body()),
                const SizedBox(height: 10),
              ],
              Text(item.aufgabenstellung, style: tokens.heading(size: 19)),
              const SizedBox(height: 12),
              AntwortEingabe(
                key: ValueKey('eingabe-$_index-${item.id}'),
                item: item,
                enabled: r == null,
                onChanged: (a, t) => setState(() {
                  _antwort = a;
                  _antwortText = t;
                }),
              ),
              for (final h in item.hilfen.take(_hilfen))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Hilfe ${h.stufe}: ${h.text}', style: tokens.body(size: 14)),
                ),
              if (r != null) ...[
                const SizedBox(height: 12),
                Text(
                  !item.automatischGeprueft && _antwortText.isNotEmpty
                      ? 'Vergleiche mit der Lösung: ${loesungAlsText(item)}'
                      : r.richtig
                      ? 'Richtig!'
                      : 'Leider nicht. Lösung: ${loesungAlsText(item)}',
                  key: const ValueKey('rueckmeldung'),
                  style: tokens.body(size: 15, weight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
          child: r == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('pruefen'),
                      onPressed: _antwortText.isEmpty && _antwort == null ? null : () => _pruefe(),
                      child: Text(item.automatischGeprueft ? 'Prüfen' : 'Fertig'),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          key: const ValueKey('weiss-nicht'),
                          onPressed: () => _pruefe(weissNicht: true),
                          child: const Text('Weiß ich nicht'),
                        ),
                        if (_hilfen < item.hilfen.length)
                          TextButton(onPressed: () => setState(() => _hilfen++), child: const Text('Hilfe')),
                      ],
                    ),
                  ],
                )
              : FilledButton(
                  key: const ValueKey('weiter'),
                  onPressed: _weiter,
                  child: Text(_index + 1 < _items.length ? 'Weiter' : 'Abgeben'),
                ),
        ),
      ],
    );
  }

  Widget _fertig(BuildContext context) {
    final tokens = context.designSystem;
    final richtig = _versuche.where((v) => v.richtig).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kopf(context, 'Abgegeben'),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 56, color: Color(0xFF1B6B32)),
                  const SizedBox(height: 12),
                  Text(
                    '$richtig von ${_versuche.length} richtig',
                    key: const ValueKey('abgabe-ergebnis'),
                    style: tokens.heading(size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Die Lehrperson sieht jetzt deine Antworten. (In der echten App gäbe es hier Punkte.)',
                    style: tokens.body(size: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: FilledButton(
            key: const ValueKey('zur-insel'),
            onPressed: () => setState(() => _bildschirm = _Bildschirm.insel),
            child: const Text('Zur Insel'),
          ),
        ),
      ],
    );
  }
}

/// Die Test-Insel als einfaches 2D-Bild: Meer, Sandstrand, Wiese, ein Baum.
class _TestInsel extends CustomPainter {
  const _TestInsel();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE3F8), Color(0xFF5DA9D9)],
        ).createShader(Offset.zero & size),
    );
    final mitte = Offset(w / 2, h * 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: mitte, width: w * 0.86, height: h * 0.34),
      Paint()..color = const Color(0xFFF1DDA6),
    );
    canvas.drawOval(
      Rect.fromCenter(center: mitte.translate(0, -8), width: w * 0.72, height: h * 0.26),
      Paint()..color = const Color(0xFF8CC56A),
    );
    final stamm = Rect.fromCenter(center: mitte.translate(0, -50), width: 16, height: 70);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stamm, const Radius.circular(4)),
      Paint()..color = const Color(0xFF8A5A36),
    );
    final krone = Paint()..color = const Color(0xFF3F8F4A);
    for (final o in [const Offset(0, -100), const Offset(-26, -84), const Offset(26, -84)]) {
      canvas.drawCircle(mitte + o, 34, krone);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
