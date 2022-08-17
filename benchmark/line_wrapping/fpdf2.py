#!/usr/bin/env python

from fpdf import FPDF
import sys

pdf = FPDF(unit='pt', format=(int(sys.argv[2]) + 6, 1000))

font = 'Times'
if len(sys.argv) == 5:
    pdf.add_font('font', fname=sys.argv[4])
    font = 'font'
pdf.set_font(font, size=10)

pdf.set_margin(0)
pdf.set_auto_page_break(True, 0)

text = open(sys.argv[1], 'r').read()
pdf.add_page()
pdf.multi_cell(w=0, h=11.16, max_line_height=11.16, txt=text, align='L')

pdf.output(sys.argv[3])
