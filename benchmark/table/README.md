## Table Benchmark

This benchmark tests the performance of table implementations.


## Benchmark Setup

A simple table with three columns (text, image, text) and varying number of rows is laid out, using
the available table implementation together with automatic page breaking.

Each benchmark script can be invoked standalone in the following way: `script-executable NR_ROWS
IMAGE_FILE OUTPUT_FILE`.

The list of the benchmarked libraries:

**HexaPDF**

: Homepage: <http://hexapdf.gettalong.org>\\
  Language: Ruby\\
  Version: Latest version

**Prawn**

: Homepage: <https://prawnpdf.org>\\
  Language: Ruby\\
  Version: 2.5.0 + prawn-table 0.2.2

  Prawn's table implementation is available in the separate gem `prawn-table`.

**ReportLab**

: Homepage: <https://www.reportlab.com/opensource/>\\
  Language: Python\\
  Version: 4.2.2 + accel extension

**fpdf2**

: Homepage: <https://pyfpdf.github.io/fpdf2/>\\
  Language: Python\\
  Version: 2.7.9
