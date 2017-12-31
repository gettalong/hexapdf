import sys
from reportlab.platypus import *
from reportlab.platypus.doctemplate import _doNothing
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

import reportlab.rl_config
reportlab.rl_config.invariant = 0
reportlab.rl_config.useA85 = 0
reportlab.rl_config.ttfAsciiReadable = 0

class MyDocTemplate(BaseDocTemplate):
    _invalidInitArgs = ('pageTemplates',)

    def build(self,flowables,onFirstPage=_doNothing, onLaterPages=_doNothing, canvasmaker=canvas.Canvas):
        self._calc()
        frameT = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, 0, 0, 0, 0, id='normal')
        self.addPageTemplates([PageTemplate(id='default',frames=frameT, onPage=onFirstPage,pagesize=self.pagesize)])
        BaseDocTemplate.build(self,flowables, canvasmaker=canvasmaker)

font = 'Times-Roman'
if len(sys.argv) == 5:
    pdfmetrics.registerFont(TTFont('font', sys.argv[4]))
    font = 'font'

ParaStyle = ParagraphStyle("default")
ParaStyle.fontName = font
ParaStyle.fontsize = 10
ParaStyle.leading = 11.16
ParaStyle.alignment = TA_LEFT
ParaStyle.allowOrphans = 1
ParaStyle.allowWidows = 1
ParaStyle.spaceBefore = 0
ParaStyle.spaceAfter = 0
ParaStyle.leftIndent = 0
ParaStyle.rightIndent = 0

height = 1000
width = int(sys.argv[2])
Elements = []

def p(txt, style=ParaStyle):
    Elements.append(Paragraph(txt, style))

text = open(sys.argv[1], 'r').read()
# Using the complete string leads to very long runtimes, splitting the string into
# individual lines and only breaking them is much faster with ReportLab
#p(text)
L=list(map(str.strip, text.split('\n')))
for P in L:
    if not P:
        P = ':'
    p(P)

doc = MyDocTemplate(sys.argv[3], pagesize=(width, height), leftMargin=0, rightMargin=0, topMargin=0, bottomMargin=0)
doc.build(Elements)
