import 'dart:convert';
import 'dart:io';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/main.dart';

import 'hilfsmittel.dart';

Future<void> starte(WidgetTester t, Api api, {String person = 'Test-Didaktik A'}) async {
  t.view.physicalSize = const Size(1600, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(DidaktikApp(api: api));
  await t.pumpAndSettle();
  await t.tap(find.textContaining(person));
  await t.pumpAndSettle();
}

Future<void> oeffneListe(WidgetTester t) async {
  await t.tap(find.text('Aufgaben').first);
  await t.pumpAndSettle();
}

Future<void> oeffneAufgabe(WidgetTester t, String id) async {
  await oeffneListe(t);
  await t.enterText(find.byKey(const ValueKey('aufgaben-suche')), id);
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(InkWell, id));
  await t.pumpAndSettle();
}

Future<void> wechslePerson(WidgetTester t, String person) async {
  await t.tap(find.byTooltip('Zurück'));
  await t.pumpAndSettle();
  await t.tap(find.text('Wechseln'));
  await t.pumpAndSettle();
  await t.tap(find.textContaining(person));
  await t.pumpAndSettle();
}

FilledButton knopf(WidgetTester t, String key) => t.widget<FilledButton>(find.byKey(ValueKey(key)));

const id = 'tuto-ag5-01-a01';

