/// Präsentations-Zugang: eine Lehrperson mit einer gefüllten Beispielklasse,
/// damit sich der Bereich für Lehrende zeigen und fotografieren lässt, ohne
/// vorher selbst Pakete zu lösen. Namen und Antworten sind erfunden; die
/// Aufgaben kommen aus dem geladenen Katalog.
library;

import 'dart:math';

import 'package:didaktik_kern/src/lehre/lehrbereich.dart';
import 'package:didaktik_kern/src/lehre/paket.dart';
import 'package:didaktik_kern/src/lehre/store.dart';
import 'package:didaktik_kern/src/lehre/testklassen.dart';
import 'package:didaktik_kern/src/pruefung.dart';

const praesentationPersonId = 'lehrperson-praesentation';
const praesentationKlassenName = '5B';
const praesentationKlassenKuerzel = '5b';

/// Erfundener Name der Lehrperson, der oben rechts statt der Testperson steht.
const praesentationLehrperson = 'Julia Berger';

/// Erfundene Schüler\*innen der Beispielklasse (Konto-Kürzel → Name).
const praesentationKonten = {
  's01': 'Amelie B.',
  's02': 'Ben K.',
  's03': 'Clara W.',
  's04': 'David S.',
  's05': 'Elif Y.',
  's06': 'Felix H.',
  's07': 'Hannah G.',
  's08': 'Ivan P.',
  's09': 'Jana L.',
  's10': 'Jonas R.',
  's11': 'Lara M.',
  's12': 'Leon T.',
  's13': 'Lina F.',
  's14': 'Marko D.',
  's15': 'Mia S.',
  's16': 'Noah A.',
  's17': 'Paul E.',
  's18': 'Sara N.',
  's19': 'Selin Ö.',
  's20': 'Theo V.',
  's21': 'Valentina C.',
  's22': 'Yusuf K.',
};

/// Wie sicher jedes Konto im Schnitt antwortet (Anteil richtiger Antworten).
const _koennen = [
  0.93, 0.62, 0.88, 0.71, 0.48, 0.80, 0.95, 0.66, 0.74, 0.58, 0.84, //
  0.42, 0.90, 0.69, 0.77, 0.55, 0.86, 0.38, 0.72, 0.64, 0.82, 0.51,
];

/// Konten mit einer klaren Schwäche in der Förder-Kompetenz.
const _schwach = {4, 11, 17, 21};

/// Formate, für die sich glaubwürdige Antworten erzeugen lassen.
const _einfacheFormate = {'mc_1aus5', 'mc_1aus6', 'mc_2aus5', 'offen_zahl', 'halboffen', 'offen_term'};

String praesentationKlassenId(String personId) => '$personId-$praesentationKlassenKuerzel';

