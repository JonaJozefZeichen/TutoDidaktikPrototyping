import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await t.scrollUntilVisible(find.text('Falsche Antwort 2'), 300, scrollable: find.byType(Scrollable).last);
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/editor_slots.png'));
    await t.tap(find.byTooltip('Im Bauplan nachsehen: titel'));
    await t.pumpAndSettle();
    await expectLater(find.byType(DidaktikApp), matchesGoldenFile('bilder/editor_hilfe.png'));
  });
}
