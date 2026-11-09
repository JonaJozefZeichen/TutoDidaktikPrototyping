import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuto_didaktik/lehre/paket_editor.dart';
import 'package:tuto_didaktik/lehre/zustand.dart';
import 'package:tuto_didaktik/main.dart';

import 'hilfsmittel.dart';

/// Erzeugt Bilder der wichtigsten Seiten zum Ansehen:
/// flutter test test/bilder_test.dart --update-goldens
void main() {
  // Die Bilder zeigen Aufgabentexte und liegen deshalb nur lokal.
  final bilderDa = Directory('test/bilder').existsSync() || autoUpdateGoldenFiles;
  testWidgets('Bilder', skip: !bilderDa, (t) async {
    await ladeSchriften();
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(DidaktikApp(api: testApi()));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/anmelden.png'));
    await t.tap(find.textContaining('Test-Didaktik A'));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/uebersicht.png'));
    await t.tap(find.text('Aufgaben').first);
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/liste.png'));
    await t.enterText(find.byKey(const ValueKey('aufgaben-suche')), 'tuto-ag5-01-a01');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(InkWell, 'tuto-ag5-01-a01'));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/editor.png'));
    await t.scrollUntilVisible(find.text('Antwort 3'), 300, scrollable: find.byType(Scrollable).last);
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/editor_slots.png'));
    await t.tap(find.byTooltip('Im Bauplan nachsehen: titel'));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/editor_hilfe.png'));
  });

  testWidgets('Bilder Lehrende', skip: !bilderDa, (t) async {
    PaketEditor.zufall = () => Random(1);
    addTearDown(() => PaketEditor.zufall = Random.new);
    var nr = 0;
    final vorher = LehreZustand.idErzeuger;
    LehreZustand.idErzeuger = (art) => '$art-${nr++}';
    addTearDown(() => LehreZustand.idErzeuger = vorher);
    await ladeSchriften();
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(DidaktikApp(api: testApi()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('person-lehrperson-schule')));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_klassen.png'));
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('klasse-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_klasse.png'));
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Aufgaben')));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_store.png'));
    await t.tap(find.byKey(const ValueKey('filter-format-ankreuzen')));
    await t.pumpAndSettle();
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ins-paket-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_store_filter.png'));
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('karte-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_detail.png'));
    await t.pump(const Duration(seconds: 6)); // Meldung ausblenden lassen
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Pakete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('paket-generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('generieren')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('sperren-1')));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_paket.png'));
    await t.tap(find.byKey(const ValueKey('tab-gruppen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('gruppen-mehr')));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_gruppen.png'));
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Klassen')));
    await t.pumpAndSettle();
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('klasse-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('an-alle-senden')));
    await t.pumpAndSettle();
    await t.tap(
      find.byType(SimpleDialogOption).first,
    );
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_klasse_v2.png'));
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('schueler-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(
      find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ergebnis-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/lehre_ergebnis.png'));
  });
}
