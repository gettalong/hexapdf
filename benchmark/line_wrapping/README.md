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

Each benchmark script can be invoked standalone in the following way: `script-executable TXT_FILE
WIDTH OUTPUT_FILE [TTF_FILE]`.

The performance of the libraries hugely depends on how the input text is provided: Some are very
fast when processing the whole input file at once, others only when processing the input line by
line. The fastest method was always chosen.

The list of the benchmarked libraries:

**HexaPDF**

: Homepage: <http://hexapdf.gettalong.org>\\
  Language: Ruby\\
  Version: Latest version

  HexaPDF works faster if the whole input is given at once but still has acceptable runtimes for
  line by line input.

  Two different ways of general layouting are benchmarked:

  L
  : This version uses the low-level layouting facility [HexaPDF::Layout::TextLayouter] and processes
    the whole file at once.

  C
  : This version uses the high-level [HexaPDF::Composer] to construct the document and processes
    chunks of 1000 lines at once to reduce peak memory usage.

**Prawn**

: Homepage: <https://prawnpdf.org>\\
  Language: Ruby\\
  Version: 2.5.0

  Prawn is much faster and uses much less memory if the input is provided line by line. However, it
  still works if the whole input is provided at once.

**ReportLab**

: Homepage: <https://www.reportlab.com/opensource/>\\
  Language: Python\\
  Version: 4.2.2 + accel extension

  ReportLab also needs its input line by line. Otherwise it is much, much slower (at least 60x, then
  the test run was aborted).

**fpdf2**

: Homepage: <https://pyfpdf.github.io/fpdf2/>\\
  Language: Python\\
  Version: 2.7.9

  As with HexaPDF itself, fpdf2 works equally fine when getting the input as one big string or line
  by line.

**TCPDF**

: Homepage: <https://tcpdf.org/>\\
  Language: PHP\\
  Version: 6.7.5

  As with Prawn and ReportLab, TCPDF needs its input line by line. Otherwise it is much, much slower
  when line wrapping needs to be done (the test run was aborted because it took too long).