/// Die Ablage des Präsentations-Zugangs: vier Pakete (abgeschlossene
/// Hausübung, laufende Wiederholung, Förderpaket, Entwurf mit zwei Gruppen),
/// dazu Antworten und Abgaben der Beispielklasse, ein Merklisten-Ordner und
/// eine gespeicherte Suche. Gleiche Eingaben ergeben dieselben Daten.
LehrDaten praesentationsDaten(
  String personId,
  List<StoreAufgabe> aufgaben,
  DateTime jetzt, {
  Map<String, String> levelTitel = const {},
}) {
  final daten = LehrDaten();
  if (aufgaben.isEmpty) return daten;
  final zufall = Random(20261111);
  final alle = [...aufgaben]..sort((a, b) => a.id.compareTo(b.id));
  final nachId = {for (final a in alle) a.id: a};
  final einfach = [
    for (final a in alle)
      if (a.formate.isNotEmpty && a.formate.every(_einfacheFormate.contains)) a,
  ];
  // Aufgaben aus dem Lernpfad zuerst: Sie tragen ein Level und damit ein Thema.
  final imLernpfad = [
    for (final a in einfach)
      if (a.levels.isNotEmpty) a,
  ];
  final pool = imLernpfad.length >= 8 ? imLernpfad : (einfach.length >= 8 ? einfach : alle);

  // Förder-Kompetenz: die mit den meisten Aufgaben.
  final proKompetenz = <String, List<StoreAufgabe>>{};
  for (final a in pool) {
    final k = a.hauptkompetenz;
    if (k != null) proKompetenz.putIfAbsent(k, () => []).add(a);
  }
  final kompetenzen = proKompetenz.keys.toList()
    ..sort((a, b) {
      final n = proKompetenz[b]!.length.compareTo(proKompetenz[a]!.length);
      return n != 0 ? n : a.compareTo(b);
    });
  final foerderKompetenz = kompetenzen.firstOrNull;
  final foerderAufgaben = proKompetenz[foerderKompetenz] ?? const <StoreAufgabe>[];

  // Hausübung: Aufgaben der Förder-Kompetenz und die folgenden im Lernplan.
  final hausuebung = <StoreAufgabe>[...foerderAufgaben.take(3)];
  final start = hausuebung.isEmpty ? 0 : pool.indexOf(hausuebung.first);
  for (var i = 0; i < pool.length && hausuebung.length < min(6, pool.length); i++) {
    final a = pool[(start + i) % pool.length];
    if (!hausuebung.contains(a)) hausuebung.add(a);
  }
  hausuebung.sort((a, b) => a.id.compareTo(b.id));

  List<StoreAufgabe> verteilt(int anzahl, int versatz, Set<String> ohne) {
    final frei = [
      for (final a in pool)
        if (!ohne.contains(a.id)) a,
    ];
    if (frei.isEmpty) return [];
    final n = min(anzahl, frei.length);
    return [for (var i = 0; i < n; i++) frei[(versatz + i * frei.length ~/ n) % frei.length]];
  }

  final wiederholung = verteilt(8, 1, {for (final a in hausuebung) a.id});
  final foerder = [...foerderAufgaben.where((a) => !hausuebung.contains(a)).take(4)];
  if (foerder.length < 3) {
    foerder
      ..clear()
      ..addAll(foerderAufgaben.take(4));
  }
  final entwurf = verteilt(5, 3, {for (final a in hausuebung) a.id, for (final a in wiederholung) a.id});

  final klasse = praesentationKlassenId(personId);
  final konten = [for (final k in praesentationKonten.keys) '$personId-$k'];
  final schwache = [
    for (var i = 0; i < konten.length; i++)
      if (_schwach.contains(i)) konten[i],
  ];

  String levelName(List<StoreAufgabe> liste) {
    final zahl = <String, int>{};
    for (final a in liste) {
      if (a.levels.isNotEmpty) zahl[a.levels.first] = (zahl[a.levels.first] ?? 0) + 1;
    }
    // Häufigstes Level, das einen Titel hat.
    for (final e in zahl.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) {
      final titel = levelTitel[e.key] ?? '';
      if (titel.isNotEmpty) return titel;
    }
    return '';
  }

  Paket paket(String nr, String titel, List<StoreAufgabe> liste, DateTime erstellt) => Paket(
    id: 'praesentation-paket-$nr',
    titel: titel,
    erstellt: erstellt,
    code: paketCode(zufall),
    plaetze: [for (final a in liste) PaketPlatz.von(a)],
    einstellung: GeneratorEinstellung(anzahl: max(1, liste.length)),
  );

  final thema = levelName(hausuebung);
  final p1 = paket(
    '1',
    thema.isEmpty ? 'Hausübung Woche 1' : 'Hausübung: $thema',
    hausuebung,
    jetzt.subtract(const Duration(days: 10)),
  );
  final p2 = paket('2', 'Wiederholung vor der Schularbeit', wiederholung, jetzt.subtract(const Duration(days: 3)));
  final p3 = paket(
    '3',
    'Förderpaket ${foerderKompetenz ?? ''} ($praesentationKlassenName)'.replaceAll('  ', ' '),
    foerder,
    jetzt.subtract(const Duration(days: 1, hours: 2)),
  );
  if (foerderKompetenz != null) {
    p3
      ..empfaenger[klasse] = schwache
      ..filter.umschalten('kompetenz', foerderKompetenz)
      ..foerderung = Foerderung(klasse: klasse, kompetenz: foerderKompetenz, schueler: schwache);
  }
  final p4 = paket('4', 'Test Kapitel 1 (Entwurf)', entwurf, jetzt.subtract(const Duration(hours: 5)))..gruppen = 2;
  p4.gruppenPlaetze.addAll(bildeGruppen(p4.plaetze, 2, nachId));

  final versuche = <SchuelerVersuch>[];
  final abgaben = <Abgabe>[];

  /// Antworten von [konto] auf die ersten [anteil] Aufgaben von [p].
  void loese(Paket p, Zuweisung z, int index, DateTime am, {double anteil = 1}) {
    final konto = konten[index];
    final zahl = (p.plaetze.length * anteil).ceil();
    var zeit = am;
    for (final platz in p.plaetze.take(zahl)) {
      final a = nachId[platz.aufgabe];
      if (a == null) continue;
      for (final item in alleItems(a.inhalt)) {
        final id = item['item_id'];
        if (id is! String) continue;
        final stufe = item['schwierigkeit_start'] is int ? item['schwierigkeit_start'] as int : 3;
        var p0 = _koennen[index] + (3 - stufe) * 0.07;
        if (_schwach.contains(index) && item['kompetenz'] == foerderKompetenz) p0 *= 0.3;
        final richtig = zufall.nextDouble() < p0.clamp(0.05, 0.98);
        final (text, selbst) = _antwort(item, richtig, zufall);
        final hilfenDa = item['hilfen'] is List ? (item['hilfen'] as List).length : 0;
        final hilfen = !richtig || _koennen[index] < 0.6 ? min(hilfenDa, zufall.nextInt(3)) : 0;
        final soll = item['erwartete_sekunden'] is int ? item['erwartete_sekunden'] as int : 90;
        final sekunden = max(8, (soll * (0.55 + zufall.nextDouble() * 1.1)).round());
        zeit = zeit.add(Duration(seconds: sekunden + 5));
        versuche.add(
          SchuelerVersuch(
            konto: konto,
            paket: p.id,
            zuweisung: z.id,
            aufgabe: a.id,
            itemId: id,
            antwort: text,
            r: richtig ? 1 : 0,
            hilfen: hilfen,
            sekunden: sekunden,
            am: zeit,
            selbstBewertet: selbst,
          ),
        );
      }
    }
  }

  // Hausübung: vor neun Tagen verschickt, Abgabe vor drei Tagen. Zwei Konten
  // haben nicht abgegeben, eines zu spät.
  if (p1.plaetze.isNotEmpty) {
    final abgabe = jetzt.subtract(const Duration(days: 3));
    versende(p1, {klasse: konten}, gruppen: 1, abgabe: abgabe, jetzt: jetzt.subtract(const Duration(days: 9)));
    final z = p1.zuweisungen.last;
    for (var i = 0; i < konten.length; i++) {
      if (i == 7 || i == 19) continue;
      final am = i == 13
          ? abgabe.add(const Duration(hours: 20))
          : abgabe.subtract(Duration(hours: 6 + zufall.nextInt(120), minutes: zufall.nextInt(60)));
      loese(p1, z, i, am.subtract(const Duration(minutes: 25)));
      abgaben.add(Abgabe(konto: konten[i], zuweisung: z.id, am: am));
    }
  }

  // Wiederholung: vor zwei Tagen verschickt, Abgabe in vier Tagen. Gut die
  // Hälfte ist fertig, drei Konten sind mittendrin.
  if (p2.plaetze.isNotEmpty) {
    versende(
      p2,
      {klasse: konten},
      gruppen: 1,
      abgabe: jetzt.add(const Duration(days: 4)),
      jetzt: jetzt.subtract(const Duration(days: 2)),
    );
    final z = p2.zuweisungen.last;
    for (var i = 0; i < konten.length; i++) {
      final am = jetzt.subtract(Duration(hours: 2 + zufall.nextInt(40), minutes: zufall.nextInt(60)));
      if (i % 9 == 5) {
        loese(p2, z, i, am, anteil: 0.5);
      } else if (i % 5 != 2 && i % 7 != 3) {
        loese(p2, z, i, am.subtract(const Duration(minutes: 30)));
        abgaben.add(Abgabe(konto: konten[i], zuweisung: z.id, am: am));
      }
    }
  }

  // Förderpaket: gestern an die vier Konten mit Schwäche, eines ist fertig.
  if (p3.plaetze.isNotEmpty && schwache.isNotEmpty) {
    versende(
      p3,
      {klasse: schwache},
      gruppen: 1,
      abgabe: jetzt.add(const Duration(days: 6)),
      jetzt: jetzt.subtract(const Duration(days: 1)),
    );
    final z = p3.zuweisungen.last;
    final indizes = _schwach.toList()..sort();
    final am = jetzt.subtract(const Duration(hours: 3));
    loese(p3, z, indizes.first, am.subtract(const Duration(minutes: 20)));
    abgaben.add(Abgabe(konto: konten[indizes.first], zuweisung: z.id, am: am));
    if (indizes.length > 1) loese(p3, z, indizes[1], jetzt.subtract(const Duration(hours: 1)), anteil: 0.5);
  }

  daten.pakete.addAll([
    for (final p in [p4, p3, p2, p1])
      if (p.plaetze.isNotEmpty) p,
  ]);
  daten.versuche.addAll(versuche);
  daten.abgaben.addAll(abgaben);
  daten.ordnerMit(standardOrdner)!.aufgaben.addAll([for (final a in verteilt(3, 2, const {})) a.id]);
  daten.ordner.add(
    MerkOrdner(
      id: 'praesentation-ordner-1',
      name: 'Schularbeit 2',
      aufgaben: [for (final a in wiederholung.take(5)) a.id],
    ),
  );
  if (foerderKompetenz != null) {
    daten.suchen.add(
      GespeicherteSuche(id: 'praesentation-suche-1', name: 'Förderung $foerderKompetenz', filter: p3.filter.kopie()),
    );
  }
  return daten;
}

