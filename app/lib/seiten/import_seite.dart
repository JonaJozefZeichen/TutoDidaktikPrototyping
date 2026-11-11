import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/thema.dart';

/// JSON-Datei importieren und den Bericht ansehen.
class ImportSeite extends StatefulWidget {
  const ImportSeite({super.key, required this.api, required this.onFertig, required this.onZuDenEntwuerfen});

  final Api api;
  final VoidCallback onFertig;
  final VoidCallback onZuDenEntwuerfen;

  @override
  State<ImportSeite> createState() => _ImportSeiteState();
}

class _ImportSeiteState extends State<ImportSeite> {
  final _text = TextEditingController();
  Map<String, dynamic>? _bericht;
  String? _fehler;
  bool _laeuft = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _waehleDatei() async {
    final auswahl = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = auswahl?.files.single.bytes;
    if (bytes == null) return;
    await _sende(utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _sende(String json) async {
    setState(() {
      _laeuft = true;
      _fehler = null;
      _bericht = null;
    });
    try {
      final b = await widget.api.importiere(json);
      if (!mounted) return;
      setState(() => _bericht = b);
      widget.onFertig();
    } on ApiFehler catch (e) {
      if (mounted) setState(() => _fehler = e.text);
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = _bericht;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Import', style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Format wie in "Aufgaben Struktur": ein Objekt mit "quelle" und "aufgaben". Alles startet als Entwurf, bestehende IDs bleiben unberührt.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _laeuft ? null : _waehleDatei,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('JSON-Datei wählen'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Oder JSON hier einfügen', style: text.labelMedium),
        const SizedBox(height: 4),
        TextField(
          key: const ValueKey('import-text'),
          controller: _text,
          minLines: 5,
          maxLines: 10,
          style: const TextStyle(fontFamily: codeSchrift, fontSize: 12),
          decoration: const InputDecoration(hintText: '{ "quelle": "…", "aufgaben": [ … ] }'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _laeuft ? null : () => _sende(_text.text),
            child: const Text('Eingefügtes JSON importieren'),
          ),
        ),
        const SizedBox(height: 16),
        if (_laeuft) const LinearProgressIndicator(),
        if (_fehler != null) Text(_fehler!, style: const TextStyle(color: fehlerRot)),
        if (b != null) _Bericht(bericht: b, onZuDenEntwuerfen: widget.onZuDenEntwuerfen),
      ],
    );
  }
}

class _Bericht extends StatelessWidget {
  const _Bericht({required this.bericht, required this.onZuDenEntwuerfen});

  final Map<String, dynamic> bericht;
  final VoidCallback onZuDenEntwuerfen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final neu = (bericht['uebernommen'] as List).cast<Map<String, dynamic>>();
    final konflikte = (bericht['konflikte'] as List).cast<String>();
    final abgelehnt = (bericht['abgelehnt'] as List).cast<Map<String, dynamic>>();
    final mitFehlern = neu.where((n) => (n['fehler'] as int) > 0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bericht${bericht['quelle'] != null ? ': ${bericht['quelle']}' : ''}', style: text.titleMedium),
          const SizedBox(height: 8),
          Text('${neu.length} übernommen, davon ${mitFehlern.length} mit Fehlern'),
          Text('${konflikte.length} nicht übernommen, weil die ID schon existiert'),
          Text('${abgelehnt.length} abgelehnt'),
          if (mitFehlern.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Mit Fehlern', style: text.labelMedium),
            for (final n in mitFehlern.take(50)) Text('${n['id']}: ${n['fehler']} Fehler', style: text.bodySmall),
          ],
          if (konflikte.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('ID existiert schon', style: text.labelMedium),
            Text(konflikte.take(50).join(', '), style: text.bodySmall),
          ],
          if (abgelehnt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Abgelehnt', style: text.labelMedium),
            for (final a in abgelehnt.take(50)) Text('${a['wo']}: ${a['grund']}', style: text.bodySmall),
          ],
          if (neu.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onZuDenEntwuerfen, child: const Text('Zu den Entwürfen')),
          ],
        ],
      ),
    );
  }
}
