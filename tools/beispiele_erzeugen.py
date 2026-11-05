#!/usr/bin/env python3
"""Erzeugt die öffentlichen Beispieldaten aus seed/privat/ für die Demo.

Nach app/assets/beispiel/ kommen 12 Aufgaben (mindestens eine pro Antwortformat)
und nur die Levels und Kompetenzen, die sie brauchen, mit ID und Titel. Lernziele,
Erklärungen und Aufgabenpakete bleiben privat. Aufruf: python3 tools/beispiele_erzeugen.py
"""
import json
import pathlib

WURZEL = pathlib.Path(__file__).resolve().parent.parent
PRIVAT = WURZEL / "seed/privat"
ZIEL = WURZEL / "app/assets/beispiel"
ANZAHL = 12
ZUSATZ = ["offen_zahl", "mc_1aus6", "offen_term"]

aufgaben = json.loads((PRIVAT / "aufgaben.json").read_text(encoding="utf8"))["aufgaben"]
gewaehlt = {}
for a in aufgaben:
    gewaehlt.setdefault(a["items"][0]["antwortformat"], []).append(a)
auswahl = [liste[0] for liste in gewaehlt.values()]
for f in ZUSATZ:
    if len(auswahl) < ANZAHL:
        auswahl.append(gewaehlt[f][1])
assert len(auswahl) == ANZAHL

level_ids = {l for a in auswahl for l in a["level"]}
levels = [
    {k: l.get(k) for k in ["level_id", "titel", "themenbereich", "lernwelt", "kompetenzen"]}
    for l in json.loads((PRIVAT / "levels.json").read_text(encoding="utf8"))["levels"]
    if l["level_id"] in level_ids
]
ZIEL.mkdir(parents=True, exist_ok=True)


def schreibe(name, daten):
    (ZIEL / name).write_text(json.dumps(daten, ensure_ascii=False, indent=1) + "\n", encoding="utf8")


schreibe("aufgaben.json", {"quelle": "Beispielaufgaben für die Demo", "aufgaben": auswahl})
schreibe("levels.json", {"lernwelten": [], "levels": levels})
schreibe("kompetenz_keys.json", {})
schreibe("matura_themen.json", [])
print(len(auswahl), "Aufgaben,", len(levels), "Levels:", [a["id"] for a in auswahl])
