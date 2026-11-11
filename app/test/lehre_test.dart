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

  testWidgets('Präsentations-Zugang: gefüllte Beispielklasse ohne Teststand-Hinweise, Zurücksetzen', (t) async {
    final api = testApi();
    await starteAls(t, api, 'lehrperson-praesentation');
    expect(find.text('Julia Berger'), findsOneWidget);
    expect(find.text('Testmodus'), findsNothing);
    expect(find.byKey(const ValueKey('entwuerfe-zeigen')), findsNothing);
    expect(find.textContaining('Testklasse'), findsNothing);
    expect(find.text('5B'), findsOneWidget);
    expect(find.textContaining('22 Personen'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('klasse-lehrperson-praesentation-5b')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('kompetenzen-kasten')), findsOneWidget);
    expect(find.text('Amelie B.'), findsWidgets);
    expect(find.textContaining('Testklasse'), findsNothing);
    await seite(t, 'Pakete');
    expect(find.text('Wiederholung vor der Schularbeit'), findsWidgets);
    final pakete = (await api.lehrDaten()).pakete.length;
    expect(pakete, greaterThanOrEqualTo(3));

    // Ein Paket löschen und zurücksetzen: der Ausgangsstand ist wieder da.
    final stand = api.person;
    api.person = testPersonen.firstWhere((p) => p.id == praesentationPersonId);
    final d = await api.lehrDaten();
    d.pakete.removeLast();
    await api.speichereLehrDaten(d);
    api.person = stand;
    await t.tap(find.byKey(const ValueKey('praesentation-zuruecksetzen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('praesentation-zuruecksetzen-ja')));
    await t.pumpAndSettle();
    expect((await api.lehrDaten()).pakete.length, pakete);

    // Die anderen Lehrpersonen sehen weiter die leere Testklasse.
    await t.tap(find.text('Wechseln'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('person-lehrperson-schule')));
    await t.pumpAndSettle();
    expect(find.text('Testklasse'), findsWidgets);
    expect(find.text('Testmodus'), findsOneWidget);
    expect((await api.lehrDaten()).pakete, isEmpty);
  });

  testWidgets('Katalog: filtern, zählen, merken, ins Paket', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    await seite(t, 'Katalog');
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
    await t.tap(find.byKey(const ValueKey('paket-erstellen')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('neues-paket-name')), 'Generiertes Paket');
    await t.tap(find.byKey(const ValueKey('neues-paket-generator')));
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
    // Standard ist eine Gruppe, mehr lassen sich dazunehmen (A, B, C ...).
    expect(find.text('1 Gruppe'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byKey(const ValueKey('gruppen-mehr')));
      await t.pumpAndSettle();
    }
    expect(find.text('5 Gruppen'), findsOneWidget);
    expect(find.byKey(const ValueKey('zelle-E-4')), findsOneWidget);

    // Aus dem Editor heraus wird nicht zugewiesen.
    expect(find.byKey(const ValueKey('paket-zuweisen')), findsNothing);
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();
    expect(find.textContaining('5 Gruppen'), findsOneWidget);

    // Zuweisen über die Paketliste: Klassenbaum, Abgabe, Überprüfen, Senden.
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('paket-zuweisen-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('zuweisen-pruefen')), findsOneWidget);
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('baum-alle-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-pruefen')));
    await t.pumpAndSettle();
    expect(find.text('Überprüfen und senden'), findsOneWidget);
    expect(find.textContaining('Testklasse ('), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('zuweisen-senden')));
    await t.pumpAndSettle();
    expect(find.textContaining('verschickt'), findsWidgets);
    expect(find.textContaining('zugewiesen: Testklasse'), findsOneWidget);
  });

  testWidgets('Paket-Code: eine andere Lehrperson holt eine Kopie', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-erstellen')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('neues-paket-name')), 'Generiertes Paket');
    await t.tap(find.byKey(const ValueKey('neues-paket-generator')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    final chip = t.widget<ActionChip>(find.byKey(const ValueKey('paket-code')));
    final code = (chip.label as Text).data!;
    expect(code, startsWith('TUTO-'));
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();
    await t.tap(find.text('Wechseln'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('person-lehrperson-nachhilfe')));
    await t.pumpAndSettle();
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-per-code')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('text-dialog-feld')), code.toLowerCase());
    await t.tap(find.byKey(const ValueKey('text-dialog-ok')));
    await t.pumpAndSettle();
    expect(find.textContaining('als eigene Kopie übernommen'), findsOneWidget);
    expect(find.byKey(const ValueKey('generieren')), findsOneWidget);
    expect((t.widget<ActionChip>(find.byKey(const ValueKey('paket-code'))).label as Text).data, isNot(code));
  });

  Finder mitSchluessel(String anfang) =>
      find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(anfang));

  testWidgets('Testklasse: zuweisen, in der Schüler*innen-Ansicht lösen, Antworten und Lernstand sehen', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    expect(find.text('Testklasse'), findsOneWidget);
    expect(mitSchluessel('klasse-'), findsNWidgets(1));

    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-erstellen')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('neues-paket-name')), 'Generiertes Paket');
    await t.tap(find.byKey(const ValueKey('neues-paket-generator')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paket-zurueck')));
    await t.pumpAndSettle();

    await seite(t, 'Klassen');
    await t.tap(mitSchluessel('klasse-lehrperson').first);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('kompetenzen-leer')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('klasse-zuweisen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-eigenes')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-paket')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Generiertes Paket').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-pruefen')));
    await t.pumpAndSettle();
    expect(find.textContaining('Testklasse (3)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('zuweisen-senden')));
    await t.pumpAndSettle();
    expect(find.textContaining('0/3 fertig'), findsOneWidget);

    // Als "Du" in der Schüler*innen-Ansicht lösen.
    await t.tap(find.byKey(const ValueKey('klasse-schueler-ansicht')));
    await t.pumpAndSettle();
    expect(find.text('Test-Insel · Gamification aus'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('postfach')));
    await t.pumpAndSettle();
    await t.tap(mitSchluessel('post-').first);
    await t.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await t.tap(find.byKey(const ValueKey('weiss-nicht')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('weiter')));
      await t.pumpAndSettle();
    }
    expect(find.text('0 von 5 richtig'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ansicht-zurueck')));
    await t.pumpAndSettle();

    // Die Klasse zeigt jetzt echten Stand und eine Förderempfehlung.
    expect(find.textContaining('1/3 fertig'), findsOneWidget);
    expect(find.byKey(const ValueKey('kompetenzen-kasten')), findsOneWidget);
    await t.tap(mitSchluessel('zuweisung-paket').first);
    await t.pumpAndSettle();
    expect(find.text('1 von 3 fertig'), findsOneWidget);
    await t.tap(mitSchluessel('zuweisung-person-').first);
    await t.pumpAndSettle();
    expect(find.text('0 von 5 richtig'), findsOneWidget);
    expect(find.textContaining('Weiß ich nicht'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('ergebnis-zurueck')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisung-zurueck')));
    await t.pumpAndSettle();

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
    expect(find.textContaining('für 1 Person der Testklasse'), findsOneWidget);
  });

  testWidgets('Paket erstellen: Name und Weg wählen, Generator per Menü, Speichern, Filter', (t) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-erstellen')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('neues-paket-name')), 'Bruchrechnen');
    await t.tap(find.byKey(const ValueKey('neues-paket-selbst')));
    await t.pumpAndSettle();
    // Selbst zusammenstellen: kein Generator, keine Schüler*innen-Auswahl.
    expect(find.byKey(const ValueKey('generieren')), findsNothing);
    expect(find.byKey(const ValueKey('tab-schueler')), findsNothing);
    await t.tap(find.byKey(const ValueKey('paket-menue')));
    await t.pumpAndSettle();
    await t.tap(find.text('Generator einblenden'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('generieren')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    // Mit dem Katalog verbinden zeigt das deutlich an.
    await t.tap(find.byKey(const ValueKey('als-warenkorb')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('katalog-hinweis')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('paket-speichern')));
    await t.pumpAndSettle();
    expect(find.textContaining('gespeichert'), findsOneWidget);
    expect(find.text('mit Katalog verbunden'), findsOneWidget);
    expect(find.text('Eigene (1)'), findsOneWidget);
    expect(find.text('Förderpakete (0)'), findsOneWidget);
    await t.tap(find.text('Förderpakete (0)'));
    await t.pumpAndSettle();
    expect(find.text('Keine Pakete in dieser Auswahl.'), findsOneWidget);
  });

  testWidgets('Emulator: selbst kontrollierte Aufgabe blockiert nicht, Eingabe ist für die Lehrperson sichtbar', (
    t,
  ) async {
    await starteAls(t, testApi(), 'lehrperson-schule');
    await seite(t, 'Pakete');
    await t.tap(find.byKey(const ValueKey('paket-erstellen')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('neues-paket-name')), 'Offen');
    await t.tap(find.byKey(const ValueKey('neues-paket-selbst')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('aufgabe-hinzufuegen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('wahl-alle')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('wahl-suche')), 'tuto-ag5-01-a03');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('waehlen-tuto-ag5-01-a03')).last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paket-speichern')));
    await t.pumpAndSettle();

    await seite(t, 'Klassen');
    await t.tap(mitSchluessel('klasse-lehrperson').first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('klasse-zuweisen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-eigenes')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-paket')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Offen ·').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-pruefen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zuweisen-senden')));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('klasse-schueler-ansicht')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('postfach')));
    await t.pumpAndSettle();
    await t.tap(mitSchluessel('post-').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'irrational');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('loesung-ansehen')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('musterloesung')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('selbst-Richtig')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('weiter')));
    await t.pumpAndSettle();
    expect(find.text('1 von 1 richtig'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ansicht-zurueck')));
    await t.pumpAndSettle();

    await t.tap(mitSchluessel('zuweisung-paket').first);
    await t.pumpAndSettle();
    expect(find.text('Gruppe A'), findsNothing);
    expect(find.textContaining('alle dieselben Aufgaben'), findsOneWidget);
    await t.tap(mitSchluessel('zuweisung-person-').first);
    await t.pumpAndSettle();
    expect(find.textContaining('irrational (selbst bewertet: richtig)'), findsOneWidget);
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
    final p = Paket(id: 'p', titel: 'Test', erstellt: DateTime(2026), gruppen: 2)
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
    await seite(t, 'Katalog');
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
