/// Aufgabenpakete der Lehrpersonen: Plätze, Generator mit Sperren und
/// Neu-Würfeln, Gruppen A/B/C gegen Abschreiben.
library;

import 'dart:convert';
import 'dart:math';

import 'package:didaktik_kern/src/lehre/filter.dart';
import 'package:didaktik_kern/src/lehre/store.dart';
import 'package:didaktik_kern/src/pruefung.dart';

/// Ein Platz im Paket. Die Fassung wird mitgespeichert, damit eine spätere
/// Korrektur ein schon verteiltes Paket nicht still verändert.
class PaketPlatz {
  PaketPlatz({required this.aufgabe, required this.fassung, this.gesperrt = false});

  factory PaketPlatz.von(StoreAufgabe a, {bool gesperrt = false}) =>
      PaketPlatz(aufgabe: a.id, fassung: a.fassung, gesperrt: gesperrt);

  factory PaketPlatz.fromJson(Map<String, dynamic> j) =>
      PaketPlatz(aufgabe: j['aufgabe'] as String, fassung: j['fassung'] as int? ?? 1, gesperrt: j['gesperrt'] == true);

  final String aufgabe;
  final int fassung;
  bool gesperrt;

  Map<String, dynamic> toJson() => {'aufgabe': aufgabe, 'fassung': fassung, 'gesperrt': gesperrt};
}

/// Woher eine Aufgabe der Gruppe B oder C kommt.
enum GruppenArt {
  original('Original'),
  variante('Variante'),
  parameter('Andere Zahlen'),
  ersatz('Ersatz'),
  ersatzTyp('Ersatz, anderer Typ'),
  fehlt('Kein Ersatz gefunden');

  const GruppenArt(this.bezeichnung);
  final String bezeichnung;
}

class GruppenPlatz {
  const GruppenPlatz({this.aufgabe, this.fassung, required this.art, this.seed});

  factory GruppenPlatz.fromJson(Map<String, dynamic> j) => GruppenPlatz(
    aufgabe: j['aufgabe'] as String?,
    fassung: j['fassung'] as int?,
    art: GruppenArt.values.asNameMap()[j['art']] ?? GruppenArt.fehlt,
    seed: j['seed'] as int?,
  );

  final String? aufgabe;
  final int? fassung;
  final GruppenArt art;

  /// Bei parametrisierten Aufgaben: Seed für andere Zahlen.
  final int? seed;

  Map<String, dynamic> toJson() => {'aufgabe': aufgabe, 'fassung': fassung, 'art': art.name, 'seed': seed};
}

class GeneratorEinstellung {
  GeneratorEinstellung({this.anzahl = 5, this.zielMinuten, this.aufsteigend = true, this.formateMischen = true});

  factory GeneratorEinstellung.fromJson(Map<String, dynamic> j) => GeneratorEinstellung(
    anzahl: j['anzahl'] as int? ?? 5,
    zielMinuten: j['ziel_minuten'] as int?,
    aufsteigend: j['aufsteigend'] != false,
    formateMischen: j['formate_mischen'] != false,
  );

  /// Zahl der Aufgaben; gilt, wenn [zielMinuten] fehlt.
  int anzahl;

  /// Gesamtdauer in Minuten; das Paket wird so lange gefüllt, bis sie erreicht ist.
  int? zielMinuten;

  /// Leichte Aufgaben zuerst, wie im Level (Grundlage → Anwendung → Transfer).
  bool aufsteigend;

  /// Verschiedene Aufgabentypen bevorzugen.
  bool formateMischen;

  Map<String, dynamic> toJson() => {
    'anzahl': anzahl,
    'ziel_minuten': zielMinuten,
    'aufsteigend': aufsteigend,
    'formate_mischen': formateMischen,
  };
}

class Zuweisung {
  Zuweisung({required this.klasse, required this.am, required this.verteilung});

