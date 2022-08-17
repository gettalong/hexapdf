#!/usr/bin/env python

from fpdf import FPDF
import sys

pdf = FPDF(unit='pt')

font = 'Times'
if len(sys.argv) == 4:
    pdf.add_font('font', fname=sys.argv[3])
    font = 'font'
pdf.set_font(font, size=12)

pdf.set_margins(72, 72 + 0.5 * 72, 72)
pdf.set_auto_page_break(False)

bottom_margin = 733.89

pdf.add_page()
y = pdf.y
data = open(sys.argv[1],'r').readlines()
for line in data:
    if y > bottom_margin:
        pdf.add_page()
        y = pdf.y
    pdf.text(72, y, line.rstrip())
    y += 14

pdf.output(sys.argv[2])
