import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuto_didaktik/api.dart';
import 'package:tuto_didaktik/demo.dart';
import 'package:tuto_didaktik/hilfe.dart';
import 'package:tuto_didaktik/main.dart';

const id = 'tuto-ag5-01-a01';

Future<(Api, DemoClient)> starteDemo() async {
  final demo = await DemoClient.lade();
  return (Api(basis: 'http://demo.local/api', client: demo), demo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('der Leitfaden liegt bei der Website und der Link zeigt darauf', () {
    expect(File('web/$leitfadenPfad').existsSync(), isTrue);
    final seite = Uri.parse('https://x.github.io/Repo/#/');
    expect(seite.removeFragment().resolve(leitfadenPfad).toString(), 'https://x.github.io/Repo/$leitfadenPfad');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Demo enthält genau die 12 Beispielaufgaben', () async {
    final (api, _) = await starteDemo();
    final personen = await api.personen();
    api.person = personen.first;
    final zeilen = await api.aufgaben();
    expect(zeilen, hasLength(12));
    expect(zeilen.every((z) => z['status'] == 'entwurf' && z['fehler'] == 0), isTrue);
    final stamm = await api.stammdaten();
    expect(stamm.levels.length, lessThan(13));
  });

  test('zwei Approvals, Regeln wie am Server, Stand übersteht einen Neustart', () async {
    var (api, demo) = await starteDemo();
    final personen = await api.personen();
    api.person = personen[0];
    expect((await api.approval(id, 1)).eintrag.status, 'geprueft');
    await expectLater(api.approval(id, 1), throwsA(isA<ApiFehler>().having((e) => e.code, 'code', 'doppelt')));
    api.person = personen[2];
    await expectLater(api.approval(id, 1), throwsA(isA<ApiFehler>().having((e) => e.status, 'status', 403)));
    api.person = personen[1];
    expect((await api.approval(id, 1)).eintrag.status, 'live');
    await Future<void>.delayed(Duration.zero);

    (api, demo) = await starteDemo();
    api.person = personen[0];
    expect((await api.aufgabe(id)).eintrag.status, 'live');

    await demo.zuruecksetzen();
    expect((await api.aufgabe(id)).eintrag.status, 'entwurf');
    (api, demo) = await starteDemo();
    api.person = personen[0];
    expect((await api.aufgabe(id)).eintrag.status, 'entwurf');
  });

  test('kaputter Stand im Browser blockiert die Demo nicht', () async {
    SharedPreferences.setMockInitialValues({'didaktik_demo_stand': '{kaputt'});
    final (api, _) = await starteDemo();
    api.person = (await api.personen()).first;
    expect(await api.aufgaben(), hasLength(12));
  });

  testWidgets('Demo zeigt den Hinweis und lässt sich zurücksetzen', (t) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Assets laden braucht echte Zeit, nicht die gefälschte Uhr des Widget-Tests.
    final (api, demo) = (await t.runAsync(starteDemo))!;
    await t.pumpWidget(DidaktikApp(api: api, demo: demo));
    await t.pumpAndSettle();
    expect(find.textContaining('Demo mit Beispielaufgaben'), findsOneWidget);
    await t.tap(find.textContaining('Test-Didaktik A'));
    await t.pumpAndSettle();
    expect(find.text('Demo · Änderungen nur in diesem Browser'), findsOneWidget);
    expect(find.text('Zu prüfen (12)'), findsOneWidget);
    expect(find.byKey(const ValueKey('leitfaden-knopf')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('demo-zuruecksetzen')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Zurücksetzen'));
    await t.pumpAndSettle();
    expect(find.text('Zu prüfen (12)'), findsOneWidget);
  });
}
