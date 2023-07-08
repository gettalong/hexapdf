#!/usr/bin/env python3

from fpdf import FPDF
import sys

rows = int(sys.argv[1])
data =[[f"Line {k}", 0, str(k)] for k in range(rows)]
image = sys.argv[2]

pdf = FPDF(unit='pt', format="A4")
pdf.set_margin(72)
pdf.set_auto_page_break(True, 72)
pdf.set_font('Helvetica', size=10)
pdf.add_page()
with pdf.table(align='LEFT', width=400, col_widths=(200, 100, 100), line_height=51.5,
               text_align=('LEFT', 'CENTER', 'RIGHT'),first_row_as_headings=False) as table:
    for data_row in data:
        row = table.row()
        for j, datum in enumerate(data_row):
            if j == 1:
                row.cell(img=image)
            else:
                row.cell(datum)

pdf.output(sys.argv[3])
