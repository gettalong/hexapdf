## Line Wrapping Benchmark

This benchmark tests the performance of line wrapping and simple general layouting. The Project
Gutenberg text of Homer's Odyssey is used for this purposes.


## Benchmark Setup

The text of the Odyssey is arranged on pages of the dimension `WIDTH`x1000 where `WIDTH` is set to
different values (400, 200, 100 and 50 by default). Additionally, all widths are combined once with
the standard PDF Type1 font Times-Roman and once with a TrueType font (DejaVu Sans by default).

In the case of pages with a width of 400 no line wrapping needs to be done because each line in the
source text is shorter than 400 points. In the other cases lines need to be actually wrapped and the
number of pages increases. With a width of 50 even words need sometimes to be broken.

The list of the benchmarked libraries:

**HexaPDF**

: Homepage: <http://hexapdf.gettalong.org>\\
  Language: Ruby\\
  Version: Latest version

**Prawn**

: Homepage: <http://hexapdf.gettalong.org>\\
  Language: Ruby\\
  Version: 2.2.2

**ReportLab**

: Homepage: <https://www.reportlab.com/opensource/>\\
  Language: Python\\
  Version: 3.4.0

**TCPDF**

: Homepage: <https://tcpdf.org/>\\
  Language: PHP\\
  Version: 6.2.12
