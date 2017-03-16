## Unreleased

### Added

* [HexaPDF::Type::FontType0] and [HexaPDF::Type::CIDFont] for composite font
  support
* Complete support for CMaps for use with composite fonts; the interface for
  [HexaPDF::Font::CMap] changed to accomodate this
* CLI command `hexapdf batch` for batch execution of a single command for
  multiple input files
* CLI option `--verbose` for more verbose output; also changed the default
  verbosity level to only display warnings and not informational messages
* CLI option `--quiet` for suppressing additional and diagnostic output
* CLI option `--strict` for enabling strict parsing and validation; also
  changed the default from strict to non-strict parsing/validation
* CLI optimization option `--optimize-fonts` for optimizing embedded fonts
* Method `#word_spacing_applicable?` to font types
* Support for marked-content points and sequences in [HexaPDF::Content::Canvas]
* Support for property lists in a page's resource dictionary
* Show file name and size in `hexapdf info` output
* [HexaPDF::Type::Font#font_file] for getting the embedded font file
* [HexaPDF::Font::TrueType::Optimizer] for optimizing TrueType fonts
* Configuration option 'filter.flate_memory' for configuring memory use of the
  [HexaPDF::Filter::FlateDecode] filter
* Method [HexaPDF::Content::Canvas#show_glyphs_only] for faster glyph showing
  without text matrix calculations
* Methods for caching expensive computations of PDF objects
  ([HexaPDF::Document#cache] and others)

### Changed

* Enabled in-place processing of PDF files for all CLI commands
* Show warning instead of exiting when extracting images with `hexapdf images`
  and an image format is not supported
* Handling of character code to Unicode mapping:
  - [HexaPDF::Font::CMap#to_unicode], [HexaPDF::Font::Encoding::Base#unicode]
    and [HexaPDF::Font::Encoding::GlyphList#name_to_unicode] return `nil`
    instead of an empty string
  - Font dictionaries use the new configuration option
    'font.on_missing_unicode_mapping' in their `#to_utf8` method
* [HexaPDF::Configuration#constantize] to raise error if constant is not found
* Extracted TrueType font file building code into new module
  [HexaPDF::Font::TrueType::Builder]
* [HexaPDF::Filter::FlateDecode] filter to use pools of Zlib inflaters and
  deflaters to conserve memory

### Fixed

* Use of wrong glyph IDs for glyph width entries and unicode mapping for subset
  TrueType fonts
* Invalid document reference when importing wrapped direct objects with
  [HexaPDF::Importer]
* Invalid type of /DW key in CIDFont dictionary when embedding TrueType fonts
* Caching problem in [HexaPDF::Document::Fonts] which lead to multiple instances
  of the same font
* Bug in handling of word spacing with respect to offset calculations when
  showing or extracting text
* Incorrect handling of page rotation values in `hexapdf merge`
* Missing handling of certain rotation values in `hexapdf modify`
* Removal of unused pages in `hexapdf modify`
* Handling of invalid page numbers in CLI commands
* Useless multiple extraction of the same image in `hexapdf images`
* Type of /VP entry of [HexaPDF::Type::Page]
* Parsing of inline images that contain the end-of-image marker
* High memory usage due to not closing `Zlib::Stream` objects in
  [HexaPDF::Filter::FlateDecode]


## 0.3.0 - 2017-01-25

### Added

* TrueType font subsetting support
* Image extraction ability to CLI via `hexapdf images` command
* [HexaPDF::Type::Image#write] for writing an image XObject to an IO stream or
  file
* [HexaPDF::Type::Image#info] for getting image properties of an image XObject
* CLI option `--[no-]force` to force overwriting existing files

### Changed

* Refactor `hexapdf modify` command into three individual commands `modify`,
  `merge` and `optimize`
* Rename `hexapdf extract` to `hexapdf files` and the option `--indices` to
  `--extract`
* Show PDF trailer by default with `hexapdf inspect`
* Refactor CLI command classes to use specialized superclass
  [HexaPDF::CLI::Command]
* Optimize parsing of PDF files for better performance and memory efficiency

### Fixed

* Writing of hybrid-reference PDF files - they are written as standard PDF files
  since all current applications should be able to handle PDF 1.5
* Serialization of self-referential, indirect PDF objects
* Performance problem for `hexapdf inspect --pages` when inspecting huge files
* TrueType compound glyph component offset calculation
* Parsing of TrueType data type 'fixed'
* Updating a PDF trailer's ID field when it isn't an array

## 0.2.0 - 2016-11-28

### Added

* PDF file merge ability to `hexapdf modify`, i.e. adding pages from other PDFs
* Page interleaving support to 'hexapdf modify'
* Step values in pages definitions for CLI commands
* Convenience class for working with pages through [HexaPDF::Document#pages]
  with a more Ruby-like interface
* Method [HexaPDF::Type::Form#canvas]
* Method [HexaPDF::Type::Page#index]
* Validation for [HexaPDF::Rectangle] objects
* [HexaPDF::Font::Type1::FontMetrics#weight_class] for returning the numeric
  weight

### Changed

* Refactor document utilities into own classes with a more Ruby-like interface;
  concern fonts, images and files, now accessible through
  [HexaPDF::Document#fonts], [HexaPDF::Document#images] and
  [HexaPDF::Document#files]
* Validate nested collection values in [HexaPDF::Object]
* Allow [HexaPDF::Dictionary#[]] to always unwrap nil values
* Update [HexaPDF::Task::Optimize] to delete unused objects on `:compact`
* Allow [HexaPDF::Type::PageTreeNode#delete_page] to take a page object or a
  page index
* Don't set /EFF key in encryption dictionary
* Better error handling for hexapdf CLI commands
* Show help output when no command is given for `hexapdf` CLI
* Set /FontWeight in [HexaPDF::Font::Type1Wrapper]
* Use kramdown's man page support for the `hexapdf` man page instead of ronn

### Removed

* Remove unneeded parts of TrueType implementation

### Fixed

* Problem with unnamed classes/modules on serialization
* Handle potentially indirect objects correctly in [HexaPDF::Object::deep_copy]
* [HexaPDF::Revisions#merge] for objects that appear in multiple revisions
* Output of `--pages` option of 'hexapdf inspect' command
* Infinite recursion problem in [HexaPDF::Task::Dereference]
* Problem with iteration over images in certain cases
* [HexaPDF::Type::Page#[]] with respect to inherited fields
* Problems with access permissions on encryption
* Encryption routine of standard security handler with respect to owner password
* Invalid check in validation of standard encryption dictionary
* 'hexapdf modify' command to support files with many pages
* Validation of encryption key for encryption revision 6
* Various parts of the API documentation


## 0.1.0 - 2016-10-26

* Initial release
