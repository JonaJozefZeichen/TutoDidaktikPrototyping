import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/lehre/bausteine.dart';
import 'package:tuto_didaktik/lehre/store_seite.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/thema.dart';

/// Merkliste: Ordner links, gemerkte Aufgaben rechts; darunter die
/// gespeicherten Suchen. Ordner und Suchen dienen dem Generator als Quelle.
class MerklisteSeite extends StatefulWidget {
  const MerklisteSeite({super.key, required this.zustand, required this.aktionen, required this.onSucheZeigen});

  final LehreZustand zustand;
  final LehreAktionen aktionen;
  final void Function(StoreFilter) onSucheZeigen;

  @override
  State<MerklisteSeite> createState() => _MerklisteSeiteState();
}

class _MerklisteSeiteState extends State<MerklisteSeite> {
  String _ordner = standardOrdner;

  LehreZustand get z => widget.zustand;

  Future<void> _melde(Future<String?> f, [String? ok]) async {
    final fehler = await f;
    if (!mounted) return;
    if (fehler != null) {
      await zeigeMeldung(context, fehler, fehler: true);
    } else if (ok != null) {
      await zeigeMeldung(context, ok);
    }
  }

  Future<void> _neuerOrdner() async {
    final name = await frageText(context, titel: 'Neuer Ordner', hinweis: 'z. B. Schularbeit 2');
    if (name != null) await _melde(z.neuerOrdner(name));
  }

  Future<void> _umbenennen(MerkOrdner o) async {
    final name = await frageText(context, titel: 'Ordner umbenennen', start: o.name);
    if (name != null) await _melde(z.aendere((d) => d.ordnerMit(o.id)?.name = name));
  }

