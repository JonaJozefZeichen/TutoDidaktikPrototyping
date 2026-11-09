import 'dart:math';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/foundation.dart';

import 'package:tuto_didaktik/api.dart';

/// Gemeinsamer Stand des Bereichs für Lehrende: Aufgaben im Store, Stammdaten
/// und die eigene Ablage (Merkliste, Suchen, Pakete). Jede Änderung an der
/// Ablage geht sofort an den Server; bei einem Fehler wird neu geladen.
class LehreZustand extends ChangeNotifier {
  LehreZustand({required this.api, required this.person});

  final Api api;
  final Person person;

  List<StoreAufgabe> aufgaben = const [];
  Map<String, StoreAufgabe> nachId = const {};
  Map<String, int> varianten = const {};
  Stammdaten? stamm;
  LehrDaten daten = LehrDaten();
  List<TestKlasse> klassen = const [];
  String? fehler;
  bool laedt = true;

  /// Teststand: auch noch nicht freigegebene Aufgaben zeigen, sonst wäre der
  /// Store leer, solange niemand etwas freigegeben hat.
  bool auchUnfreigegebene = true;

  /// Paket, in das "+ ins Paket" legt (wie ein Warenkorb).
  String? offenesPaket;

  Map<String, String> levelTitel = const {};

  Future<void> laden() async {
    laedt = true;
    notifyListeners();
    try {
      final s = await api.stammdaten();
      final a = await api.storeAufgaben(auchUnfreigegebene: auchUnfreigegebene);
      final d = await api.lehrDaten();
      stamm = s;
      _setzeAufgaben(a);
      daten = d;
      levelTitel = {for (final l in s.levels) l['id'] as String: '${l['titel'] ?? ''}'};
      klassen = testKlassen(person.id, _kompetenzenProLernwelt(s));
      fehler = null;
    } on ApiFehler catch (e) {
      fehler = e.text;
    }
    laedt = false;
    notifyListeners();
  }

  void _setzeAufgaben(List<StoreAufgabe> a) {
    aufgaben = a;
    nachId = {for (final x in a) x.id: x};
    varianten = variantenZahlen(a);
  }

  Map<int, List<String>> _kompetenzenProLernwelt(Stammdaten s) {
    final m = <int, Set<String>>{};
    for (final l in s.levels) {
      final w = l['lernwelt'];
      if (w is! int) continue;
      m.putIfAbsent(w, () => {}).addAll(((l['kompetenzen'] as List?) ?? const []).whereType<String>());
    }
    return {for (final e in m.entries) e.key: (e.value.toList()..sort())};
  }

  Future<void> setzeAuchUnfreigegebene(bool wert) async {
    auchUnfreigegebene = wert;
    await laden();
  }

  /// Schreibt die Ablage nach einer Änderung von [aendern].
  Future<String?> aendere(void Function(LehrDaten d) aendern) async {
    final kopie = LehrDaten.fromJson(daten.toJson());
    aendern(kopie);
    daten = kopie;
    notifyListeners();
    try {
      daten = await api.speichereLehrDaten(kopie);
      notifyListeners();
      return null;
    } on ApiFehler catch (e) {
      try {
        daten = await api.lehrDaten();
      } on ApiFehler {
        // Bleibt beim lokalen Stand; die Meldung unten reicht.
      }
      notifyListeners();
      return e.text;
    }
  }

  // --- Merkliste ---

  bool istGemerkt(String id) => daten.gemerkt.contains(id);

  List<MerkOrdner> ordnerVon(String id) => [
    for (final o in daten.ordner)
      if (o.aufgaben.contains(id)) o,
  ];

  Future<String?> merken(String id, {String ordner = standardOrdner}) => aendere((d) {
    final o = d.ordnerMit(ordner) ?? d.ordnerMit(standardOrdner)!;
    if (!o.aufgaben.contains(id)) o.aufgaben.add(id);
  });

  Future<String?> entmerken(String id, {String? ordner}) => aendere((d) {
    for (final o in d.ordner) {
      if (ordner == null || o.id == ordner) o.aufgaben.remove(id);
    }
  });

  Future<String?> neuerOrdner(String name, {String? mitAufgabe}) => aendere((d) {
    d.ordner.add(MerkOrdner(id: neueId('ordner'), name: name.trim(), aufgaben: [?mitAufgabe]));
  });

