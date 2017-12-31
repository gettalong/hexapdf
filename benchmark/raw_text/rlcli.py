from reportlab.pdfgen import canvas
from reportlab import rl_config
import sys

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

rl_config.useA85 = 0
rl_config.ttfAsciiReadable = 0

font = 'Times-Roman'
if len(sys.argv) == 4:
    pdfmetrics.registerFont(TTFont('font', sys.argv[3]))
    font = 'font'

top_margin = A4[1] - 72 - 0.5 * 72
bottom_margin = 72 + 0.5 * 72

canv = canvas.Canvas(sys.argv[2], invariant=0)
canv.setPageCompression(1)
y = 0
tx = None

data = open(sys.argv[1],'r').readlines()
for line in data:
    if y < bottom_margin:
        if tx:
            canv.drawText(tx)
            canv.showPage()
        canv.setFont(font, 12)
        tx = canv.beginText(72, top_margin)
        tx.setLeading(14)
        y = top_margin
    tx.textLine(line.rstrip())
    y -= 14

canv.drawText(tx)
canv.showPage()
canv.save()
