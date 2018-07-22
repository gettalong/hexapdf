# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby

HexaPDF is a pure Ruby library with an accompanying application for working with PDF files. In
short, it allows

* **creating** new PDF files,
* **manipulating** existing PDF files,
* **merging** multiple PDF files into one,
* **extracting** meta information, text, images and files from PDF files,
* **securing** PDF files by encrypting them and
* **optimizing** PDF files for smaller file size or other criteria.

HexaPDF was designed with ease of use and performance in mind. It uses lazy loading and lazy
computing when possible and tries to produce small PDF files by default.


## Usage

The HexaPDF distribution provides the library as well as the `hexapdf` application. The application
can be used to perform common tasks like merging PDF files, decrypting or encrypting PDF files and
so on.

When HexaPDF is used as a library, it can be used to do all the task that the command line
application does and much more. Here is a "Hello World" example that shows how to create a simple
PDF file:

~~~ ruby
require 'hexapdf'

doc = HexaPDF::Document.new
canvas = doc.pages.add.canvas
canvas.font('Helvetica', size: 100)
canvas.text("Hello World!", at: [20, 400])
doc.write("hello-world.pdf")
~~~

For detailed information have a look at the [HexaPDF website][website] where you will the API
documentation, example code and more.

[website]: http://hexapdf.gettalong.org


## Requirements and Installation

Since HexaPDF is written in Ruby, a working Ruby installation is needed - see the
[official installation documentation][rbinstall] for details. Note that you need Ruby version 2.4 or
higher as prior versions are not supported!

Apart from Ruby itself the HexaPDF library has no external dependencies. The `hexapdf` application
has a dependency on `cmdparse`, a command line parsing library.

HexaPDF itself is distributed via Rubygems and therefore easily installable via `gem install
hexapdf`.

[rbinstall]: https://www.ruby-lang.org/en/documentation/installation/


## Difference to Prawn

The main difference between HexaPDF and [Prawn] is that HexaPDF is a **full PDF library** whereas
Prawn is a **library for generating content**.

To be more specific, it is easily possible to read an existing PDF with HexaPDF and modify parts of
it before writing it out again. The modifications can be to the PDF object structure like removing
superfluous annotations or the the content itself.

Prawn has no such functionality. There is basic support for using a PDF as a template using the
`pdf-reader` and `prawn-template` gems but support is very limited. However, Prawn has a very
featureful API when it comes to creating content, for individual pages as well as across pages.

Such functionality will be incorporated into HexaPDF in the near future. The main functionality for
providing such a feature is already available in HexaPDF (the [page canvas API]). Additionally,
laying out text inside a box with line wrapping and such is also supported. What's missing (and this
is still quite a big chunk) is support for advanced features like tables, page breaking and so on.

So why use HexaPDF?

* The architecture of HexaPDF is based on the object model of the PDF standard. This makes extending
  HexaPDF very easy and allows for **reading PDF files for templating purposes**.

* HexaPDF will provide a high level layer for **composing a document of individual elements** that
  are automatically layouted. Such elements can be headers, paragraphs, code blocks, ... or links,
  emphasized text and so on. These elements can be customized and additional element types easily
  added.

* In addition to being usable as a library, HexaPDF also comes with a command line tool for
  manipulating PDFs. This tool is intended to be a replacement for tools like `pdftk` and the
  various Poppler-based tools like `pdfinfo`, `pdfimages`, ...

[Prawn]: http://prawnpdf.org
[page canvas API]: https://hexapdf.gettalong.org/api/HexaPDF/Content/Canvas.html


## License

AGPL - see the LICENSE file for licensing details. Commercial licenses are available at
<https://gettalong.at/hexapdf/>.

Some included files have a different license:

* For the license of the included AFM files in the `data/hexapdf/afm` directory, see the file
  `data/hexapdf/afm/MustRead.html`.

* The files `test/data/encoding/{glyphlist.txt,zapfdingbats.txt}` are licensed under the Apache
  License V2.0.

* The file `test/data/fonts/Ubuntu-Title.ttf` is licensed under the SIL Open Font License.

* The AES test vector files in `test/data/aes-test-vectors` have been created using the test vector
  file available from <http://csrc.nist.gov/groups/STM/cavp/block-ciphers.html#test-vectors>.


## Contributing

See <http://hexapdf.gettalong.org/contributing.html> for more information.


## Author

Thomas Leitner, <http://gettalong.org>