  // --- Pakete ---

  Paket? paket(String? id) {
    for (final p in daten.pakete) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<String?> speicherePaket(Paket p) => aendere((d) {
    final i = d.pakete.indexWhere((x) => x.id == p.id);
    final kopie = Paket.fromJson(p.toJson());
    if (i < 0) {
      d.pakete.insert(0, kopie);
    } else {
      d.pakete[i] = kopie;
    }
  });

  Future<String?> loeschePaket(String id) {
    if (offenesPaket == id) offenesPaket = null;
    return aendere((d) => d.pakete.removeWhere((p) => p.id == id));
  }

  Paket neuesPaket({String titel = 'Neues Paket'}) =>
      Paket(id: neueId('paket'), titel: titel, erstellt: DateTime.now());

  /// "+ ins Paket": legt [id] in das offene Paket, sonst in ein neues.
  Future<(Paket, String?)> insPaket(String id) async {
    var p = paket(offenesPaket);
    if (p == null) {
      p = neuesPaket();
      offenesPaket = p.id;
    } else {
      p = Paket.fromJson(p.toJson());
    }
    final a = nachId[id];
    if (a != null && !p.plaetze.any((x) => x.aufgabe == id)) p.plaetze.add(PaketPlatz.von(a));
    final f = await speicherePaket(p);
    return (p, f);
  }

  /// Gesamtdauer eines Pakets in Minuten.
  double minuten(Iterable<String> ids) => ids.fold(0, (s, id) => s + (nachId[id]?.minuten ?? 0));

  /// Aufgaben, aus denen der Generator für [p] wählt.
  List<StoreAufgabe> generatorPool(Paket p) {
    var basis = aufgaben;
    if (p.quelle.startsWith('ordner:')) {
      final o = daten.ordnerMit(p.quelle.substring(7));
      basis = [for (final id in o?.aufgaben ?? const <String>[]) ?nachId[id]];
    } else if (p.quelle.startsWith('suche:')) {
      final id = p.quelle.substring(6);
      final s = daten.suchen.where((x) => x.id == id).firstOrNull;
      if (s != null) basis = s.filter.treffer(aufgaben, varianten: varianten);
    }
    return p.filter.treffer(basis, varianten: varianten);
  }

  String quelleName(String quelle) {
    if (quelle.startsWith('ordner:')) {
      return 'Merkliste: ${daten.ordnerMit(quelle.substring(7))?.name ?? 'gelöschter Ordner'}';
    }
    if (quelle.startsWith('suche:')) {
      final s = daten.suchen.where((x) => x.id == quelle.substring(6)).firstOrNull;
      return 'Gespeicherte Suche: ${s?.name ?? 'gelöscht'}';
    }
    return 'Alle Aufgaben';
  }

  // --- Anzeige ---

  String kompetenzName(String key) => key;

  String levelName(String id) {
    final t = levelTitel[id];
    return t == null || t.isEmpty ? id : '$id $t';
  }

  static final _zufall = Random();

  /// Erzeugt neue IDs; Tests setzen eine feste Folge.
  static String Function(String art) idErzeuger = (art) =>
      '$art-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_zufall.nextInt(1 << 20).toRadixString(36)}';
  static String neueId(String art) => idErzeuger(art);
}

/// Weist [p] den [personen] der Klasse [k] zu, abwechselnd auf die Gruppen
/// verteilt, und gibt die Meldung für die Oberfläche zurück. Im Teststand
/// wird nichts verschickt.
String weiseZu(Paket p, TestKlasse k, List<String> personen) {
  final verteilung = verteileGruppen(personen, p.gruppen);
  p.zuweisungen.removeWhere((x) => x.klasse == k.id);
  p.zuweisungen.add(Zuweisung(klasse: k.id, am: DateTime.now(), verteilung: verteilung));
  final zahlen = [
    for (final g in gruppenNamenBis(p.gruppen)) '$g: ${verteilung.values.where((x) => x == g).length}',
  ].join(', ');
  final wer = personen.length == k.schueler.length ? k.name : '${personen.length} Personen der ${k.name}';
  return 'An $wer zugewiesen ($zahlen). Im Test wird nichts verschickt.';
}
