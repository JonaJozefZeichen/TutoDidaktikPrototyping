#!/usr/bin/env python3
"""Erzeugt aus der Vault-Notiz "Didaktik-Tool für Manuel.md" ein PDF zum Verschicken.

Weggelassen: Frontmatter, "Siehe auch", "Änderungsverlauf".
Aufruf (mit reportlab, z. B. in einer venv): python tools/manuel_doc_pdf.py
"""
import os
import re
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image, KeepTogether, ListFlowable, ListItem, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

ORDNER = os.path.expanduser(
    "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/Tuto | Jona/Produkt-Design/Didaktik"
)
QUELLE = os.path.join(ORDNER, "Didaktik-Tool für Manuel.md")
ZIEL = os.path.join(ORDNER, "Didaktik-Tool für Manuel.pdf")

SCHRIFTEN = "/System/Library/Fonts/Supplemental"
pdfmetrics.registerFont(TTFont("Arial", f"{SCHRIFTEN}/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", f"{SCHRIFTEN}/Arial Bold.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Italic", f"{SCHRIFTEN}/Arial Italic.ttf"))
pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold", italic="Arial-Italic", boldItalic="Arial-Bold")

BLAU = colors.HexColor("#2A62C4")
TINTE = colors.HexColor("#1B2433")
LINIE = colors.HexColor("#DCE2EA")
FLAECHE = colors.HexColor("#F5F7FA")
BREITE = A4[0] - 40 * mm

BASIS = ParagraphStyle("Basis", fontName="Arial", fontSize=10, leading=14, textColor=TINTE, spaceAfter=5)
LISTE = ParagraphStyle("Liste", parent=BASIS, spaceAfter=2)
TITEL = ParagraphStyle("Titel", parent=BASIS, fontName="Arial-Bold", fontSize=20, leading=25, textColor=BLAU, spaceAfter=8)
H2 = ParagraphStyle("H2", parent=BASIS, fontName="Arial-Bold", fontSize=13, leading=17, spaceBefore=11, spaceAfter=5)
ZELLE = ParagraphStyle("Zelle", parent=BASIS, fontSize=9, leading=12, spaceAfter=0)


def inline(text):
    t = escape(text).replace("\\*", "*")
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"`(.+?)`", r"\1", t)
    t = re.sub(r"(https?://\S+)", r'<a href="\1" color="#2A62C4"><u>\1</u></a>', t)
    return t


def tabelle(zeilen):
    daten = []
    for z in zeilen:
        zellen = [c.strip() for c in z.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in zellen):
            continue
        daten.append(zellen)
    kopf = [Paragraph(f"<b>{inline(c)}</b>", ZELLE) for c in daten[0]]
    rest = [[Paragraph(inline(c), ZELLE) for c in z] for z in daten[1:]]
    t = Table([kopf, *rest], colWidths=[BREITE * 0.3, BREITE * 0.7], repeatRows=1)
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), FLAECHE),
                ("GRID", (0, 0), (-1, -1), 0.5, LINIE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return t


def liste(eintraege, nummeriert):
    return ListFlowable(
        [ListItem(Paragraph(inline(e), LISTE), leftIndent=14) for e in eintraege],
        bulletType="1" if nummeriert else "bullet",
        start=None if nummeriert else "•",
        bulletFontName="Arial",
        bulletFontSize=10,
        leftIndent=14,
    )


def bild(name):
    pfad = os.path.join(ORDNER, name)
    b, h = ImageReader(pfad).getSize()
    return Image(pfad, width=BREITE, height=BREITE * h / b)


def main():
    text = open(QUELLE, encoding="utf8").read()
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    text = re.split(r"^## (?:Siehe auch|Änderungsverlauf)", text, flags=re.M)[0]
    story = []
    zeilen = text.strip().split("\n")
    i = 0
    while i < len(zeilen):
        z = zeilen[i]
        if not z.strip():
            i += 1
        elif z.startswith("# "):
            story.append(Paragraph(inline(z[2:]), TITEL))
            i += 1
        elif z.startswith("## "):
            # Überschrift nicht allein am Seitenende stehen lassen
            ueberschrift = Paragraph(inline(z[3:]), H2)
            i += 1
            while not zeilen[i].strip():
                i += 1
            if zeilen[i].startswith("!"):
                story.append(KeepTogether([ueberschrift, bild(zeilen[i][3:-2]), Spacer(1, 6)]))
                i += 1
            elif zeilen[i].startswith(("-", "|", "1.")):
                story.append(ueberschrift)
            else:
                story.append(KeepTogether([ueberschrift, Paragraph(inline(zeilen[i]), BASIS)]))
                i += 1
        elif z.startswith("![["):
            story += [bild(z[3:-2]), Spacer(1, 6)]
            i += 1
        elif z.startswith("|"):
            block = []
            while i < len(zeilen) and zeilen[i].startswith("|"):
                block.append(zeilen[i])
                i += 1
            story += [tabelle(block), Spacer(1, 6)]
        elif re.match(r"(- |\d+\. )", z):
            nummeriert = z[0].isdigit()
            block = []
            while i < len(zeilen) and re.match(r"(- |\d+\. )", zeilen[i]):
                block.append(re.sub(r"^(- |\d+\. )", "", zeilen[i]))
                i += 1
            story += [liste(block, nummeriert), Spacer(1, 6)]
        else:
            story.append(Paragraph(inline(z), BASIS))
            i += 1
    SimpleDocTemplate(
        ZIEL,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="Das Didaktik-Tool für Tuto",
        author="Tuto",
    ).build(story)
    print(ZIEL)


main()