  Future<void> _loeschen(MerkOrdner o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('„${o.name}“ löschen?'),
        content: const Text('Die Aufgaben bleiben im Store, nur der Ordner verschwindet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _ordner = standardOrdner);
    await _melde(z.aendere((d) => d.ordner.removeWhere((x) => x.id == o.id)));
  }

  /// Neues Paket, das der Generator aus diesem Ordner füllt.
  Future<void> _alsQuelle(MerkOrdner o) async {
    final p = z.neuesPaket(titel: o.name)..quelle = 'ordner:${o.id}';
    final fehler = await z.speicherePaket(p);
    if (!mounted) return;
    if (fehler != null) {
      await zeigeMeldung(context, fehler, fehler: true);
    } else {
      widget.aktionen.oeffnePaket(p.id);
    }
  }

  /// Neues Paket mit genau den Aufgaben des Ordners.
  Future<void> _alsPaket(MerkOrdner o) async {
    final p = z.neuesPaket(titel: o.name);
    for (final id in o.aufgaben) {
      final a = z.nachId[id];
      if (a != null) p.plaetze.add(PaketPlatz.von(a));
    }
    final fehler = await z.speicherePaket(p);
    if (!mounted) return;
    if (fehler != null) {
      await zeigeMeldung(context, fehler, fehler: true);
    } else {
      widget.aktionen.oeffnePaket(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: z,
      builder: (context, _) {
        final o = z.daten.ordnerMit(_ordner) ?? z.daten.ordnerMit(standardOrdner)!;
        final text = Theme.of(context).textTheme;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.white,
              child: Container(
                width: 260,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: linie)),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('Ordner', style: text.labelMedium)),
                          IconButton(
                            key: const ValueKey('neuer-ordner'),
                            tooltip: 'Neuer Ordner',
                            onPressed: _neuerOrdner,
                            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                          ),
                        ],
                      ),
                    ),
                    for (final x in z.daten.ordner)
                      ListTile(
                        key: ValueKey('ordner-${x.id}'),
                        dense: true,
                        selected: x.id == o.id,
                        leading: Icon(x.id == standardOrdner ? Icons.favorite_border : Icons.folder_outlined, size: 20),
                        title: Text(x.name),
                        trailing: Text('${x.aufgaben.length}'),
                        onTap: () => setState(() => _ordner = x.id),
                      ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('Gespeicherte Suchen', style: text.labelMedium),
                    ),
                    if (z.daten.suchen.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Im Store mit „Suche speichern“ anlegen.', style: text.bodySmall),
                      ),
                    for (final s in z.daten.suchen)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.bookmark_outline, size: 20),
                        title: Text(s.name),
                        subtitle: Text('${s.filter.treffer(z.aufgaben, varianten: z.varianten).length} Treffer'),
                        onTap: () => widget.onSucheZeigen(s.filter.kopie()),
                        trailing: IconButton(
                          tooltip: 'Suche löschen',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _melde(z.aendere((d) => d.suchen.removeWhere((x) => x.id == s.id))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${o.name} · ${o.aufgaben.length} Aufgaben', style: text.titleLarge),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('ordner-als-paket'),
                          onPressed: o.aufgaben.isEmpty ? null : () => _alsPaket(o),
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: const Text('Als Paket übernehmen'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('ordner-als-quelle'),
                          onPressed: o.aufgaben.isEmpty ? null : () => _alsQuelle(o),
                          icon: const Icon(Icons.casino_outlined, size: 18),
                          label: const Text('Generator daraus wählen lassen'),
                        ),
                        if (o.id != standardOrdner) ...[
                          TextButton(onPressed: () => _umbenennen(o), child: const Text('Umbenennen')),
                          TextButton(onPressed: () => _loeschen(o), child: const Text('Löschen')),
                        ],
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: o.aufgaben.isEmpty
                        ? Center(
                            child: Text(
                              'Noch nichts gemerkt. Im Store mit dem Herz merken, über den Pfeil daneben in einen Ordner.',
                              style: text.bodySmall,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 360,
                              mainAxisExtent: 236,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: o.aufgaben.length,
                            itemBuilder: (_, i) {
                              final a = z.nachId[o.aufgaben[i]];
                              if (a == null) {
                                return Card(
                                  child: ListTile(
                                    title: Text(o.aufgaben[i]),
                                    subtitle: const Text('Nicht mehr verfügbar (zurückgezogen)'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => _melde(z.entmerken(o.aufgaben[i], ordner: o.id)),
                                    ),
                                  ),
                                );
                              }
                              return AufgabenKarte(
                                zustand: z,
                                aufgabe: a,
                                onOeffnen: () => widget.aktionen.oeffneAufgabe(a.id),
                                onInsPaket: () async {
                                  final (p, f) = await z.insPaket(a.id);
                                  if (context.mounted) {
                                    await zeigeMeldung(context, f ?? 'In „${p.titel}“ gelegt', fehler: f != null);
                                  }
                                },
                                imPaket: z.paket(z.offenesPaket)?.plaetze.any((p) => p.aufgabe == a.id) ?? false,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Alle Pakete der Lehrperson.
class PaketeSeite extends StatelessWidget {
  const PaketeSeite({super.key, required this.zustand, required this.aktionen});

  final LehreZustand zustand;
  final LehreAktionen aktionen;

  Future<void> _neu(BuildContext context, {required bool generieren}) async {
    final p = zustand.neuesPaket(titel: generieren ? 'Generiertes Paket' : 'Neues Paket');
    final f = await zustand.speicherePaket(p);
    if (!context.mounted) return;
    if (f != null) {
      await zeigeMeldung(context, f, fehler: true);
      return;
    }
    aktionen.oeffnePaket(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: zustand,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Aufgabenpakete', style: text.titleLarge),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('paket-generieren'),
                onPressed: () => _neu(context, generieren: true),
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Paket generieren'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('paket-leer'),
                onPressed: () => _neu(context, generieren: false),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Leer starten (per Hand)'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Generieren würfelt passende Aufgaben, einzelne Plätze lassen sich sperren und neu würfeln. '
            'Per Hand kommen die Aufgaben aus Merkliste oder Store.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          if (zustand.daten.pakete.isEmpty)
            Text('Noch keine Pakete.', style: text.bodySmall)
          else
            for (final p in zustand.daten.pakete)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: linie),
                ),
                child: ListTile(
                  key: ValueKey('paket-${p.id}'),
                  leading: const Icon(Icons.inventory_2_outlined, color: tutoBlau),
                  title: Text(p.titel),
                  subtitle: Text(
                    [
                      '${p.plaetze.length} Aufgaben',
                      minutenText(zustand.minuten(p.plaetze.map((x) => x.aufgabe))),
                      if (p.gruppen > 1) '${p.gruppen} Gruppen',
                      if (p.foerderung != null) 'Förderpaket',
                      if (p.zuweisungen.isNotEmpty)
                        'zugewiesen: ${p.zuweisungen.map((z) => _klassenName(z.klasse)).join(', ')}',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Paket löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final f = await zustand.loeschePaket(p.id);
                      if (f != null && context.mounted) await zeigeMeldung(context, f, fehler: true);
                    },
                  ),
                  onTap: () => aktionen.oeffnePaket(p.id),
                ),
              ),
        ],
      ),
    );
  }

  String _klassenName(String id) => zustand.klassen.where((k) => k.id == id).firstOrNull?.name ?? id;
}
