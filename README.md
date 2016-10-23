# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby

HexaPDF is a pure Ruby library with an accompanying application for working with PDF files. In
short, it allows

* **creating** new PDF files,
* **manipulating** existing PDF files,
* **merging** multiple PDF files into one,
* **extracting** meta information, text, images and files from PDF files,
* **securing** PDF files by encrypting them and
* **optimizing** PDF files for smaller file size or other criteria.

HexaPDF was designed with easy of use and performance in mind. It uses lazy loading and lazy
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
canvas = doc.pages.add_page.canvas
canvas.font('Helvetica', size: 100)
canvas.text("Hello World!", at: [20, 400])
doc.write("hello-world.pdf")
~~~

For detailed information have a look at the [HexaPDF website][website] where you will the API
documentation, example code and more.

[website]: http://hexapdf.gettalong.org


## Requirements and Installation

Since HexaPDF is written in Ruby, a working Ruby installation is needed - see the
[official installation documentation][rbinstall] for details. Note that you need Ruby version 2.3 or
higher as prior versions are not (officially) supported!

Apart from Ruby itself the HexaPDF library has no external dependencies. The `hexapdf` application
has a dependency on `cmdparse`, a command line parsing library.

HexaPDF itself is distributed via Rubygems and therefore easily installable via `gem install
hexapdf`.

[rbinstall]: https://www.ruby-lang.org/en/documentation/installation/


## Difference to Prawn

[Prawn] is a Ruby library that can be used for creating PDF files. It has been in development since
2008 and currently provides more features in regard to PDF content creation than HexaPDF.

So why use HexaPDF? Because it differs significantly from Prawn in how it is implemented:

* The architecture of HexaPDF is based on the object model of the PDF standard. This makes extending
  HexaPDF very easy and allows for **reading PDF files for templating purposes**.

* HexaPDF will provide a high level layer for **composing a document of individual elements** that
  are automatically layouted. Such elements can be headers, paragraphs, code blocks, ... or links,
  emphasized text and so on. These elements can be customized and additional element types easily
  added.

[Prawn]: http://prawnpdf.org


## License

See the LICENSE file for licensing details.


## Author

Thomas Leitner, <http://gettalong.org>
