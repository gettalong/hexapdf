#!/usr/bin/env python3

import sys
from reportlab.platypus import *
from reportlab.platypus.doctemplate import _doNothing
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.lib import colors

import reportlab.rl_config
reportlab.rl_config.invariant = 0
reportlab.rl_config.useA85 = 0
reportlab.rl_config.ttfAsciiReadable = 0

class MyDocTemplate(BaseDocTemplate):
    _invalidInitArgs = ('pageTemplates',)

    def build(self,flowables,onFirstPage=_doNothing, onLaterPages=_doNothing, canvasmaker=canvas.Canvas):
        self._calc()
        frameT = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, 0, 0, 0, 0, id='normal')
        self.addPageTemplates([PageTemplate(id='default', frames=frameT, onPage=onFirstPage, pagesize=self.pagesize)])
        BaseDocTemplate.build(self,flowables, canvasmaker=canvasmaker)

font = 'Helvetica'

elements = []

rows = int(sys.argv[1])
image = Image(sys.argv[2], height=40, width=53.3)

data =[[f"Line {k}", image, str(k)] for k in range(rows)]
t = Table(data, colWidths=[200, 100, 100],hAlign='LEFT')
t.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 1, colors.black),
                       ('LEFTPADDING', (0,0), (-1,-1), 6),
                       ('RIGHTPADDING', (0,0), (-1,-1), 5),
                       ('TOPPADDING', (0,0), (-1,-1), 6),
                       ('BOTTOMPADDING', (0,0), (-1,-1), 6),
                       ('VALIGN', (0,0), (-1,-1), 'TOP'),
                       ('ALIGN', (-1,0), (-1,-1), 'RIGHT'),
                       ('ALIGN', (1,0), (1,-1), 'CENTER')]))
t.halign = 'LEFT'
elements.append(t)

doc = MyDocTemplate(sys.argv[3], pagesize=A4, leftMargin=72, rightMargin=72, topMargin=72, bottomMargin=72)
doc.build(elements)