void main() {
  test('jedes Feld mit "?" hat einen Treffer im Bauplan', () {
    final bauplan = File('assets/hilfe/bauplan.md').readAsStringSync().toLowerCase();
    final fehlend = [
      for (final f in [...aufgabeFelder, ...itemFelder])
        if (!bauplan.contains(hilfeBegriffFuer(f.key).toLowerCase())) f.key,
    ];
    expect(fehlend, isEmpty);
  });

  test('Adresse des Servers', () {
    expect(Api.ausAdresse(Uri.parse('http://127.0.0.1:8787/')).basis, 'http://127.0.0.1:8787/api');
    expect(Api.ausAdresse(Uri.parse('http://localhost:8788/#/')).basis, 'http://localhost:8787/api');
  });

  testWidgets('Übersicht zeigt den Startbestand', (t) async {
    await starte(t, testApi());
    expect(find.text('Zu prüfen ($aufgabenZahl)'), findsOneWidget);
    expect(find.text('Testmodus'), findsOneWidget);
  });

  testWidgets('Filter in der Liste', (t) async {
    await starte(t, testApi());
    await oeffneListe(t);
    expect(find.text('$aufgabenZahl von $aufgabenZahl Aufgaben'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('aufgaben-suche')), id);
    await t.pumpAndSettle();
    expect(find.textContaining('1 von $aufgabenZahl'), findsOneWidget);
  });

  testWidgets('voller Ablauf: bearbeiten, zwei Approvals, Korrektur, zurückziehen', (t) async {
    final api = testApi();
    await starte(t, api);
    await oeffneAufgabe(t, id);
    expect(knopf(t, 'speichern').onPressed, isNull);

    // Titel ändern: Vorschau folgt sofort, Approval ist bis zum Speichern gesperrt.
    await t.enterText(find.byType(TextField).first, 'Neuer Titel');
    await t.pumpAndSettle();
    expect(find.text('Nicht gespeichert'), findsOneWidget);
    expect(find.text('Neuer Titel'), findsWidgets);
    expect(knopf(t, 'approval').onPressed, isNull);

    await t.tap(find.byKey(const ValueKey('speichern')));
    await t.pumpAndSettle();
    expect(find.text('Fassung 2'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('approval')));
    await t.pumpAndSettle();
    final nach1 = await api.aufgabe(id);
    expect(nach1.eintrag.status, 'geprueft');
    expect(nach1.eintrag.aktuell.approvals.single.person, 'didaktik-a');

    // Der Editor geht zur nächsten Aufgabe; zweites Approval von Person B.
    await wechslePerson(t, 'Test-Didaktik B');
    expect(find.text('Wartet auf dein Approval (1)'), findsOneWidget);
    await oeffneAufgabe(t, id);
    await t.tap(find.byKey(const ValueKey('approval')));
    await t.pumpAndSettle();
    expect((await api.aufgabe(id)).eintrag.status, 'live');

    // Korrektur: live bleibt die alte Fassung.
    await oeffneAufgabeNeu(t, id);
    await t.enterText(find.byType(TextField).first, 'Korrektur');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('speichern')));
    await t.pumpAndSettle();
    expect(find.text('Neue Fassung speichern?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Speichern').last);
    await t.pumpAndSettle();
    expect(find.text('Live, Korrektur 0/2'), findsOneWidget);
    final k = (await api.aufgabe(id)).eintrag;
    expect(k.liveInhalt!['titel'], 'Neuer Titel');

    // Zurückziehen und wieder aufnehmen.
    await t.tap(find.byKey(const ValueKey('zurueckziehen')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Zurückziehen'));
    await t.pumpAndSettle();
    expect((await api.aufgabe(id)).eintrag.status, 'zurueckgezogen');
    expect(find.text('Zurückgezogen'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('wiederaufnehmen')));
    await t.pumpAndSettle();
    expect((await api.aufgabe(id)).eintrag.status, 'entwurf');
  });

  testWidgets('Fehler stehen am Feld und sperren das Approval', (t) async {
    await starte(t, testApi());
    await oeffneAufgabe(t, id);
    await t.enterText(find.byType(TextField).first, '');
    await t.pumpAndSettle();
    expect(find.text('Titel fehlt'), findsNWidgets(2)); // am Feld und in der Fehlerliste
    expect(find.textContaining(' Fehler'), findsWidgets);
    expect(knopf(t, 'approval').onPressed, isNull);
  });

  testWidgets('Warnung bei ungespeicherten Änderungen', (t) async {
    await starte(t, testApi());
    await oeffneAufgabe(t, id);
    await t.enterText(find.byType(TextField).first, 'Ungespeichert');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Zurück'));
    await t.pumpAndSettle();
    expect(find.text('Ungespeicherte Änderungen'), findsOneWidget);
    await t.tap(find.text('Verwerfen'));
    await t.pumpAndSettle();
    expect(find.text('$aufgabenZahl von $aufgabenZahl Aufgaben'), findsNothing);
    expect(find.textContaining('von $aufgabenZahl Aufgaben'), findsOneWidget);
  });

  testWidgets('Konflikt: zwei Personen an derselben Aufgabe', (t) async {
    final api = testApi();
    await starte(t, api);
    await oeffneAufgabe(t, id);
    await t.enterText(find.byType(TextField).first, 'Von A');
    await t.pumpAndSettle();
    // Während A tippt, speichert jemand anderes.
    api.person = const Person(id: 'didaktik-b', name: 'B', didaktik: true);
    final stand = (await api.aufgabe(id)).eintrag.aktuell;
    await api.speichere(id, {...stand.inhalt, 'titel': 'Von B'}, basis: stand.nr);
    api.person = const Person(id: 'didaktik-a', name: 'A', didaktik: true);
    await t.tap(find.byKey(const ValueKey('speichern')));
    await t.pumpAndSettle();
    expect(find.text('Jemand war schneller'), findsOneWidget);
    await t.tap(find.text('Trotzdem speichern'));
    await t.pumpAndSettle();
    expect((await api.aufgabe(id)).eintrag.aktuell.inhalt['titel'], 'Von A');
  });

  testWidgets('Antwort testen nutzt die Prüfung der App', (t) async {
    await starte(t, testApi());
    await oeffneAufgabe(t, id);
    // Richtig ist √3 in den Optionen von tuto-ag5-01-a01.
    await t.ensureVisible(find.text('√3').first);
    await t.tap(find.text('√3').first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('antwort-testen')));
    await t.pumpAndSettle();
    expect(find.textContaining('gilt als richtig'), findsOneWidget);
  });

  group('Antwort-Slots', () {
    Map<String, dynamic> antwortVon(Eintrag e) => (e.aktuell.inhalt['items'] as List).first as Map<String, dynamic>;

    testWidgets('Öffnen ändert nichts, richtige Antwort steht zuerst', (t) async {
      await starte(t, testApi());
      await oeffneAufgabe(t, id);
      expect(find.text('Nicht gespeichert'), findsNothing);
      await t.scrollUntilVisible(find.text('Richtige Antwort'), 300, scrollable: find.byType(Scrollable).last);
      final richtig = t.getTopLeft(find.text('Richtige Antwort'));
      final falsch = t.getTopLeft(find.text('Falsche Antwort 1'));
      expect(richtig.dy, lessThan(falsch.dy));
      expect(find.text('Falsche Antwort 5'), findsOneWidget); // mc_1aus6
      expect(find.text('Nicht gespeichert'), findsNothing);
    });

    testWidgets('Fehlerbild landet beim richtigen Schlüssel und wird beim Testen gezeigt', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, id);
      await t.scrollUntilVisible(find.text('Falsche Antwort 1'), 300, scrollable: find.byType(Scrollable).last);
      // Erste falsche Option von a01 ist 7/8 (Index 0), richtig ist Index 3.
      await t.enterText(find.widgetWithText(TextField, 'Fehlerbild, z. B. vorzeichenfehler').first, 'bruch_ist_irrational');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      expect(antwortVon((await api.aufgabe(id)).eintrag)['fehlerbilder'], {'0': 'bruch_ist_irrational'});
      await t.tap(find.text('7/8').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('antwort-testen')));
      await t.pumpAndSettle();
      expect(find.textContaining('Fehlerbild: bruch_ist_irrational'), findsOneWidget);
    });

    testWidgets('"Das ist richtig" tauscht die Rollen und löscht das Fehlerbild', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, id);
      await t.scrollUntilVisible(find.text('Falsche Antwort 1'), 300, scrollable: find.byType(Scrollable).last);
      await t.enterText(find.widgetWithText(TextField, 'Fehlerbild, z. B. vorzeichenfehler').first, 'x');
      await t.pumpAndSettle();
      await t.tap(find.text('Das ist richtig').first);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      final item = antwortVon((await api.aufgabe(id)).eintrag);
      expect((item['antwort'] as Map)['richtig'], 0);
      expect(item['fehlerbilder'], isEmpty);
    });

    testWidgets('freie Zeilen: Zahl mit Komma, neue Zeile erscheint, Fehlerbild an richtigem Wert wird gemeldet', (t) async {
      final api = testApi();
      await starte(t, api);
      final aufgaben = (jsonDecode(File('${datenPfad.path}/aufgaben.json').readAsStringSync()) as Map)['aufgaben'] as List;
      final a = aufgaben.firstWhere((x) => x['items'][0]['antwortformat'] == 'offen_zahl') as Map;
      final aid = a['id'] as String;
      await oeffneAufgabe(t, aid);
      await t.scrollUntilVisible(find.text('Falsche Antwort 1'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Falsche Antwort 2'), findsNothing);
      await t.enterText(find.widgetWithText(TextField, '16').first, '6,25');
      await t.pumpAndSettle();
      expect(find.text('Wird erst mit beiden Angaben gespeichert.'), findsOneWidget);
      expect(find.text('Falsche Antwort 2'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Fehlerbild, z. B. vorzeichenfehler').first, 'prozent_vergessen');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      expect(antwortVon((await api.aufgabe(aid)).eintrag)['fehlerbilder'], {'6.25': 'prozent_vergessen'});
    });

    testWidgets('selbst bewertete Formate haben keine falschen Slots', (t) async {
      await starte(t, testApi());
      final aufgaben = (jsonDecode(File('${datenPfad.path}/aufgaben.json').readAsStringSync()) as Map)['aufgaben'] as List;
      final a = aufgaben.firstWhere((x) => x['items'][0]['antwortformat'] == 'offen_text') as Map;
      await oeffneAufgabe(t, a['id'] as String);
      await t.scrollUntilVisible(find.textContaining('bewerten die Lernenden selbst, deshalb'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Falsche Antwort 1'), findsNothing);
    });
  });

  testWidgets('Hilfe öffnet sich vom Feld aus mit Suche', (t) async {
    await starte(t, testApi());
    await oeffneAufgabe(t, id);
    await t.tap(find.byTooltip('Im Bauplan nachsehen: titel'));
    await t.pumpAndSettle();
    expect(find.text('Hilfe: Bauplan für Aufgaben'), findsOneWidget);
    expect(find.text('Eine Aufgabe anlegen'), findsOneWidget);
  });

  testWidgets('Import: Bericht mit Konflikt und neuer Aufgabe', (t) async {
    final api = testApi();
    await starte(t, api);
    await t.tap(find.text('Import').first);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('import-text')),
      jsonEncode({
        'quelle': 'Test',
        'aufgaben': [
          {'id': id},
          {'id': 'neu-1', 'titel': 'Neu'},
        ],
      }),
    );
    await t.tap(find.text('Eingefügtes JSON importieren'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 übernommen'), findsOneWidget);
    expect(find.textContaining('1 nicht übernommen'), findsOneWidget);
    await t.tap(find.text('Zu den Entwürfen'));
    await t.pumpAndSettle();
    expect(find.text('${aufgabenZahl + 1} von ${aufgabenZahl + 1} Aufgaben (gefiltert)'), findsOneWidget);
  });

  testWidgets('jedes Antwortformat lässt sich öffnen, ohne dass etwas überläuft', (t) async {
    final api = testApi();
    await starte(t, api);
    final aufgaben = (jsonDecode(File('${datenPfad.path}/aufgaben.json').readAsStringSync()) as Map)['aufgaben'] as List;
    final proFormat = <String, String>{};
    for (final a in aufgaben) {
      proFormat.putIfAbsent(a['items'][0]['antwortformat'] as String, () => a['id'] as String);
    }
    expect(proFormat, hasLength(9));
    for (final aid in proFormat.values) {
      await oeffneAufgabe(t, aid);
      expect(find.byKey(const ValueKey('approval')), findsOneWidget);
      await t.tap(find.byTooltip('Zurück'));
      await t.pumpAndSettle();
    }
  });
}

Future<void> oeffneAufgabeNeu(WidgetTester t, String id) async {
  // Nach dem Approval steht der Editor auf der nächsten Aufgabe.
  await t.tap(find.byTooltip('Zurück'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const ValueKey('aufgaben-suche')), id);
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(InkWell, id));
  await t.pumpAndSettle();
}
