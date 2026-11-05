#!/usr/bin/env python3
"""Holt die Texte aus dem Vault ins Projekt.

- Bauplan Aufgabenerstellung.md -> app/assets/hilfe/bauplan.md (ohne Frontmatter,
  "Siehe auch", "Änderungsverlauf", Pflegehinweise; wie beim PDF)
- Aufgaben - Bauplan und Datenmodell.pdf -> app/web/dokumente/ (öffentlich, für den Leitfaden-Knopf)
- Lernplan 5.-8. Klasse.md -> seed/privat/matura_themen.json

Nach Änderungen an den Notizen neu ausführen: python3 tools/hilfe_sync.py
"""
import json
import pathlib
import re
import shutil

WURZEL = pathlib.Path(__file__).resolve().parent.parent
VAULT = pathlib.Path.home() / "Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/Tuto | Jona"
AUFGABEN = VAULT / "App-Architektur/Aufgaben"


def bauplan():
    t = (AUFGABEN / "Bauplan Aufgabenerstellung.md").read_text(encoding="utf8")
    t = re.sub(r"\A---\n.*?\n---\n", "", t, flags=re.S)
    t = re.sub(r"<!-- nur-vault -->.*?<!-- /nur-vault -->", "", t, flags=re.S)
    t = re.sub(r"^> \[!vault\].*\n(?:^>.*\n)*", "", t, flags=re.M)
    t = re.split(r"^## (?:Siehe auch|Änderungsverlauf)", t, flags=re.M)[0]
    t = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"\[\[([^\]]*)\]\]", r"\1", t)
    ziel = WURZEL / "app/assets/hilfe/bauplan.md"
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(t.strip() + "\n", encoding="utf8")
    print("Hilfe:", ziel.relative_to(WURZEL), len(t), "Zeichen")


def leitfaden():
    ziel = WURZEL / "app/web/dokumente/aufgaben-bauplan-und-datenmodell.pdf"
    ziel.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(AUFGABEN / "Aufgaben - Bauplan und Datenmodell.pdf", ziel)
    print("Leitfaden:", ziel.relative_to(WURZEL))


def matura_themen():
    t = (AUFGABEN / "Lernplan 5.-8. Klasse.md").read_text(encoding="utf8")
    themen = {}
    for pre, von, bis, titel in re.findall(r"\b(M(?:AG|FA|AN|WS))-(\d\d)-(\d\d) ([^(|]+)", t):
        for n in range(int(von), int(bis) + 1):
            themen.setdefault(f"{pre}-{n:02d}", titel.strip())
    ziel = WURZEL / "seed/privat/matura_themen.json"
    ziel.write_text(json.dumps([{"id": k, "titel": v} for k, v in sorted(themen.items())], ensure_ascii=False, indent=1), encoding="utf8")
    print("Matura-Themen:", len(themen))


bauplan()
leitfaden()
matura_themen()
