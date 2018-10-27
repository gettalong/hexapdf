## 0.8.0 - 2018-10-26

### Added

* [HexaPDF::Layout::Frame] for box positioning and easier text layouting
  inside an arbitrary polygon
* [HexaPDF::Layout::TextBox] for displaying text in a rectangular and for
  flowing text inside a frame
* [HexaPDF::Layout::WidthFromPolygon] for getting a width specification from
  a polygon for use with the text layouting engine
* [HexaPDF::Type::Image#width] and [HexaPDF::Type::Image#height] convenience
  methods
* [HexaPDF::Type::FontType3] for Type 3 font support
* [HexaPDF::Content::GraphicObject::Geom2D] for [Geom2D] object drawing support
* [HexaPDF::Type::Page#orientation] for easy determination of page orientation
* [HexaPDF::Type::Page#rotate] for rotating a page
* [HexaPDF::Layout::Style::Quad#set] for setting all values at once

### Changed

* [HexaPDF::Document#validate] to also yield the object that failed validation
* [HexaPDF::Type::Page#box] to allow setting the value for a box
* [HexaPDF::Layout::TextLayouter#fit] to allow fitting text into arbitrarily
  shaped areas
* [HexaPDF::Layout::TextLayouter] to return a new
  [HexaPDF::Layout::TextLayouter::Result] structure when `#fit` is called that
  includes the `#draw` method
* [HexaPDF::Layout::TextLayouter#fit] to require the height argument
* Refactored [HexaPDF::Layout::Box] to make using it a bit easier

### Fixed

* Validation and conversion of dictionary fields with multiple possible types
* Box border drawing when border width is greater than edge length

[geom2d]: https://github.com/gettalong/geom2d


## 0.7.0 - 2018-06-19

### Changed

* All Ruby source files use frozen string literal pragma
* [HexaPDF::MalformedPDFError::new] method signature
* [HexaPDF::Layout::TextFragment::new] and
  [HexaPDF::Layout::TextFragment::create] method signatures
* [HexaPDF::Encryption::SecurityHandler#set_up_encryption] argument `force_V4`
  to `force_v4`
* HexaPDF::Layout::TextLayouter#draw to return result of #fit if possible

### Removed

* Optional `leading` argument to HexaPDF::Content::Canvas#font_size method

### Fixed

* Misspelt variable name in [HexaPDF::Layout::TextLayouter::SimpleLineWrapping]
* [HexaPDF::Layout::TextLayouter::SimpleTextSegmentation] to work if the last
  character in a text fragment is \r
* [HexaPDF::Layout::TextLayouter] to work if an optional break point (think
  soft-hyphen) is followed by whitespace
* [HexaPDF::Font::TrueType::Builder] to correctly order the entries in the
  table directory
* [HexaPDF::Font::TrueType::Builder] to pad the table data to achieve the
  correct alignment
* [HexaPDF::Filter::FlateDecode] by removing the Zlib pools since they were
  not thread safe
* All color space classes to accept the color space definition as argument to
  `::new`


## 0.6.0 - 2017-10-27

### Added

* [HexaPDF::Layout::Box] as base class for all layout boxes
* More styling properties for [HexaPDF::Layout::Style]
* Methods for checking whether styling properties in [HexaPDF::Layout::Style]
  have been accessed or set
* [HexaPDF::FontLoader::FromFile] to allow specifying a font file directly
* Configuration option 'page.default_media_orientation' for settig the default
  orientation of new pages
* Convenience methods for getting underline and strikeout properties from fonts
* Configuration option 'style.layers_map' for pre-defining overlay and underlay
  callback objects for [HexaPDF::Layout::Style]
* [HexaPDF::Type::Action] as well as specific implementations for the GoTo,
  GoToR, Launch and URI actions
* [HexaPDF::Type::Annotation] as well as specific implementations for the Text
  Link annotations
* [HexaPDF::Layout::Style::LinkLayer] for easy adding of in-document, URI and
  file links

### Changed

* [HexaPDF::Layout::TextFragment] to support more styling properties
* Cross-reference subsection parsing can handle missing whitespace
* Renamed HexaPDF::Layout::LineFragment to [HexaPDF::Layout::Line]
* Renamed HexaPDF::Layout::TextBox to [HexaPDF::Layout::TextLayouter]
* [HexaPDF::Layout::TextFragment::new] and
  [HexaPDF::Layout::TextLayouter::new] to either take a Style object or
  style options
* [HexaPDF::Layout::TextLayouter#fit] method signature
* [HexaPDF::Layout::InlineBox] to wrap a generic box
* HexaPDF::Document::Fonts#load to [HexaPDF::Document::Fonts#add] for
  consistency
* [HexaPDF::Document::Pages#add] to allow setting the paper orientation when
  creating new pages
* [HexaPDF::Filter::Predictor] to allow correcting some common problems
  depending on the new configuration option 'filter.predictor.strict'
* Moved configuration options 'encryption.aes', 'encryption.arc4',
  'encryption.filter_map', 'encryption.sub_filter.map', 'filter.map',
  'image_loader' and 'task.map' to the document specific configuration object
* [HexaPDF::Configuration#constantize] can now dig into hierarchical values
* [HexaPDF::Document#wrap] class resolution and configuration option structure
  of 'object.subtype_map'

### Removed

* HexaPDF::Dictionary#to_hash method

### Fixed

* [HexaPDF::Layout::TextLayouter#fit] to split text fragment into parts if the
  fragment doesn't fit on an empty line
* Parsing of PDF files containing a loop with respect to cross-reference tables
* [HexaPDF::Layout::InlineBox] to act as placeholder if no drawing block is
  given
* Undefined method error in [HexaPDF::Content::Canvas] by raising a proper error
* Invalid handling of fonts by [HexaPDF::Content::Canvas] when saving and
  restoring the graphics state
* [HexaPDF::Layout::TextLayouter] so that text fragments don't pollute the
  graphics state
* [HexaPDF::Content::Operator::SetTextRenderingMode] to normalize the value
* [HexaPDF::Stream#stream_source] to always return a decrypted stream
* [HexaPDF::Layout::TextLayouter] to correctly indent all paragraphs, not just
  the first one
* One-off error in [HexaPDF::Filter::LZWDecode]
* [HexaPDF::Configuration#merge] to duplicate array values to avoid unwanted
  modifications
* [HexaPDF::Dictionary#key?] to return false if the key is present but nil
* [HexaPDF::DictionaryFields::FileSpecificationConverter] to convert hash and
  dictionaries
* Field /F definition in [HexaPDF::Stream]


## 0.5.0 - 2017-06-24

### Added

* HexaPDF::Layout::TextBox for easy positioning and layouting of text
* HexaPDF::Layout::LineFragment for single text line layout calculations
* [HexaPDF::Layout::TextShaper] for text shaping functionality
* [HexaPDF::Layout::TextFragment] for basic text metrics calculations
* [HexaPDF::Layout::InlineBox] for fixed size inline graphics
* [HexaPDF::Layout::Style] as container for text and graphics styling properties
* Support for kerning of TrueType fonts via the 'kern' table
* Support for determining the features provided by a font

### Changed

* Handling of invalid glyphs is done using the special
  [HexaPDF::Font::InvalidGlyph] class
* Configuration option 'font.on_missing_glyph'; returns an invalid glyph
  instead of raising an error
* Bounding box of TrueType glyphs without contours is set to `[0, 0, 0, 0]`
* Ligature pairs for AFM fonts are stored like kerning pairs
* Use TrueType configuration option 'font.true_type.unknown_format' in all
  places where applicable
* Allow passing a font object to [HexaPDF::Content::Canvas#font]
* Handle invalid entry in TrueType format 4 cmap subtable encountered in the
  wild gracefully
* Invalid positive descent values in font descriptors are now changed into
  negative ones by the validation feature
* Allow specifying the page media box or a page format when adding a new page
  through [HexaPDF::Document::Pages#add]

### Fixed

* [HexaPDF::Task::Dereference] to work correctly when encountering invalid
  references
* [HexaPDF::Tokenizer] and HexaPDF::Content::Tokenizer to parse a solitary
  plus sign
* Usage of Strings instead of Symbols for AFM font kerning and ligature pairs
* Processing the contents of form XObjects in case they don't have a resources
  dictionary
* Deletion of valid page node when optimizing page trees with the `hexapdf
  optimize` command
* [HexaPDF::Type::FontType0] to always wrap the descendant font even if it is a
  direct object


## 0.4.0 - 2017-03-19

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
