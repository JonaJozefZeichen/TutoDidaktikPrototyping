/// Datenmodell des Tools. Die Namen folgen den Tabellen `exercise_revisions`
/// und `exercise_approvals` im Data Dictionary (Vault), auf Deutsch wie die
/// Feldliste.
library;

/// Testperson. Rechte nach der Rollen-Tabelle im Design Document.
class Person {
  const Person({
    required this.id,
    required this.name,
    this.didaktik = false,
    this.admin = false,
    this.lehrperson = false,
  });

  final String id;
  final String name;
  final bool didaktik;
  final bool admin;

  /// Lehrperson an einer Schule oder Nachhilfelehrer\*in von Mindlink: sieht
  /// den Bereich für Lehrende, bearbeitet aber keine Aufgaben.
  final bool lehrperson;

  bool get darfBearbeiten => didaktik || admin;
  bool get darfFreigeben => didaktik;
  bool get darfZurueckziehen => didaktik || admin;
  bool get darfPaketeBauen => lehrperson;

  /// Bereich, den die Oberfläche nach der Anmeldung zeigt.
  bool get istLehrbereich => lehrperson && !didaktik && !admin;

  String get rollenText =>
      [if (didaktik) 'Didaktik', if (admin) 'Admin', if (lehrperson) 'Lehrperson'].join(' + ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'didaktik': didaktik,
    'admin': admin,
    'lehrperson': lehrperson,
  };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: j['id'] as String,
    name: j['name'] as String,
    didaktik: j['didaktik'] as bool? ?? false,
    admin: j['admin'] as bool? ?? false,
    lehrperson: j['lehrperson'] as bool? ?? false,
  );
}

class Approval {
  const Approval({required this.person, required this.am});

  final String person;
  final DateTime am;

  Map<String, dynamic> toJson() => {'person': person, 'am': am.toIso8601String()};

  factory Approval.fromJson(Map<String, dynamic> j) =>
      Approval(person: j['person'] as String, am: DateTime.parse(j['am'] as String));
}

/// Ein Bearbeitungsstand einer Aufgabe. Approvals hängen an der Fassung,
/// deshalb gelten sie nach einer Änderung nicht mehr.
class Fassung {
  Fassung({
    required this.nr,
    required this.inhalt,
    required this.quelle,
    required this.von,
    required this.am,
    List<Approval>? approvals,
  }) : approvals = approvals ?? [];

  final int nr;
  final Map<String, dynamic> inhalt;

  /// `import`, `bearbeitung`, `wiederherstellung` oder `wiederaufnahme`.
  final String quelle;

  /// `null` beim automatischen Import des Startbestands.
  final String? von;
  final DateTime am;
  final List<Approval> approvals;

  Map<String, dynamic> toJson() => {
    'nr': nr,
    'inhalt': inhalt,
    'quelle': quelle,
    'von': von,
    'am': am.toIso8601String(),
    'approvals': [for (final a in approvals) a.toJson()],
  };

  factory Fassung.fromJson(Map<String, dynamic> j) => Fassung(
    nr: j['nr'] as int,
    inhalt: j['inhalt'] as Map<String, dynamic>,
    quelle: j['quelle'] as String,
    von: j['von'] as String?,
    am: DateTime.parse(j['am'] as String),
    approvals: [for (final a in j['approvals'] as List) Approval.fromJson(a as Map<String, dynamic>)],
  );
}

/// Eintrag im Verlauf einer Aufgabe.
class Ereignis {
  const Ereignis({required this.art, required this.person, required this.am, required this.fassung, this.text});

  final String art;
  final String? person;
  final DateTime am;
  final int fassung;
  final String? text;

  Map<String, dynamic> toJson() => {
    'art': art,
    'person': person,
    'am': am.toIso8601String(),
    'fassung': fassung,
    'text': text,
  };

  factory Ereignis.fromJson(Map<String, dynamic> j) => Ereignis(
    art: j['art'] as String,
    person: j['person'] as String?,
    am: DateTime.parse(j['am'] as String),
    fassung: j['fassung'] as int,
    text: j['text'] as String?,
  );
}

/// Eine Aufgabe mit allen Fassungen.
class Eintrag {
  Eintrag({
    required this.id,
    required this.status,
    required this.fassungen,
    required this.ereignisse,
    this.liveFassung,
    Set<String>? geschuetzteItems,
  }) : geschuetzteItems = geschuetzteItems ?? {};

  final String id;

  /// `entwurf`, `geprueft`, `live` oder `zurueckgezogen`.
  String status;

  /// Fassung, die die App bekommt; `null` = nicht in der App.
  int? liveFassung;
  final List<Fassung> fassungen;
  final List<Ereignis> ereignisse;

  /// Items, die schon einmal live waren. Sie dürfen nicht verschwinden, weil
  /// gespeicherte Versuche auf ihre IDs zeigen.
  final Set<String> geschuetzteItems;

  Fassung get aktuell => fassungen.last;

  /// Die Aufgabe ist live und es gibt eine neuere, noch nicht freigegebene Fassung.
  bool get hatKorrektur => status == 'live' && aktuell.nr != liveFassung;

  Map<String, dynamic>? get liveInhalt {
    if (liveFassung == null) return null;
    return fassungen.firstWhere((f) => f.nr == liveFassung).inhalt;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'live_fassung': liveFassung,
    'fassungen': [for (final f in fassungen) f.toJson()],
    'ereignisse': [for (final e in ereignisse) e.toJson()],
    'geschuetzte_items': geschuetzteItems.toList()..sort(),
  };

  factory Eintrag.fromJson(Map<String, dynamic> j) => Eintrag(
    id: j['id'] as String,
    status: j['status'] as String,
    liveFassung: j['live_fassung'] as int?,
    fassungen: [for (final f in j['fassungen'] as List) Fassung.fromJson(f as Map<String, dynamic>)],
    ereignisse: [for (final e in j['ereignisse'] as List) Ereignis.fromJson(e as Map<String, dynamic>)],
    geschuetzteItems: {...(j['geschuetzte_items'] as List? ?? const []).cast<String>()},
  );
}

/// Ergebnis eines Imports.
class ImportBericht {
  ImportBericht({this.quelle});

  final String? quelle;
  final uebernommen = <Map<String, dynamic>>[];
  final konflikte = <String>[];
  final abgelehnt = <Map<String, dynamic>>[];

  Map<String, dynamic> toJson() => {
    'quelle': quelle,
    'uebernommen': uebernommen,
    'konflikte': konflikte,
    'abgelehnt': abgelehnt,
  };
}

/// Verstoß gegen eine Regel; der Server antwortet damit, die Oberfläche zeigt [text].
class RegelFehler implements Exception {
  const RegelFehler(this.code, this.text, {this.status = 422});

  /// Maschinenlesbar, z. B. `konflikt`, `keine_rechte`.
  final String code;
  final String text;

  /// HTTP-Status.
  final int status;

  @override
  String toString() => 'RegelFehler($code): $text';
}
