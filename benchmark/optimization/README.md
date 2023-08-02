## Optimization Benchmark

One of the ways to use the `hexapdf` command is to optimize a PDF file in terms of its file size.
This involves reading and writing the PDF file and performing the optimization. Sometimes the word
"optimization" is used when a PDF file is linearized for faster display on web sites. However, here
it always means file size optimization.

There are various ways to optimize the file size of a PDF file and they can be divided into two
groups: lossless and lossy operations. Since all used applications perform only lossless
optimizations, we only look at those:

Removing unused and deleted objects

: A PDF file can store multiple revisions of an object but only the last one is used. So all other
  versions can safely be deleted.

Using object and cross-reference streams

: A PDF file can be thought of as a collection of random-access objects that are stored sequentially
  in an ASCII-based format. Object streams take those objects and store them compressed in a binary
  format. And cross-reference streams store the file offsets to the objects in a compressed manner,
  instead of the standard ASCII-based format.

Recompressing page content streams

: The content of a PDF page is described in an ASCII-based format. Some PDF producers don't optimize
  their output which can lead to bigger than necessary content streams or don't store it in a
  compressed format.

There are some more techniques for reducing the file size like font subsetting/merging/deduplication
or object and image deduplication. However, those are rather advanced and not implemented in most
PDF libraries because it is hard to get them right.


## Benchmark Setup

There are many applications that can perform some or all of the optimizations mentioned above. Since
this benchmark is intended to be run on Linux we will use command line applications that are readily
available on this platform.

Since the abilities of the applications vary, following is a table of keys used to describe the
various operations:

| Key | Operation |
|-----------------|
| C   | Compacting by removing unused and deleted objects |
| S   | Usage of object and cross-reference streams |
| P   | Recompression of page content streams |
{:.default}

The list of the benchmarked applications:

**hexapdf**

: Homepage: <http://hexapdf.gettalong.org>\\
  Version: Latest version\\
  Abilities: Any combination of C, S and P

  We want to benchmark `hexapdf` with increasing levels of compression, using the following
  invocations:

  None of C, S, or P
  : `hexapdf optimize INPUT --no-compact --object-streams=preserve --xref-streams=preserve
    --streams=preserve --no-optimize-fonts OUTPUT`

  C
  : `hexapdf optimize INPUT --compact --object-streams=preserve --xref-streams=preserve
    --streams=preserve --no-optimize-fonts OUTPUT`

  CS (so this would be the standard mode of operation)
  : `hexapdf optimize INPUT OUTPUT`

  CSP
  : `hexapdf optimize INPUT --compress-pages OUTPUT`

**origami**

: Homepage: <https://github.com/gdelugre/origami>\\
  Version: 2.1.0\\
  Abilities: ?

  Similar to HexaPDF Origami is a framework for manipulating PDF files. Since it is also written in
  Ruby, it makes for a good comparison.

  The `origami.rb` script can be invoked like `ruby origami.rb INPUT OUTPUT`.

**combine_pdf**

: Homepage: <https://github.com/boazsegev/combine_pdf>\\
  Version: 1.0.23\\
  Abilities: ?

  CombinePDF is a tool for merging PDF files, written in Ruby.

  The `combine_pdf.rb` script can be invoked like `ruby combine_pdf.rb INPUT OUTPUT`.

**pdftk**

: Homepage: <https://gitlab.com/marcvinyals/pdftk>\\
  Version: 3.3.2\\
  Abilities: C

  `pdftk` is probably one of the best known applications because, like `hexapdf` it allows for many
  different operations on PDFs. It is based on the Java iText library. Prior version have been
  compiled to native code using GCJ but GCJ was deprecated and this fork of pdftk now uses Java.

  The application doesn't have options for optimizing a PDF file but it can be assumed that it
  removes unused and deleted objects when invoked like `pdftk INPUT output OUTPUT`.

**qpdf**

: Homepage: <http://qpdf.sourceforge.net/>\\
  Version: 10.4.0\\
  Abilities: C, CS

  QPDF is a command line application for transforming PDF files written in C++.

  The standard `C` mode of operation is invoked with `qpdf INPUT OUTPUT` whereas the CS mode would
  need an additional option `--object-streams=generate`.

**smpdf**
: Homepage: <http://www.coherentpdf.com/compression.html>\\
  Version: 1.4.1\\
  Abilities: CSP

  This is a commercial application but can be used for evaluation purposes. There is no way to
  configure the operations done but judging from its output it seems it does all of the lossless
  operations.

  Invocation is done like this: `smpdf INPUT -o OUTPUT`.


The standard files used in the benchmark (*not* available in the HexaPDF distribution) vary in file
size and internal structure:

| Name      |        Size |  Objects |  Pages | Details |
|-----------|------------:|---------:|-------:|----------|
| **a.pdf** |      53.056 |       36 |      4 | Very simple one page file |
| **b.pdf** |  11.520.218 |    4.161 |    439 | Many non-stream objects |
| **c.pdf** |  14.399.980 |    5.263 |    620 | Linearized, many streams |
| **d.pdf** |   8.107.348 |   34.513 |     20 | |
| **e.pdf** |  21.788.087 |    2.296 |     52 | Huge content streams, many pictures, object streams, encrypted with default password |
| **f.pdf** | 154.752.614 |  287.977 | 28.365 | *Very* big file |
{:.default}