  factory Zuweisung.fromJson(Map<String, dynamic> j) => Zuweisung(
    klasse: j['klasse'] as String,
    am: DateTime.parse(j['am'] as String),
    verteilung: {...((j['verteilung'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'))},
  );

  final String klasse;
  final DateTime am;

  /// Schüler\*in → Gruppe (`A`, `B`, `C`).
  final Map<String, String> verteilung;

  Map<String, dynamic> toJson() => {'klasse': klasse, 'am': am.toIso8601String(), 'verteilung': verteilung};
}

const gruppenNamen = ['A', 'B', 'C'];

class Paket {
  Paket({
    required this.id,
    required this.titel,
    required this.erstellt,
    List<PaketPlatz>? plaetze,
    this.gruppen = 1,
    Map<String, List<GruppenPlatz>>? gruppenPlaetze,
    this.antwortenMischen = true,
    GeneratorEinstellung? einstellung,
    this.quelle = 'alle',
    StoreFilter? filter,
    List<Zuweisung>? zuweisungen,
  }) : plaetze = plaetze ?? [],
       filter = filter ?? StoreFilter(),
       gruppenPlaetze = gruppenPlaetze ?? {},
       einstellung = einstellung ?? GeneratorEinstellung(),
       zuweisungen = zuweisungen ?? [];

  factory Paket.fromJson(Map<String, dynamic> j) => Paket(
    id: j['id'] as String,
    titel: j['titel'] as String? ?? 'Paket',
    erstellt: DateTime.parse(j['erstellt'] as String),
    plaetze: [for (final p in (j['plaetze'] as List?) ?? const []) PaketPlatz.fromJson(p as Map<String, dynamic>)],
    gruppen: (j['gruppen'] as int? ?? 1).clamp(1, 3),
    gruppenPlaetze: {
      for (final e in ((j['gruppen_plaetze'] as Map?) ?? const {}).entries)
        '${e.key}': [for (final g in e.value as List) GruppenPlatz.fromJson(g as Map<String, dynamic>)],
    },
    antwortenMischen: j['antworten_mischen'] != false,
    einstellung: j['einstellung'] is Map<String, dynamic>
        ? GeneratorEinstellung.fromJson(j['einstellung'] as Map<String, dynamic>)
        : null,
    quelle: j['quelle'] as String? ?? 'alle',
    filter: j['filter'] is Map<String, dynamic> ? StoreFilter.fromJson(j['filter'] as Map<String, dynamic>) : null,
    zuweisungen: [
      for (final z in (j['zuweisungen'] as List?) ?? const []) Zuweisung.fromJson(z as Map<String, dynamic>),
    ],
  );

  final String id;
  String titel;
  final DateTime erstellt;
  final List<PaketPlatz> plaetze;

  /// 1 = nur A, 2 = A/B, 3 = A/B/C.
  int gruppen;

  /// Gruppe `B`/`C` → ein Platz pro Platz in [plaetze].
  final Map<String, List<GruppenPlatz>> gruppenPlaetze;

  /// In B und C stehen die Antworten von Ankreuz-, Lücken- und
  /// Zuordnungsaufgaben in anderer Reihenfolge.
  bool antwortenMischen;
  GeneratorEinstellung einstellung;

  /// Woraus der Generator wählt: `alle`, `suche:<id>` oder `ordner:<id>`.
  String quelle;

  /// Zusätzliche Filter des Generators (Klasse, Aufgabentyp, Kompetenz ...).
  StoreFilter filter;
  final List<Zuweisung> zuweisungen;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titel': titel,
    'erstellt': erstellt.toIso8601String(),
    'plaetze': [for (final p in plaetze) p.toJson()],
    'gruppen': gruppen,
    'gruppen_plaetze': {
      for (final e in gruppenPlaetze.entries) e.key: [for (final g in e.value) g.toJson()],
    },
    'antworten_mischen': antwortenMischen,
    'einstellung': einstellung.toJson(),
    'quelle': quelle,
    'filter': filter.toJson(),
    'zuweisungen': [for (final z in zuweisungen) z.toJson()],
  };
}

// --- Generator ---

/// Stellt Pakete zufällig, aber nachvollziehbar zusammen: gleicher Seed,
/// gleiches Ergebnis. Gesperrte Plätze bleiben immer stehen.
class PaketGenerator {
  PaketGenerator(List<StoreAufgabe> pool, {this.gemerkt = const {}})
    : pool = [...pool]..sort((a, b) => a.id.compareTo(b.id));

  /// Aufgaben, aus denen gewählt wird (meist die Treffer des Filters).
  final List<StoreAufgabe> pool;

  /// Gemerkte Aufgaben werden beim Austauschen zuerst vorgeschlagen.
  final Set<String> gemerkt;

  static const maxPlaetze = 30;

  StoreAufgabe? _finde(String id) {
    for (final a in pool) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Füllt alle offenen Plätze neu. Gesperrte Plätze behalten ihre Position.
  /// [alle] löst gesperrte Aufgaben auf, die nicht im Pool sind.
  List<PaketPlatz> fuelle(
    List<PaketPlatz> bisher,
    GeneratorEinstellung e,
    int seed, {
    Map<String, StoreAufgabe> alle = const {},
  }) {
    final random = Random(seed);
    final gesperrt = <int, PaketPlatz>{
      for (var i = 0; i < bisher.length; i++)
        if (bisher[i].gesperrt) i: bisher[i],
    };
    StoreAufgabe? info(String id) => _finde(id) ?? alle[id];
    final gewaehlt = <StoreAufgabe>[];
    final belegt = <StoreAufgabe>[for (final p in gesperrt.values) ?info(p.aufgabe)];
    var minuten = belegt.fold<double>(0, (s, a) => s + a.minuten);

    bool weiter() {
      final gesamt = gesperrt.length + gewaehlt.length;
      if (gesamt >= maxPlaetze) return false;
      final ziel = e.zielMinuten;
      if (ziel != null) return minuten < ziel;
      return gesamt < max(e.anzahl, gesperrt.length);
    }

    while (weiter()) {
      final a = _waehle([...belegt, ...gewaehlt], e, random);
      if (a == null) break;
      gewaehlt.add(a);
      minuten += a.minuten;
    }
    if (e.aufsteigend) {
      gewaehlt.sort((a, b) => (a.schwierigkeit ?? 3).compareTo(b.schwierigkeit ?? 3));
    }
    final laenge = gesperrt.length + gewaehlt.length;
    final ergebnis = <PaketPlatz>[];
    var naechste = 0;
    for (var i = 0; i < laenge; i++) {
      final g = gesperrt[i];
      if (g != null) {
        ergebnis.add(g);
      } else if (naechste < gewaehlt.length) {
        ergebnis.add(PaketPlatz.von(gewaehlt[naechste++]));
      }
    }
    // Gesperrte Plätze hinter dem neuen Ende rücken nach vorn.
    for (final e in gesperrt.entries) {
      if (e.key >= laenge) ergebnis.add(e.value);
    }
    return ergebnis;
  }

  /// Ersetzt nur den Platz [index]; `null`, wenn keine andere Aufgabe passt.
  PaketPlatz? neuWuerfeln(List<PaketPlatz> plaetze, int index, GeneratorEinstellung e, int seed) {
    final andere = <StoreAufgabe>[
      for (var i = 0; i < plaetze.length; i++)
        if (i != index) ?_finde(plaetze[i].aufgabe),
    ];
    final aktuell = _finde(plaetze[index].aufgabe);
    final a = _waehle([...andere, ?aktuell], e, Random(seed), bewertet: andere);
    return a == null ? null : PaketPlatz.von(a);
  }

  /// Kandidaten zum gezielten Austauschen von Platz [index]: gleiche Kompetenz
  /// und gleicher Aufgabentyp zuerst, gemerkte vor anderen.
  List<StoreAufgabe> vorschlaege(
    List<PaketPlatz> plaetze,
    int index, {
    int anzahl = 12,
    Map<String, StoreAufgabe> alle = const {},
  }) {
    final ziel = _finde(plaetze[index].aufgabe) ?? alle[plaetze[index].aufgabe];
    final drin = {for (final p in plaetze) p.aufgabe};
    final gruppen = {
      for (var i = 0; i < plaetze.length; i++)
        if (i != index) ?(_finde(plaetze[i].aufgabe) ?? alle[plaetze[i].aufgabe])?.gruppenSchluessel,
    };
    double wert(StoreAufgabe a) {
      if (ziel == null) return gemerkt.contains(a.id) ? 1 : 0;
      var w = 0.0;
      if (a.hauptkompetenz != null && a.hauptkompetenz == ziel.hauptkompetenz) w += 4;
      if (a.kompetenzen.intersection(ziel.kompetenzen).isNotEmpty) w += 1;
      if (a.formatGruppenSet.intersection(ziel.formatGruppenSet).isNotEmpty) w += 2;
      if (a.themenbereiche.intersection(ziel.themenbereiche).isNotEmpty) w += 1;
      if (a.klasse == ziel.klasse) w += 0.5;
      w -= ((a.schwierigkeit ?? 3) - (ziel.schwierigkeit ?? 3)).abs() * 0.5;
      if (gemerkt.contains(a.id)) w += 1.5;
      return w;
    }

    final kandidaten =
        [
          for (final a in pool)
            if (!drin.contains(a.id) && !gruppen.contains(a.gruppenSchluessel)) a,
        ]..sort((a, b) {
          final c = wert(b).compareTo(wert(a));
          return c != 0 ? c : a.id.compareTo(b.id);
        });
    return kandidaten.take(anzahl).toList();
  }

  /// Wählt eine Aufgabe, die nicht in [ausgeschlossen] steht. Kompetenzen und
  /// (auf Wunsch) Aufgabentypen werden gestreut; der Zufall entscheidet unter
  /// ähnlich guten Kandidaten.
  StoreAufgabe? _waehle(
    List<StoreAufgabe> ausgeschlossen,
    GeneratorEinstellung e,
    Random random, {
    List<StoreAufgabe>? bewertet,
  }) {
    final ids = {for (final a in ausgeschlossen) a.id};
    final gruppen = {for (final a in ausgeschlossen) a.gruppenSchluessel};
    final vergleich = bewertet ?? ausgeschlossen;
    final kompetenzen = <String, int>{};
    final formate = <String, int>{};
    for (final a in vergleich) {
      if (a.hauptkompetenz != null) kompetenzen[a.hauptkompetenz!] = (kompetenzen[a.hauptkompetenz!] ?? 0) + 1;
      for (final f in a.formatGruppenSet) {
        formate[f] = (formate[f] ?? 0) + 1;
      }
    }
    StoreAufgabe? beste;
    var besterWert = double.negativeInfinity;
    for (final a in pool) {
      if (ids.contains(a.id) || gruppen.contains(a.gruppenSchluessel)) continue;
      var w = random.nextDouble();
      w -= (kompetenzen[a.hauptkompetenz] ?? 0) * 0.6;
      if (e.formateMischen) {
        w -= a.formatGruppenSet.fold<int>(0, (s, f) => s + (formate[f] ?? 0)) * 0.25;
      }
      if (e.zielMinuten != null) {
        final rest = e.zielMinuten! - vergleich.fold<double>(0, (s, x) => s + x.minuten);
        if (a.minuten > rest + 2) w -= 0.5;
      }
      if (w > besterWert) {
        besterWert = w;
        beste = a;
      }
    }
    return beste;
  }
}

// --- Gruppen A/B/C ---

/// Bildet die Gruppen B und C. Reihenfolge der Quellen pro Platz: andere
/// Aufgabe derselben Variantengruppe, dieselbe Vorlage mit anderen Zahlen,
/// Ersatz mit gleicher Kompetenz, gleichem Aufgabentyp und gleicher
/// Schwierigkeit; sonst fehlt der Platz und die Oberfläche warnt.
Map<String, List<GruppenPlatz>> bildeGruppen(List<PaketPlatz> plaetze, int gruppen, Map<String, StoreAufgabe> alle) {
  final belegt = {for (final p in plaetze) p.aufgabe};
  final ergebnis = <String, List<GruppenPlatz>>{};
  for (var g = 1; g < gruppen.clamp(1, 3); g++) {
    final liste = <GruppenPlatz>[];
    for (final p in plaetze) {
      final platz = gruppenPlatzFuer(p, g, alle, belegt);
      if (platz.aufgabe != null && platz.art != GruppenArt.parameter) belegt.add(platz.aufgabe!);
      liste.add(platz);
    }
    ergebnis[gruppenNamen[g]] = liste;
  }
  return ergebnis;
}

/// Ein Platz für Gruppe Nummer [g] (1 = B, 2 = C). [belegt] sind alle IDs,
/// die schon im Paket oder in einer anderen Gruppe stehen.
GruppenPlatz gruppenPlatzFuer(PaketPlatz p, int g, Map<String, StoreAufgabe> alle, Set<String> belegt) {
  final original = alle[p.aufgabe];
  if (original == null) return const GruppenPlatz(art: GruppenArt.fehlt);
  final vg = original.variantengruppe;
  if (vg != null) {
    final varianten = [
      for (final a in alle.values)
        if (a.variantengruppe == vg && !belegt.contains(a.id)) a,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (varianten.isNotEmpty) {
      return GruppenPlatz(aufgabe: varianten.first.id, fassung: varianten.first.fassung, art: GruppenArt.variante);
    }
  }
  if (original.parametrisierbar) {
    return GruppenPlatz(aufgabe: original.id, fassung: p.fassung, art: GruppenArt.parameter, seed: g);
  }
  final ersatz = ersatzKandidaten(original, alle, belegt);
  if (ersatz.isNotEmpty) {
    final e = ersatz.first;
    final gleicherTyp = e.formatGruppenSet.intersection(original.formatGruppenSet).isNotEmpty;
    return GruppenPlatz(aufgabe: e.id, fassung: e.fassung, art: gleicherTyp ? GruppenArt.ersatz : GruppenArt.ersatzTyp);
  }
  return const GruppenPlatz(art: GruppenArt.fehlt);
}

/// Ersatz für [original], beste zuerst: gleiche Hauptkompetenz und ähnliche
/// Schwierigkeit (höchstens eine Stufe Abstand) sind Pflicht; gleicher
/// Aufgabentyp kommt vor anderem Typ, dann geringerer Abstand.
List<StoreAufgabe> ersatzKandidaten(StoreAufgabe original, Map<String, StoreAufgabe> alle, Set<String> belegt) {
  final k = original.hauptkompetenz;
  if (k == null) return const [];
  int abstand(StoreAufgabe a) => ((a.schwierigkeit ?? 3) - (original.schwierigkeit ?? 3)).abs().round();
  int typ(StoreAufgabe a) {
    if (a.formate.containsAll(original.formate)) return 0;
    if (a.formatGruppenSet.intersection(original.formatGruppenSet).isNotEmpty) return 1;
    return 2;
  }

  final passend = [
    for (final a in alle.values)
      if (a.id != original.id &&
          !belegt.contains(a.id) &&
          a.gruppenSchluessel != original.gruppenSchluessel &&
          a.hauptkompetenz == k &&
          abstand(a) <= 1)
        a,
  ];
  passend.sort((a, b) {
    final t = (typ(a) > 1 ? 1 : 0).compareTo(typ(b) > 1 ? 1 : 0);
    if (t != 0) return t;
    final c = abstand(a).compareTo(abstand(b));
    if (c != 0) return c;
    final f = typ(a).compareTo(typ(b));
    return f != 0 ? f : a.id.compareTo(b.id);
  });
  return passend;
}

// --- Antworten mischen ---

/// Kopie von [inhalt] mit Antworten in anderer Reihenfolge (Ankreuzformate,
/// Lückentext, Zuordnung). Richtige Antworten und Fehlerbilder ziehen mit.
Map<String, dynamic> mischeAntworten(Map<String, dynamic> inhalt, int seed) {
  final kopie = jsonDecode(jsonEncode(inhalt)) as Map<String, dynamic>;
  final random = Random(seed);
  for (final item in alleItems(kopie)) {
    final a = item['antwort'];
    if (a is! Map<String, dynamic>) continue;
    final fb = item['fehlerbilder'] is Map ? Map<String, dynamic>.from(item['fehlerbilder'] as Map) : null;
    switch (item['antwortformat']) {
      case 'mc_1aus5' || 'mc_1aus6' || 'mc_2aus5':
        final optionen = a['optionen'];
        if (optionen is! List || optionen.length < 2) continue;
        final perm = _permutation(optionen.length, random);
        a['optionen'] = [for (final alt in perm) optionen[alt]];
        final neu = {for (var i = 0; i < perm.length; i++) perm[i]: i};
        final r = a['richtig'];
        if (r is int) a['richtig'] = neu[r] ?? r;
        if (r is List) {
          a['richtig'] = [
            for (final x in r)
              if (x is int) neu[x] ?? x,
          ]..sort();
        }
        if (fb != null) {
          item['fehlerbilder'] = {for (final e in fb.entries) '${neu[int.tryParse(e.key)] ?? e.key}': e.value};
        }
      case 'lueckentext':
        final richtig = a['richtig'];
        final neueRichtig = richtig is List ? [...richtig] : null;
        final abbildung = <int, Map<int, int>>{};
        for (var l = 1; l <= 2; l++) {
          final opt = a['luecke_$l'];
          if (opt is! List || opt.length < 2) continue;
          final perm = _permutation(opt.length, random);
          a['luecke_$l'] = [for (final alt in perm) opt[alt]];
          final neu = {for (var i = 0; i < perm.length; i++) perm[i]: i};
          abbildung[l] = neu;
          if (neueRichtig != null && neueRichtig.length >= l && neueRichtig[l - 1] is int) {
            neueRichtig[l - 1] = neu[neueRichtig[l - 1]] ?? neueRichtig[l - 1];
          }
        }
        if (neueRichtig != null) a['richtig'] = neueRichtig;
        if (fb != null) {
          item['fehlerbilder'] = {for (final e in fb.entries) _lueckenSchluessel(e.key, abbildung): e.value};
        }
      case 'zuordnung':
        final elemente = a['elemente'];
        final richtig = a['richtig'];
        if (elemente is! List || elemente.length < 2 || richtig is! Map) continue;
        final perm = _permutation(elemente.length, random);
        a['elemente'] = [for (final alt in perm) elemente[alt]];
        a['richtig'] = {
          for (var i = 0; i < perm.length; i++)
            if (richtig.containsKey('${perm[i]}')) '$i': richtig['${perm[i]}'],
        };
    }
  }
  return kopie;
}

String _lueckenSchluessel(String schluessel, Map<int, Map<int, int>> abbildung) {
  final teile = schluessel.split(':');
  if (teile.length != 2) return schluessel;
  final l = int.tryParse(teile[0]);
  final o = int.tryParse(teile[1]);
  final neu = l == null || o == null ? null : abbildung[l]?[o];
  return neu == null ? schluessel : '$l:$neu';
}

/// Zufällige Reihenfolge, die sich von der ursprünglichen unterscheidet.
List<int> _permutation(int n, Random random) {
  final p = List<int>.generate(n, (i) => i);
  for (var versuch = 0; versuch < 5; versuch++) {
    p.shuffle(random);
    if (!_istIdentitaet(p)) return p;
  }
  return [...p.sublist(1), p.first];
}

bool _istIdentitaet(List<int> p) {
  for (var i = 0; i < p.length; i++) {
    if (p[i] != i) return false;
  }
  return true;
}
