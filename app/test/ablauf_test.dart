import 'dart:convert';
import 'dart:io';

import 'package:didaktik_kern/didaktik_kern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/editor/bausteine.dart';
import 'package:tuto_didaktik/main.dart';
import 'package:tuto_didaktik/seiten/aufgaben.dart';

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

  testWidgets('Ungespeicherte Änderungen lassen sich beim Verlassen speichern', (t) async {
    final api = testApi();
    await starte(t, api);
    await oeffneAufgabe(t, id);
    await t.enterText(find.byType(TextField).first, 'Beim Verlassen gespeichert');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Zurück'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('verlassen-speichern')));
    await t.pumpAndSettle();
    expect(find.textContaining('von $aufgabenZahl Aufgaben'), findsOneWidget); // Liste ist wieder da
    expect((await api.aufgabe(id)).eintrag.aktuell.inhalt['titel'], 'Beim Verlassen gespeichert');
  });

  testWidgets('Approval zurücknehmen macht aus Geprüft wieder Entwurf', (t) async {
    final api = testApi();
    await starte(t, api);
    await oeffneAufgabe(t, id);
    // Nach dem Approval nicht weiterspringen, damit dieselbe Aufgabe offen bleibt.
    await t.tap(
      find.descendant(
        of: find.ancestor(of: find.text('Nach Approval zur nächsten'), matching: find.byType(Row)).first,
        matching: find.byType(Checkbox),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('approval')));
    await t.pumpAndSettle();
    expect((await api.aufgabe(id)).eintrag.status, 'geprueft');
    await t.tap(find.byKey(const ValueKey('approval-zuruecknehmen')));
    await t.pumpAndSettle();
    final e = (await api.aufgabe(id)).eintrag;
    expect(e.status, 'entwurf');
    expect(e.aktuell.approvals, isEmpty);
    expect(knopf(t, 'approval').onPressed, isNotNull);
  });

  testWidgets('Aufgabenliste sortiert nach Spalten und zeigt lesbare Typen', (t) async {
    await starte(t, testApi());
    await oeffneListe(t);
    expect(find.text('1 aus 6'), findsWidgets);
    expect(find.text('mc_1aus6'), findsNothing);
    List<String> titel() => [
      for (final w in t.widgetList<Text>(
        find.descendant(of: find.byType(AufgabenZeile), matching: find.byType(Text)),
      ))
        if (w.style == null) w.data ?? '',
    ];
    await t.tap(find.byKey(const ValueKey('sortiere-titel')));
    await t.pumpAndSettle();
    final auf = titel();
    expect(auf, [...auf]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
    await t.tap(find.byKey(const ValueKey('sortiere-titel')));
    await t.pumpAndSettle();
    expect(titel(), auf.reversed.toList());
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

    const a01 = id; // mc_1aus6, richtig ist Index 3 (√3)
    const a02 = 'tuto-ag5-01-a02'; // mc_2aus5, richtig sind 0 und 1
    final fehlerbildFeld = find.widgetWithText(TextField, 'Fehlerbild, z. B. vorzeichenfehler');

    Future<void> zeigeAntworten(WidgetTester t) async {
      await t.scrollUntilVisible(find.text('Antwort 1'), 300, scrollable: find.byType(Scrollable).last);
      await t.pumpAndSettle();
    }

    Future<void> wechsleFormat(WidgetTester t, String von, String nach) async {
      final feld = find.descendant(of: find.byType(WahlFeld), matching: find.text(von));
      await t.ensureVisible(feld.first);
      await t.pumpAndSettle();
      await t.tap(feld.first);
      await t.pumpAndSettle();
      await t.tap(find.text(nach).last);
      await t.pumpAndSettle();
    }

    Future<void> haken(WidgetTester t, int i) async {
      await t.ensureVisible(find.byKey(ValueKey('richtig-$i')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('richtig-$i')));
      await t.pumpAndSettle();
    }

    testWidgets('Öffnen ändert nichts, falsche Antworten haben ein Fehlerbild-Feld, die richtige nicht', (t) async {
      await starte(t, testApi());
      await oeffneAufgabe(t, a01);
      await zeigeAntworten(t);
      expect(find.text('Nicht gespeichert'), findsNothing);
      expect(find.text('Antwort 6'), findsOneWidget);
      expect(fehlerbildFeld, findsNWidgets(5));
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-3'))).value, isTrue);
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-0'))).value, isFalse);
    });

    testWidgets('2 aus 5 auf 1 aus 6 behält alles, meldet zu viele und sperrt das Approval', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, a02);
      await zeigeAntworten(t);
      final vorher = ((antwortVon((await api.aufgabe(a02)).eintrag)['antwort'] as Map)['optionen'] as List).cast<String>();
      await wechsleFormat(t, 'mc_2aus5', 'mc_1aus6');
      for (final o in vorher) {
        expect(find.widgetWithText(TextField, o), findsOneWidget, reason: o);
      }
      expect(find.textContaining('Zu viele richtige Antworten: 2 markiert'), findsWidgets);
      expect(find.textContaining('Antwort 6 ist leer'), findsWidgets);
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-0'))).value, isTrue);
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-1'))).value, isTrue);
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      expect(knopf(t, 'approval').onPressed, isNull);
      expect((await api.aufgabe(a02)).eintrag.aktuell.nr, 2); // speichern geht, freigeben nicht

      // Markierung entfernen und den leeren Slot füllen hebt die Sperre auf.
      await haken(t, 1);
      await t.enterText(find.widgetWithText(TextField, 'Text eingeben').last, 'Neue Antwort');
      await t.pumpAndSettle();
      expect(find.textContaining('Zu viele richtige'), findsNothing);
      expect(find.textContaining(RegExp(r'^\d+ Fehler')), findsNothing);
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      expect(knopf(t, 'approval').onPressed, isNotNull);
      final item = antwortVon((await api.aufgabe(a02)).eintrag);
      expect((item['antwort'] as Map)['richtig'], 0);
      expect((item['antwort'] as Map)['optionen'], hasLength(6));
    });

    testWidgets('1 aus 6 auf 2 aus 5 meldet zu wenige und zu viele, Entfernen rückt alles nach', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, a01);
      await zeigeAntworten(t);
      // Fehlerbild an Index 4 (0,75), danach Index 0 entfernen: wird zu Index 3.
      await t.enterText(fehlerbildFeld.at(3), 'zahl_x');
      await t.pumpAndSettle();
      await wechsleFormat(t, 'mc_1aus6', 'mc_2aus5');
      expect(find.textContaining('Zu wenige richtige Antworten: 1 markiert'), findsWidgets);
      expect(find.textContaining('Zu viele Antworten: 6'), findsWidgets);
      await t.ensureVisible(find.byTooltip('Antwort entfernen').first);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Antwort entfernen').first);
      await t.pumpAndSettle();
      expect(find.textContaining('Zu viele Antworten'), findsNothing);
      await haken(t, 0);
      expect(find.textContaining(RegExp(r'^\d+ Fehler')), findsNothing);
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      final item = antwortVon((await api.aufgabe(a01)).eintrag);
      expect((item['antwort'] as Map)['richtig'], [0, 2]); // √3 war Index 3, jetzt 2
      expect(item['fehlerbilder'], {'3': 'zahl_x'});
    });

    testWidgets('Häkchen blendet das Fehlerbild-Feld aus, löscht den Wert und springt bei 1 aus', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, a01);
      await zeigeAntworten(t);
      await t.enterText(fehlerbildFeld.first, 'x');
      await t.pumpAndSettle();
      await haken(t, 0);
      expect(fehlerbildFeld, findsNWidgets(5));
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-3'))).value, isFalse);
      await t.tap(find.byKey(const ValueKey('speichern')));
      await t.pumpAndSettle();
      final item = antwortVon((await api.aufgabe(a01)).eintrag);
      expect((item['antwort'] as Map)['richtig'], 0);
      expect(item['fehlerbilder'], isEmpty);
    });

    testWidgets('Wechsel auf offene Zahl und zurück bringt Antworten und Fehlerbilder wieder', (t) async {
      await starte(t, testApi());
      await oeffneAufgabe(t, a01);
      await zeigeAntworten(t);
      await wechsleFormat(t, 'mc_1aus6', 'offen_zahl');
      expect(find.text('Antwort 1'), findsNothing);
      expect(find.text('Richtiger Wert'), findsOneWidget);
      await wechsleFormat(t, 'offen_zahl', 'mc_1aus6');
      expect(find.widgetWithText(TextField, '7/8'), findsOneWidget);
      expect(t.widget<Checkbox>(find.byKey(const ValueKey('richtig-3'))).value, isTrue);
      expect(find.text('Nicht gespeichert'), findsNothing);
    });

    testWidgets('Fehlerbild landet beim richtigen Schlüssel und wird beim Testen gezeigt', (t) async {
      final api = testApi();
      await starte(t, api);
      await oeffneAufgabe(t, id);
      await zeigeAntworten(t);
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
