#!/usr/bin/env python3
"""Regenerate the fully synthetic sample. ReportLab is a development tool only."""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    for name, file in [('Plex', 'IBMPlexSans-Regular.ttf'), ('PlexSemi', 'IBMPlexSans-SemiBold.ttf')]:
        pdfmetrics.registerFont(TTFont(name, str(ROOT / 'assets/fonts' / file)))
    file = ROOT / 'assets/sample.pdf'
    c = canvas.Canvas(str(file), pagesize=(595, 842), invariant=1)
    c.setTitle('Welcome to Cave Paper - synthetic sample')
    c.setAuthor('Cave')
    chapters = [
        ('Welcome to Cave Paper', 'Your files. Your device.', [
            'This is a synthetic PDF, included so you can try the reader safely.',
            'Cave Paper imports a local copy and keeps the original unchanged.',
            'Read, search and bookmark without signing in or connecting to a server.',
            'Search for the word privacy to test cross-page text search.',
        ]),
        ('Make a little room for ideas', 'Bookmarks and local annotations', [
            'Bookmark this page, close the reader, and return to it from your library.',
            'Select text and choose Highlight selected text in the reading menu.',
            'Add a page note. Your annotations are stored separately from the PDF.',
            'Export the annotation JSON with this PDF to move your notes.',
            'Privacy reminder: notes and PDFs are not encrypted by Cave Paper.',
        ]),
        ('Know what is supported', 'A reader first, with honest boundaries', [
            'The sample fields below demonstrate PDF form rendering only.',
            'Form editing and saving are not implemented in this first version.',
            'OCR, PDF content editing, digital signatures and printing come later.',
            'Your device backups may contain local PDFs. Keep those backups secure.',
        ]),
    ]
    for page, (title, subtitle, paragraphs) in enumerate(chapters, 1):
        c.setFillColor(HexColor('#F3F7F6')); c.rect(0, 0, 595, 842, fill=1, stroke=0)
        c.setFillColor(HexColor('#147F79')); c.roundRect(42, 738, 511, 55, 10, fill=1, stroke=0)
        c.setFillColor(white); c.setFont('PlexSemi', 13); c.drawString(60, 760, 'CAVE PAPER / OFFLINE READER')
        c.bookmarkPage(f'chapter-{page}'); c.addOutlineEntry(title, f'chapter-{page}', level=0)
        c.setFillColor(HexColor('#123A49')); c.setFont('PlexSemi', 25); c.drawString(44, 685, title)
        c.setFillColor(HexColor('#147F79')); c.setFont('Plex', 15); c.drawString(44, 652, subtitle)
        y = 596
        for line in paragraphs:
            c.setFont('Plex', 11.5); c.setFillColor(HexColor('#243E49')); c.drawString(44, y, line); y -= 34
        if page == 3:
            c.setFont('PlexSemi', 12); c.drawString(44, 385, 'Demo name (display only)')
            c.acroForm.textfield(name='demo_name', value='Synthetic reader sample', x=44, y=342,
                                width=330, height=30, borderWidth=1, fillColor=white)
            c.acroForm.checkbox(name='demo_consent', x=44, y=290, checked=True, size=16)
            c.setFont('Plex', 11); c.drawString(70, 294, 'This is a demonstration, not a real consent form.')
        c.setFillColor(HexColor('#54706F')); c.setFont('Plex', 10)
        c.drawString(44, 55, 'Synthetic content. No customer documents or personal data.')
        c.drawRightString(551, 55, f'{page} / 3')
        c.showPage()
    c.save()
    print(file.name)


if __name__ == '__main__':
    main()
