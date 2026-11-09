import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/lehre/paket_pdf.dart';
import 'package:tuto_didaktik/main.dart';

import 'hilfsmittel.dart';

Future<void> starteAls(WidgetTester t, Api api, String person, {DemoClient? demo}) async {
  t.view.physicalSize = const Size(1700, 1050);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(DidaktikApp(api: api, demo: demo));
  await t.pumpAndSettle();
  await t.tap(find.byKey(ValueKey('person-$person')));
  await t.pumpAndSettle();
}

Future<void> seite(WidgetTester t, String name) async {
  await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(name)));
  await t.pumpAndSettle();
}

String trefferText(WidgetTester t) => t.widget<Text>(find.byKey(const ValueKey('trefferzahl'))).data!;

List<String> plaetze(WidgetTester t) => [
  for (final e in t.widgetList(
    find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('platz-')),
  ))
    (e.key! as ValueKey<String>).value.split('-').skip(2).join('-'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Rollenwahl: Didaktik-Team und Lehrende getrennt', (t) async {
    t.view.physicalSize = const Size(1700, 1050);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(DidaktikApp(api: testApi()));
    await t.pumpAndSettle();
    expect(find.text('Didaktik-Team'), findsOneWidget);
    expect(find.text('Lehrende'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('person-lehrperson-schule')));
    await t.pumpAndSettle();
    expect(find.text('Tuto für Lehrende'), findsOneWidget);
    expect(find.text('Import'), findsNothing);
    expect(find.text('Meine Klassen'), findsOneWidget);
    await t.tap(find.text('Wechseln'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('person-didaktik-a')));
    await t.pumpAndSettle();
    expect(find.text('Tuto Didaktik-Tool'), findsOneWidget);
  });

  testWidgets('Store: filtern, zählen, merken, ins Paket', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    await seite(t, 'Aufgaben');
    expect(trefferText(t), '$aufgabenZahl Aufgaben');

    await t.tap(find.byKey(const ValueKey('filter-format-ankreuzen')));
    await t.pumpAndSettle();
    final ankreuzen = int.parse(trefferText(t).split(' ').first);
    expect(ankreuzen, inInclusiveRange(1, aufgabenZahl - 1));
    expect(find.byType(InputChip), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('filter-zuruecksetzen')));
    await t.pumpAndSettle();
    expect(trefferText(t), '$aufgabenZahl Aufgaben');

    await t.enterText(find.byKey(const ValueKey('store-suche')), 'zzz-gibt-es-nicht');
    await t.pumpAndSettle();
    expect(trefferText(t), '0 Aufgaben');
    await t.enterText(find.byKey(const ValueKey('store-suche')), '');
    await t.pumpAndSettle();

    final erste = find
        .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('merken-'))
        .first;
    await t.tap(erste);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    final insPaket = find
        .byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ins-paket-'),
        )
        .first;
    await t.tap(insPaket);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('paket-leiste')), findsOneWidget);
    expect(find.textContaining('1 Aufgaben'), findsWidgets);

    await seite(t, 'Merkliste');
    expect(find.textContaining('Gemerkt · 1 Aufgaben'), findsOneWidget);
  });

  testWidgets('Generator: generieren, sperren, neu würfeln, Gruppen, zuweisen', (t) async {
    await starteAls(t, testApi(), 'lehrperson-nachhilfe');
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    final erst = plaetze(t);
    expect(erst, hasLength(5));
    expect(erst.toSet(), hasLength(5));

    await t.tap(find.byKey(const ValueKey('sperren-0')));
    await t.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('generieren')));
      await t.pumpAndSettle();
      expect(plaetze(t).first, erst.first);
      expect(plaetze(t), hasLength(5));
    }
    final vorWuerfeln = plaetze(t);
    await t.tap(find.byKey(const ValueKey('wuerfeln-2')));
    await t.pumpAndSettle();
    final nachWuerfeln = plaetze(t);
    expect(nachWuerfeln[2], isNot(vorWuerfeln[2]));
    expect(
      [nachWuerfeln[0], nachWuerfeln[1], nachWuerfeln[3], nachWuerfeln[4]],
      [vorWuerfeln[0], vorWuerfeln[1], vorWuerfeln[3], vorWuerfeln[4]],
    );

    await t.tap(find.byKey(const ValueKey('tab-gruppen')));
    await t.pumpAndSettle();
    // Standard sind zwei Gruppen, mehr lassen sich dazunehmen (A, B, C ...).
    expect(find.text('Gruppe B'), findsOneWidget);
    expect(find.text('Gruppe C'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const ValueKey('gruppen-mehr')));
      await t.pumpAndSettle();
    }
    expect(find.text('5 Gruppen'), findsOneWidget);
    expect(find.byKey(const ValueKey('zelle-E-4')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('paket-zuweisen')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Gruppe Montag'));
    await t.pumpAndSettle();
    expect(find.textContaining('An Gruppe Montag zugewiesen'), findsOneWidget);

    // Nach dem Neuladen ist alles noch da.
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();
    expect(find.textContaining('5 Gruppen'), findsOneWidget);
    expect(find.textContaining('zugewiesen: Gruppe Montag'), findsOneWidget);
  });

  Finder mitSchluessel(String anfang) =>
      find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(anfang));

  testWidgets('Klasse: Förderpaket nur an Betroffene, Paket an alle, Antworten pro Person', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    // Ein normales Paket für "an alle senden".
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();

    await seite(t, 'Klassen');
    await t.tap(mitSchluessel('klasse-lehrperson').first);
    await t.pumpAndSettle();
    expect(find.text('Kompetenzen der Klasse'), findsOneWidget);
    expect(find.text('Zugewiesene Pakete'), findsOneWidget);

    // Förderpaket: Zuweisen fragt nicht nach der Klasse.
    final foerder = find.byWidgetPredicate(
      (w) =>
          w is TextButton &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('foerder-') &&
          w.onPressed != null,
    );
    expect(foerder, findsWidgets);
    await t.tap(foerder.first);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('foerder-hinweis')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paket-zuweisen')));
    await t.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.textContaining('zugewiesen (A:'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();
    expect(find.textContaining('Personen'), findsWidgets);

    // Paket an alle senden.
    await t.tap(find.byKey(const ValueKey('an-alle-senden')));
    await t.pumpAndSettle();
    await t.tap(find.byType(SimpleDialogOption).first);
    await t.pumpAndSettle();
    expect(find.textContaining('zugewiesen (A:'), findsOneWidget);
    expect(find.textContaining('· an alle'), findsOneWidget);

    // Antworten einer Person.
    await t.tap(mitSchluessel('schueler-').first);
    await t.pumpAndSettle();
    await t.tap(mitSchluessel('ergebnis-').first);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ergebnis-summe')), findsOneWidget);
    expect(find.textContaining('Lösung:'), findsWidgets);
  });

  testWidgets('PDF: Blätter pro Gruppe mit Lösungen, Copyright und SRDP-Kennzeichnung', (t) async {
    final alle = <String, StoreAufgabe>{};
    for (final (id, herkunft) in [('t1', 'team'), ('s1', 'srdp')]) {
      final inhalt = <String, dynamic>{
        'id': id,
        'titel': 'Titel $id',
        'herkunft': herkunft,
        'stamm': 'Stamm',
        'externe_referenzen': [
          if (herkunft == 'srdp') {'quelle': 'srdp', 'id': 'AG 1.1 – 123'},
        ],
        'items': [
          {
            'item_id': '$id-1',
            'aufgabenstellung': 'Kreuze an: x ∈ ℕ?',
            'kompetenz': 'ag-x',
            'antwortformat': 'mc_1aus5',
            'antwort': {
              'optionen': ['a', 'b', 'c', 'd', 'e'],
              'richtig': 1,
            },
            'punkteschema': '0/1',
            'loesungsweg': ['Weil.'],
            'hilfen': [],
            'schwierigkeit_start': 2,
          },
        ],
      };
      alle[id] = StoreAufgabe.aus(id, inhalt, fassung: 1, status: 'live');
    }
    final p = Paket(id: 'p', titel: 'Test', erstellt: DateTime(2026))
      ..plaetze.addAll([PaketPlatz.von(alle['t1']!), PaketPlatz.von(alle['s1']!)])
      ..gruppenPlaetze['B'] = [
        const GruppenPlatz(aufgabe: 's1', fassung: 1, art: GruppenArt.ersatz),
        const GruppenPlatz(aufgabe: 't1', fassung: 1, art: GruppenArt.ersatz),
      ];
    final b = paketBlaetter(p, alle, gruppen: ['A', 'B'], mitLoesungen: true);
    expect([for (final x in b) '${x.gruppe}${x.loesungen ? 'L' : ''}'], ['A', 'AL', 'B', 'BL']);
    expect(b.first.aufgaben.map((a) => a.srdpKennung), [null, 'AG 1.1 – 123']);
    expect(b.first.hatSrdp, isTrue);
    expect(b.first.aufgaben.first.items.single.loesung, 'b');
    // Gruppe B: Antworten gemischt, die Lösung zieht mit.
    expect(b[2].aufgaben.first.titel, 'Titel s1');
    expect(b[2].aufgaben.first.items.single.loesung, 'b');
    final bytes = await t.runAsync(() => paketPdf(b));
    expect(String.fromCharCodes(bytes!.take(4)), '%PDF');
  });

  testWidgets('Demo: Bereich für Lehrende läuft im Browser und merkt sich alles', (t) async {
    final demo = await t.runAsync(DemoClient.lade);
    final api = Api(basis: 'http://demo.local/api', client: demo!);
    await starteAls(t, api, 'lehrperson-schule', demo: demo);
    await seite(t, 'Aufgaben');
    expect(trefferText(t), '12 Aufgaben');
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('merken-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    // Neuer Client mit demselben Browser-Speicher.
    final wieder = await t.runAsync(DemoClient.lade);
    final api2 = Api(basis: 'http://demo.local/api', client: wieder!)
      ..person = const Person(id: 'lehrperson-schule', name: 'x', lehrperson: true);
    final daten = await t.runAsync(api2.lehrDaten);
    expect(daten!.gemerkt, hasLength(1));
  });
}