/// Antworttext eines Items und ob es selbst bewertet wird. Falsche Antworten
/// sind naheliegende Fehler (anderes Kästchen, Vorzeichen, Rechenfehler); wo
/// sich keine erfinden lässt, bleibt die Antwort leer ("Weiß ich nicht").
(String, bool) _antwort(Map<String, dynamic> item, bool richtig, Random zufall) {
  final a = item['antwort'];
  if (a is! Map) return ('', false);
  switch (item['antwortformat']) {
    case 'mc_1aus5' || 'mc_1aus6':
      final optionen = a['optionen'];
      final r = a['richtig'];
      if (optionen is! List || r is! int || optionen.length < 2) return ('', false);
      var wahl = r;
      if (!richtig) {
        wahl = zufall.nextInt(optionen.length - 1);
        if (wahl >= r) wahl++;
      }
      return ('${optionen[wahl]}', false);
    case 'mc_2aus5':
      final optionen = a['optionen'];
      final r = a['richtig'];
      if (optionen is! List || r is! List || r.length < 2) return ('', false);
      final wahl = [...r.whereType<int>()];
      if (!richtig) {
        final falsche = [
          for (var i = 0; i < optionen.length; i++)
            if (!wahl.contains(i)) i,
        ];
        if (falsche.isEmpty) return ('', false);
        wahl[wahl.length - 1] = falsche[zufall.nextInt(falsche.length)];
        wahl.sort();
      }
      return ([for (final i in wahl) '${optionen[i]}'].join(' · '), false);
    case 'offen_zahl':
      final w = a['wert'];
      if (w is! num) return ('', false);
      return (_zahl(richtig ? w : _daneben(w, zufall)), false);
    case 'halboffen':
      final w = a['wert'];
      final vorlage = a['vorlage'];
      if (w is! List || vorlage is! String || !w.every((x) => x is num)) return ('', false);
      final werte = [...w.cast<num>()];
      if (!richtig) werte[werte.length - 1] = _daneben(werte.last, zufall);
      var i = 0;
      return (vorlage.replaceAllMapped(RegExp(r'\{[^}]*\}'), (_) => i < werte.length ? _zahl(werte[i++]) : ''), false);
    case 'offen_term':
      final t = a['term'];
      return (richtig && t is String ? t : '', false);
    case 'offen_text':
      final m = a['musterloesung'];
      return (richtig && m is String ? m : '', richtig);
    default:
      return ('', false);
  }
}

/// Ein naheliegender falscher Wert zu [w].
num _daneben(num w, Random zufall) {
  final kandidaten = <num>[
    if (w != 0) -w,
    w + 1,
    w - 1,
    w * 2,
    if (w != 0) w * 10,
    if (w is int && w.isEven && w != 0) w ~/ 2,
  ];
  return kandidaten[zufall.nextInt(kandidaten.length)];
}

/// Zahl mit Komma und ohne überflüssige Nullen.
String _zahl(num w) {
  if (w == w.roundToDouble()) return '${w.round()}'.replaceAll('-', '−');
  var t = w.toStringAsFixed(4);
  t = t.replaceFirst(RegExp(r'0+$'), '');
  return t.replaceAll('.', ',').replaceAll('-', '−');
}
