## Unreleased

### Added

* [HexaPDF::Document::Destinations#resolve] for resolving destination values
* [HexaPDF::Document::Destinations::Destination#value] to return the destination
  array
* Support for verifying document timestamp signatures

### Changed

* **Breaking change**: The crop box is now used instead of the media box in most
  cases to be in line with the specification
* [HexaPDF::Document::Signatures::DefaultHandler] to allow setting the used
  signature method
* **Breaking change**: [HexaPDF::Document::Signatures::DefaultHandler#sign]
  needs to accept the IO object and the byte range instead of just the data
* **Breaking change**: Enhanced support for outline items with new methods
  `#level` and `#destination_page` as well as changes to `#add` and `#each_item`

### Fixed

* [HexaPDF::Document::Destinations::Destination::new] to also accept a hash
* [HexaPDF::Type::Catalog] auto-conversion of /Outlines to correct class
* [HexaPDF::Type::AcroForm::Form#flatten] to return the unflattened form fields
  instead of the widgets
* [HexaPDF::Writer#write_incremental] to set the /Version in the catalog
  dictionary when necessary
* [HexaPDF::Importer#import] to always return an imported object with the same
  class as the argument
* [HexaPDF::Type::OutlineItem] to always be an indirect object
* [HexaPDF::Tokenizer#parse_number] to handle references correctly in all cases
* [HexaPDF::Type::Page#rotate] to correctly flatten all page boxes


## 0.26.2 - 2022-10-22

### Added

* Support for setting custom properties on [HexaPDF::Layout::Box] and
  [HexaPDF::Layout::TextFragment]

### Changed

* [HexaPDF::Layout::Style::LinkLayer] to use the 'link' custom box property if
  no target is set

### Fixed

* [HexaPDF::Layout::Style::Layers] to allow named layers without options
* [HexaPDF::Revision#each_modified_object] to not yield signature objects
* [HexaPDF::Revision#each_modified_object] to force comparison of direct objects
* [HexaPDF::Type::ObjectStream] to work for encrypted documents again


## 0.26.1 - 2022-10-14

### Changed

* [HexaPDF::Serializer] to provide better error messages when encountering
  unserializable objects

### Fixed

* [HexaPDF::Importer] to correctly expose previously mapped objects


## 0.26.0 - 2022-10-14

### Added

* Support for page labels
* [HexaPDF::Type::MarkInformation]

### Changed

* [HexaPDF::Rectangle] to recover from invalid values by defaulting to
  `[0, 0, 0, 0]`

### Fixed

* [HexaPDF::DictionaryFields::PDFByteStringConverter] to duplicate the string
  before conversion
* [HexaPDF::Type::FileSpecification#path=] to duplicate the given string value
  due to using it for two different fields


## 0.25.0 - 2022-10-02

### Added

* Support for the document outline
* [HexaPDF::Layout::Style#line_height] for setting a custom line height
  independent of the font size
* [HexaPDF::Document::Destinations#use_or_create] as unified interface for
  using or creating destinations
* [HexaPDF::Document::Destinations::Destination#valid?] and class method for
  checking whether a destination array is valid

### Fixed

* Calculation of text related [HexaPDF::Layout::Style] values for Type3 fonts
* [HexaPDF::Encryption::SecurityHandler#encrypt_string] to either return a
  dupped or encrypted string
* [HexaPDF::Layout::TextLayouter#fit] to avoid infinite loop when encountering
  a non-zero width breakpoint penalty
* [HexaPDF::Type::ObjectStream] to parse the initial stream data right after
  initialization to avoid access errors
* [HexaPDF::Revisions::from_io] to merge a completely empty revision with just a
  /XRefStm pointing into the previous one with the latter
* [HexaPDF::Revisions::from_io] to handle the case of the configuration option
  'parser.try_xref_reconstruction' being false


## 0.24.2 - 2022-08-31

### Fixed

* [HexaPDF::Importer] to detect loops in a fully-loaded document
* HexaPDF::Type::PageTreeNode#perform_validation to only do the validation for
  the document's root page tree node
* HexaPDF::Type::Page#perform_validation to only do the validation if the page
  is part of the document's page tree
* Box layouting to take small floating point differences into account


## 0.24.1 - 2022-08-11

### Added

* [HexaPDF::TestUtils] module that contains helper methods useful for testing
  various parts of HexaPDF

### Changed

* All applicable places to only load the current version of PDF objects, to
  avoid possible inconsistencies when working with files containing multiple
  revisions

### Fixed

* Parsing of streams with an invalid length value that led to a parsing error
* [HexaPDF::Object#==] to only allow comparing simple values to non-indirect
  objects and not also other HexaPDF::Object instances


## 0.24.0 - 2022-08-01

### Added

* [HexaPDF::Layout::ListBox] for rendering ordered and unordered lists
* [HexaPDF::Layout::ColumnBox] for rendering content inside columns
* [HexaPDF::Layout::BoxFitter] for placing boxes into multiple frames
* New configuration option 'debug' for enabling debug output
* [HexaPDF::Document::Pages#move] for moving pages around the same document
* [HexaPDF::Composer#box] for drawing arbitrary, registered boxes
* [HexaPDF::Layout::Box#split_box?] for determining whether a box is a split
  box, i.e. the continuation of another box
* [HexaPDF::Document::Layout::ChildrenCollector] to provide an easy method for
  defining children boxes of a container box

### Changed

* **Breaking change**: Refactored [HexaPDF::Layout::Frame] and associated data
  structures so that the complete result of fitting a box is returned
* [HexaPDF::Layout::Frame] to use a better algorithm for trimming the shape
* [HexaPDF::Layout::Frame::new] to allow setting the initial shape
* **Breaking change**: Removed contour line from [HexaPDF::Layout::Frame]
* **Breaking change**: Changed positional arguments of
  [HexaPDF::Layout::TextBox::new] and [HexaPDF::Layout::ImageBox::new] to
  keyword arguments for a consistent box initialization interface
* [HexaPDF::Layout::Box#split] to provide a default implementation that is
  useful for most subclasses
* Layout box implementations to provide a `#supports_position_flow?` method that
  indicates whether the box supports flowing its content around other content.
* `hexapdf info --check` to only check the current version of each object
* [HexaPDF::Writer] to make sure the producer information is written when
  writing the file incrementally

### Fixed

* [HexaPDF::Layout::TextLayouter] to freeze the new items when a text fragment
  needs to be split
* [HexaPDF::Layout::TextLayouter] to avoid the possible splitting of a text
  fragment if there would not be enough height left anyway
* [HexaPDF::Layout::WidthFromPolygon] to work correctly in case of very small
  floating point errors
* HexaPDF::Layout::TextFragment#inspect to work in case of interspersed
  numbers
* [HexaPDF::Layout::TextBox#split] to work for position :flow when box is wider
  than the initial available width
* [HexaPDF::Layout::Frame#fit] to create minimally sized mask rectangles
* [HexaPDF::Content::GraphicObject::Geom2D] to close the path when drawing
  polygons
* [HexaPDF::Layout::WidthFromPolygon] to work for all counterclockwise polygons
* [HexaPDF::Type::PageTreeNode#move_page] to work in case the parent node of the
  moved node doesn't change
* [HexaPDF::Type::PageTreeNode#move_page] to use the correct target position
  when the moved node is before the target position
* [HexaPDF::Document::Signatures#add] to work in case the signature object is
  the last object written
* CLI command `hexapdf inspect` to show correct byte range of the last revision
* [HexaPDF::Writer#write_incremental] to only use a cross-reference stream if a
  revision directly used one and not through an `/XRefStm` entry
* [HexaPDF::Encryption::FastARC4] to use RubyARC4 as fallback if OpenSSL has RC4
  disabled
* [HexaPDF::Font::Encoding::GlyphList] to use binary reading to avoid problems
  on Windows
* [HexaPDF::Document::Signatures#add] to use binary writing to avoid problems on
  Windows


## 0.23.0 - 2022-05-26

### Added

- [HexaPDF::Composer#create_stamp] for creating a form Xobject
- [HexaPDF::Revision#reset_objects] for deleting all live loaded and added
  objects
- Support for removing or flattening annotations to the `hexapdf modify` command
- Option to CLI command `hexapdf form` to allow generation of a template file
- Support for centering a floating box in [HexaPDF::Layout::Frame]
- [HexaPDF::Type::Catalog#names] for easier access to the name dictionary
- [HexaPDF::Type::Names#destinations] for easier access to the destinations name
  tree
- [HexaPDF::Document::Destinations], accessible via
  [HexaPDF::Document#destinations], as convenience interface for working with
  destination arrays

### Changed

- **Breaking change**: Refactored the [HexaPDF::Document] interface for working
  with objects and move parts into [HexaPDF::Revisions]
- **Breaking change**: [HexaPDF::Layout::TextBox] to use whole available width
  when aligning to the center or right
- **Breaking change**: [HexaPDF::Layout::TextBox] to use whole available height
  when vertically aligning to the center or bottom
- CLI command `hexapdf inspect` to show the type of revisions, as well as the
  number of objects per revision
- [HexaPDF::Task::Optimize] to allow skipping invalid content stream operations
- [HexaPDF::Composer#image] to allow using a form xobject in place of the image

### Fixed

- [HexaPDF::Writer#write] to write modified objects into the correct revision
- [HexaPDF::Revisions::from_io] to correctly handle hybrid-reference files
- [HexaPDF::Writer] to assign a valid object number to a created cross-reference
  stream in all cases
* [HexaPDF::Type::AcroForm::TextField] to validate the existence of a /MaxLen
  value for comb text fields
* [HexaPDF::Type::AcroForm::TextField#field_value=] to check for the existence
  of /MaxLen when setting a value for a comb text field
* [HexaPDF::Type::AcroForm::TextField#field_value=] to check the value against
  /MaxLen
* [HexaPDF::Layout::TextLayouter#fit] to not use style valign when doing
  variable width layouting
* [HexaPDF::Utils::SortedTreeNode#find_entry] to work in case of a node without
  a container name or kids key
* CLI command `hexapdf form` to allow setting array values when using a template
* CLI command `hexapdf form` to allow setting file select fields


## 0.22.0 - 2022-03-26

### Added

- Support for writing images with an ICCBased color space
- Support for writing images with soft masks

### Changed

- CLI command `hexapdf form` to show a warning when working with a file
  containing an XFA form

### Fixed

- [HexaPDF::Type::AcroForm::Form#field_by_name] to work correctly when field
  name parts are UTF-16BE encoded
- `hexapdf inspect` command 'revision' to correctly detect the end of revisions
- [HexaPDF::DictionaryFields::StringConverter] to use correct method name
  `HexaPDF::Document#config`


## 0.21.1 - 2022-03-12

### Fixed

- Handling of invalid AES encrypted files where the padding is missing


## 0.21.0 - 2022-03-04

### Added

* [HexaPDF::Parser#reconstructed?] which returns true if the cross-reference
  table was reconstructed
- [HexaPDF::Layout::Style::create] for easier creation of style objects
* The ability to view revisions of a PDF document or extract a single revision
  via `hexapdf inspect`

### Changed

* **Breaking change**: Refactored [HexaPDF::Composer] for better and more
  consistent style support
* **Breaking change**: Arguments for configuration option
  'font.on_missing_glyph' have changed to allow access to the document instance

### Fixed

* Setter for [HexaPDF::Layout::Style#line_spacing] to allow usage of numeric
  arguments
* Digital Signature validation for 'adbe.pkcs7.detached' certifiates in case no
  key usage was defined
* Removed caching of configuration 'font.on_missing_glyph' in font wrappers to
  avoid problems


## 0.20.4 - 2022-01-26

### Fixed

* Regression when using Type1 font with different encodings


## 0.20.3 - 2022-01-24

### Changed

* Appearance of signature field values when using the `hexapdf form` command

### Fixed

* Writing of encrypted PDF files in incremental node in case the encryption was
  changed
* [HexaPDF::Type::Annotation#appearance] to return correctly wrapped object in
  case of Form XObjects missing required data
* Decrypting of files with multiple revisions


## 0.20.2 - 2022-01-17

### Fixed

* [HexaPDF::Task::Optimize] so that page resource pruning works for pages
  without XObjects


## 0.20.1 - 2022-01-05

### Changed

* Refactored signature handlers, making `#store_verification_callback` a
  protected method

### Fixed

* [HexaPDF::Task::Dereference] to work for even very deeply nested structures


## 0.20.0 - 2021-12-30

### Added

* Support for signing a PDF using a digital signature
* Support for reading and validating digital signatures
* Output info regarding digital signatures when using the `hexapdf info` command
* [HexaPDF::Type::AcroForm::Form#create_signature_field] for adding signature
  fields
* [HexaPDF::Type::Annotation::AppearanceDictionary#set_appearance] for setting
  the appearance stream
* [HexaPDF::Type::Annotation#create_appearance] for creating an empty appearance
  stream

### Changed

* **Breaking change**: Method signature of
  [HexaPDF::Type::Annotation#appearance] changed
* [HexaPDF::Object#==] to allow comparison to simple value if not indirect
* [HexaPDF::Type::AcroForm::Form] to use an empty array as default for the
  /Fields field
* [HexaPDF::Type::ObjectStream] to not store signature fields in object streams
* [HexaPDF::Writer] to return the last written cross-reference section
* [HexaPDF::Type::AcroForm::Field#create_widget] to automatically set the print
  flag and assign the page

### Fixed

* Incremental writing of files in cases where object streams were deleted (e.g.
  when using the `optimize: true` argument when writing)
* Comparison of non-indirect [HexaPDF::Object] instances with other
  HexaPDF::Object instances
* Deleting of objects via [HexaPDF::Revision#delete] to re-use the
  [HexaPDF::PDFData] object of the deleted object when using
  `mark_as_free: true`
* [HexaPDF::Revision#each_modified_object] to work correctly for dictionary
  objects even if a value is changed only by reading it


## 0.19.3 - 2021-12-14

### Fixed

* Handling of invalid files where the "startxref" keyword and its value are on
  the same line


## 0.19.2 - 2021-12-14

### Fixed

* Set the trailer's ID field to an array of two empty strings when decrypting in
  case it is missing
* Incremental writing when one of the existing revisions contains a
  cross-reference stream


## 0.19.1 - 2021-12-12

### Added

* [HexaPDF::Type::FontType3#bounding_box] to fix content stream processing error

### Fixed

* Calculation of scaled font size for [HexaPDF::Content::GraphicsState] and
  [HexaPDF::Layout::Style] when Type3 fonts are used


## 0.19.0 - 2021-11-24

### Added

* Page resource pruning to the optimization task
* An option for page resources pruning to the optimization options of the
  `hexapdf` command

### Fixed

* Handling of invalid date strings with a minute time zone offset greater than
  59


## 0.18.0 - 2021-11-04

### Added

* [HexaPDF::Content::ColorSpace::serialize_device_color] for serialization of
  device colors in parts other than the canvas
* [HexaPDF::Type::AcroForm::VariableTextField::create_appearance_string] for
  centralized creation of appearance strings
* [HexaPDF::Object::make_direct] for making objects and all parts of them direct
  instead of indirect

### Changed

* [HexaPDF::Type::AcroForm::VariableTextField::parse_appearance_string] to also
  return the font color
* [HexaPDF::Type::AcroForm::VariableTextField#set_default_appearance_string] to
  allow specifying the font color
* [HexaPDF::Type::AcroForm::Form] methods to support new variable text field
  methods
* [HexaPDF::Type::AcroForm::AppearanceGenerator] to support the set font color
  when creating text field appearances

### Fixed

* Writing of existing, encrypted PDF files where parts of the encryption
  dictionary are indirect objects
* [HexaPDF::Content::GraphicObject::EndpointArc] to correctly determine the
  start and end points
* HexaPDF::Dictionary#perform_validation to correctly handle objects that
  should not be indirect objects


## 0.17.3 - 2021-10-31

### Fixed

* Reconstruction of invalid PDF files where the PDF header is not at the start
  of the file
* Reconstruction of invalid PDF files where the first object is invalid


## 0.17.2 - 2021-10-26

### Fixed

* Deployment of HexaPDF's Rubygem


## 0.17.1 - 2021-10-21

### Fixed

* Handling of files containing invalid UTF-16 strings


## 0.17.0 - 2021-10-21

### Added

* CLI command `hexapdf fonts` for listing fonts of a PDF file
* [HexaPDF::Layout::Style#background_alpha] for defining the opacity of the
  background
* [HexaPDF::Type::Page#each_annotation] for iterating over all annotations of a
  page

### Changed

* **Breaking change**: Handling of AcroForm check boxes to allow multiple
  widgets with different values
* CLI command `hexapdf form` to support new check box features
* [HexaPDF::Content::Canvas#text] to use the font size as leading if no leading
  has been set
* [HexaPDF::Content::Canvas#line_with_rounded_corner] to be a public method
* [HexaPDF::Layout::Style::LineSpacing] to allow using integers or floats as
  type argument to mean proportional line spacing
* [HexaPDF::Type::AcroForm::VariableTextField#set_default_appearance_string] to
  allow specifying font options
* AcroForm text field creation methods in [HexaPDF::Type::AcroForm::Form] to
  allow specifying font options

### Fixed

* [HexaPDF::Type::AcroForm::Field#each_widget] to also return widgets of other
  form fields that have the same name
* `hexapdf form` to allow filling in multiline and comb text fields
* `hexapdf form` to correctly work for PDF files containing null values in the
  list of annotations
* Handling of files that contain invalid default appearance strings
* [HexaPDF::Type::AcroForm::TextField#field_value] to allow setting a `nil`
  value for single line text fields
* [HexaPDF::Content::GraphicObject::Arc] to respect the value set by the
  `#max_curves` accessor


## 0.16.0 - 2021-09-28

### Added

* Support for RGB color values of the form "RGB" in addition to "RRGGBB" and for
  CSS color module level 3 color names
* Conversion module for Integer fields to fix certain invalid PDF files


## 0.15.9 - 2021-09-04

### Fixed

* Handling of files that contain stream length values that are indirect objects
  not referring to a number


## 0.15.8 - 2021-08-16

### Fixed

* Regression when using `-v` with the hexapdf command line tool


## 0.15.7 - 2021-07-17

### Fixed

* Infinite loop while parsing PDF array due to missing closing bracket
* Handling of invalid files with missing or corrupted trailer dictionary


## 0.15.6 - 2021-07-16

### Fixed

* Handling of indirect objects with invalid values which are now treated as null
  objects


## 0.15.5 - 2021-07-06

### Changed

* Refactored [HexaPDF::Tokenizer#next_xref_entry] and changed yielded value


### Fixed

* Handling of invalid cross-reference stream entries that ends with the sequence
  `\r\r`


## 0.15.4 - 2021-05-27

### Fixed

* [HexaPDF::Type::Annotation#appearance] to handle cases where there is
  no valid appearance stream


## 0.15.3 - 2021-05-01

### Fixed

* Handling of general (not document-level), unencrypted metadata streams


## 0.15.2 - 2021-05-01

### Fixed

* Handling of unencrypted metadata streams


## 0.15.1 - 2021-04-15

### Fixed

* Potential division by zero when calculating the scaling for XObjects
* Handling of XObjects with a width or height of zero when drawing on canvas


## 0.15.0 - 2021-04-12

### Added

* [HexaPDF::Type::Page#flatten_annotations] for flattening the annotations of a
  page
* [HexaPDF::Type::AcroForm::Form#flatten] for flattening interactive forms
* [HexaPDF::Revision#update] for updating the stored wrapper class of a PDF
  object
* [HexaPDF::Type::AcroForm::SignatureField] for working with AcroForm signature
  fields
* Support for form field flattening to the `hexapdf form` CLI command

### Changed

* **Breaking change**: Overhauled the interface for accessing appearances of
  annotations to make it more convenient
* Validation of [HexaPDF::Type::FontDescriptor] to delete invalid `/FontWeight`
  value
* [HexaPDF::MalformedPDFError#pos] an accessor instead of a reader and update
  the exception message
* Configuration option 'acro_form.fallback_font' to allow a callable object for
  more advanced fallback font handling

### Fixed

* [HexaPDF::Type::Annotations::Widget#background_color] to correctly handle
  empty background color arrays
* [HexaPDF::Type::AcroForm::Field#delete_widget] to update the wrapper object
  stored in the document in case the widget is embedded
* Processing of invalid PDF files containing a space,CR,LF combination after
  the 'stream' keyword
* Cross-reference stream reconstruction with respect to detection of linearized
  files
* Detection of existing appearances for AcroForm push button fields when
  creating appearances


## 0.14.4 - 2021-02-27

### Added

* Support for the Crypt filters

### Changed

* [HexaPDF::MalformedPDFError] to make the `pos` argument optional

### Fixed

* Handling of invalid floating point numbers NaN, Inf and -Inf when serializing
* Processing of invalid PDF files containing NaN and Inf instead of numbers
* Bug in Type1 font AFM parser that occured if the file doesn't end with a new
  line character
* Cross-reference table reconstruction to handle the case of an entry specifying
  a non-existent indirect object
* Cross-reference table reconstruction to handle trailers specified by cross-
  reference streams
* Cross-reference table reconstruction to use the set security handle for
  decrypting indirect objects
* Parsing of cross-reference streams where data is missing


## 0.14.3 - 2021-02-16

### Fixed

* Bug in [HexaPDF::Font::TrueType::Subsetter#use_glyph] which lead to corrupt
  text output
* [HexaPDF::Serializer] to handle infinite recursion problem
* Cross-reference table reconstruction to avoid an O(n^2) performance problem
* [HexaPDF::Type::Resources] validation to handle an invalid `/ProcSet` entry
  containing a single value instead of an array
* Processing of invalid PDF files missing a required value in appearance streams
* Processing of invalid empty arrays that should be rectangles by converting
  them to PDF null objects
* Processing of invalid PDF files containing indirect objects with offset 0
* Processing of invalid PDF files containing a space/CR or space/LF combination
  after the 'stream' keyword


## 0.14.2 - 2021-01-22

### Fixed

* [HexaPDF::Font::TrueType::Subsetter#use_glyph] to really avoid using subset
  glyph ID 41 (`)`)


## 0.14.1 - 2021-01-21

### Changed

* Validation message when checking for allowed values to include the invalid
  object
* [HexaPDF::FontLoader::FromFile] to allow (re)using an existing font object
* [HexaPDF::Importer] internals to avoid problems with retained memory

### Fixed

* Parsing of invalid PDF files where whitespace is missing after the integer
  value of an indirect object
* [HexaPDF::Dictionary] so that adding new key-value pairs during validation is
  possible


## 0.14.0 - 2020-12-30

### Added

* Support for creating AcroForm multiline text fields and their appearances
* Support for creating AcroForm comb text fields and their appearances
* Support for creating AcroForm password fields and their appearances
* Support for creating AcroForm file select fields and their appearances
* Support for creating AcroForm list box appearances
* [HexaPDF::Type::AcroForm::ChoiceField#list_box_top_index] and its setter
  method
* [HexaPDF::Type::AcroForm::ChoiceField#update_widgets] to create appearances if
  they don't exist
* Methods for caching data to [HexaPDF::Object]
* Support for splitting by page size to CLI command `hexapdf split`

### Changed

* [HexaPDF::Utils::ObjectHash#oids] to be public instead of private
* Cross-reference table parsing to handle invalidly numbered main sections
* [HexaPDF::Document#cache] and [HexaPDF::Object#cache] to allow updating
  values for existing keys
* Appearance creation methods of AcroForm objects to allow forcing the creation
  of new appearances
* [HexaPDF::Type::AcroForm::AppearanceGenerator#create_text_appearances] to
  re-use existing form objects
* AcroForm field creation methods to allow specifying often used field
  properties

### Fixed

* Missing usage of `:sort` flag for AcroForm choice fields
* Setting the `/I` field for AcroForm list boxes with multiple selection
* [HexaPDF::Layout::TextLayouter::SimpleLineWrapping] to remove glue items
  (whitespace) before a hard line break
* Infinite loop when reconstructing the cross-reference table
* [HexaPDF::Type::AcroForm::ChoiceField] to support export values for option
  items
* AcroForm text field appearance creation to only create a new appearance if the
  field's value has changed
* AcroForm choice field appearance creation to only create a new appearance if
  the involved dictionary fields' values have changed
* [HexaPDF::Type::AcroForm::ChoiceField#list_box_top_index=] to raise an error
  if no option items are set
* [HexaPDF::PDFArray#to_ary] to return an array with preprocessed values
* [HexaPDF::Type::Form#contents=] to clear cached values to avoid returning e.g.
  an invalid canvas object later
* [HexaPDF::Type::AcroForm::ButtonField#update_widgets] to create appearances if
  they don't exist


## 0.13.0 - 2020-11-15

### Added

* Cross-reference table reconstruction for damaged PDFs, controllable via the
  new 'parser.try_xref_reconstruction' option
* Two new `hexapdf inspect` commands for showing page objects and page content
  streams by page number
* Flag `--check` to the CLI command `hexapdf info` for checking a file for
  parse and validation errors
* [HexaPDF::Type::AcroForm::Field#embedded_widget?] for checking if a widget is
  embedded in the field object
* [HexaPDF::Type::AcroForm::Field#delete_widget] for deleting a widget
* [HexaPDF::PDFArray#delete] for deleting an object from a PDF array
* [HexaPDF::Type::Page#ancestor_nodes] for retrieving all ancestor page tree
  nodes of a page
* [HexaPDF::Type::PageTreeNode#move_page] for moving a page to another index

### Changed

* **Breaking change**: Overhauled document/object validation interfaces and
  internals to be more similar and to allow for reporting of multiple validation
  problems
* Validation of TrueType fonts to ignore missing fields if the font name
  suggests that the font is one of the standard 14 PDF fonts
* Option `-p` of CLI command `hexapdf image2pdf` to also allow lowercase page
  size names

### Fixed

* Reporting of cross-reference section entry parsing error
* PDF version used by default for dictionary fields
* Error in CLI command `hexapdf inspect` when parsing an invalid object number
* Output of error messages in CLI command `hexapdf inspect` to go to `$stderr`
* Bug in [HexaPDF::Type::AcroForm::TextField] validation due to missing nil
  handling


## 0.12.3 - 2020-08-22

### Changed

* Allow any object responding to `#to_sym` when setting a radio button value

### Fixed

* Error in the AcroForm appearance generator for text fields when the font is
  not found in the default resources
* Parsing of long numbers when reading a file from IO
* Usage of unsupported method for Ruby 2.4 so that all tests pass again


## 0.12.2 - 2020-08-17

### Fixed

- Wrong origin for page canvases when bottom left corner of media box doesn't
  coincide with origin of coordinate system
- Wrong origin for Form XObject canvas when bottom left corner of bounding box
  doesn't coincide with origin of coordinate system


## 0.12.1 - 2020-08-16

### Added

* [HexaPDF::Font::Encoding::Base#code] for retrieving the code for a given
  glyph name

### Fixed

* [HexaPDF::Font::Type1Wrapper#encode] to correctly resolve the code for a glyph
  name


## 0.12.0 - 2020-08-12

### Added

* Convenience methods for accessing field flags for
  [HexaPDF::Type::AcroForm::Field]
* [HexaPDF::Type::AcroForm::TextField] and
  [HexaPDF::Type::AcroForm::VariableTextField] for basic text field support
* [HexaPDF::Type::AcroForm::ButtonField] for push button, radio button and
  check box support
* [HexaPDF::Type::AcroForm::ChoiceField] for combo box and list box support
* [HexaPDF::Type::AcroForm::AppearanceGenerator] as central class for
  generating appearance streams for form fields
* Various convenience methods for [HexaPDF::Type::AcroForm::Form]
* Various convenience methods for [HexaPDF::Type::AcroForm::Field]
* Various convenience methods for [HexaPDF::Type::Annotations::Widget]
* [HexaPDF::Type::Annotation::AppearanceDictionary]
* [HexaPDF::Document#acro_form] and [HexaPDF::Type::Catalog#acro_form]
  convenience methods
* CLI command `hexapdf form` for listing fields of interactive forms and filling
  them out
* [HexaPDF::Rectangle] methods for setting the left, top, right, bottom, width
  and height
* Method #prenormalized_color to all color space implementations
* [HexaPDF::Type::Font#font_wrapper] for accessing an associated font wrapper
  instance
* [HexaPDF::Type::FontType1#font_wrapper] for providing a font wrapper for the
  standard PDF fonts
* [HexaPDF::Type::Annotation::Border] class
* [HexaPDF::Content::ColorSpace::device_color_from_specification] for easily
  getting a device color object
* [HexaPDF::Content::ColorSpace::prenormalized_device_color] for getting a device
  color object without normalizing values
* [HexaPDF::Type::Annotation#appearance] for returning the associated appearance
  dictionary
* [HexaPDF::Type::Annotation#appearance?] for checking whether an appearance for
  the annotation exists
* Configuration option 'acro_form.create_appearance_streams' for automatically
  creating appearance streams
* [HexaPDF::Type::Resources] methods `#pattern` and `add_pattern`

### Changed

* Deletion of pages to delete them from the document as well
* Refactored [HexaPDF::Font::Type1Wrapper] and [HexaPDF::Font::TrueTypeWrapper]
  and renamed `#dict` to `#pdf_object`
* Fall back to the Type1 font's internal encoding when decoding a string
* All [HexaPDF::Content::ColorSpace] implementations to only normalize values
  when using the ::color method
* [HexaPDF::Content::Parser#parse] to also accept a block in place of a
  processor object
* HexaPDF::Type::AcroForm::Field#full_name to
  [HexaPDF::Type::AcroForm::Field#full_field_name]
* Moved `HexaPDF::Content::Canvas#color_space_for_components` to class method on
  [HexaPDF::Content::ColorSpace]
* Added bit unsetter method to[HexaPDF::Utils::BitField]
* [HexaPDF::Type::AcroForm::Form#find_root_fields] and `#each_field` to take the
  field type into account when wrapping a field dictionary
* Pages specification of CLI commands to allow counting from the end using the
  new `r<N>` notation
* [HexaPDF::Font::Type1Wrapper] to use the internal encoding of a font with a
  'Special' character set instead of a custom encoding
* Configuration 'filter.map' to use the pass-through filter on all unsupported
  filters

### Fixed

* Wrong normalization of color values when invoking a color operator
* Invalid type of `/DR` field of [HexaPDF::Type::AcroForm::Form]
* Invalid ordering of types for the `/V` and `/DV` fields of
  [HexaPDF::Type::AcroForm::Field]
* [HexaPDF::Type::AcroForm::Field#terminal_field?] to work according to the spec
* Handling of empty files by throwing better error messages
* [HexaPDF::Type::Image#info] to correctly identify images with a soft mask as
  currently not supported for writing
* [HexaPDF::Revision#delete] to remove the connection between the object and the
  document
* Missing `#definition` method of `DeviceRGB`, `DeviceCMYK` and `DeviceGray`
  color spaces
* Handling of 'Pattern' color spaces when parsing content streams


## 0.11.9 - 2020-06-15

### Changed

* Encryption dictionaries to always be indirect objects


## 0.11.8 - 2020-06-11

### Fixed

* Serialization of special `/` (zero-length name) object in dictionaries and
  arrays


## 0.11.7 - 2020-06-10

### Fixed

* Deletion of object streams in [HexaPDF::Task::Optimize] to avoid accessing
  then invalid object streams
* [HexaPDF::Task::Optimize] to work correctly when deleting object streams and
  generating xref streams


## 0.11.6 - 2020-05-27

### Fixed

* [HexaPDF::Layout::TextBox] to respect the set width and height when fitting
  and splitting the box


## 0.11.5 - 2020-01-27

### Changed

* [HexaPDF::Font::TrueType::Table::CmapSubtable] to lazily parse the subtable
* [HexaPDF::Font::TrueType::Table::Hmtx] to lazily parse the width data
* CLI command `hexapdf image2pdf` to use the last argument as output file
  instead of the first (same order as `merge`)
* Automatically require the HexaPDF C extension if it is installed

### Fixed

* Wrong line length calculation for variable width layouting when a text box is
  too wide and needs to be broken into parts
* CLI command `hexapdf image2pdf` so that treating a PDF as image works


## 0.11.4 - 2019-12-28

### Fixed

* Memory consumption problem of PNG image loader when using images with alpha
  channel


## 0.11.3 - 2019-11-27

### Fixed

* Restore compatibility with Ruby 2.4


## 0.11.2 - 2019-11-22

### Fixed

* Conversion of [HexaPDF::Rectangle] type when the original is not a plain
  Array but a [HexaPDF::PDFArray]


## 0.11.1 - 2019-11-19

### Fixed

* [HexaPDF::Type::AcroForm::Form#find_root_fields] to work for documents where
  not all pages have form fields


## 0.11.0 - 2019-11-19

### Added

* [HexaPDF::PDFArray] to wrap arrays and allow automatic resolution of
  references like with [HexaPDF::Dictionary] - MAY BREAK THINGS!
* CLI command `hexapdf watermark` to apply a watermark PDF as background or
  stamp onto another PDF file
* CLI command `hexapdf image2pdf` to convert images into a PDF file
* [HexaPDF::DictionaryFields::Field#allowed_values] to allow constraining a
  field to certain allowed values
* [HexaPDF::Document::Fonts#configured_fonts] to return all font variants that
  are configured and available for adding to a document
* [HexaPDF::Type::Annotations::Widget] and associated classes
* [HexaPDF::Type::AcroForm::Form] and [HexaPDF::Type::AcroForm::Field] for basic
  AcroForm support

### Changed

* Use Reline for interactive mode of `hexapdf inspect` if available
* [HexaPDF::DictionaryFields::Field::new] to use keyword arguments
* Update the field information for implemented PDF types to include the allowed
  values where possible
* Interface of font loader objects to allow another method `available_fonts` for
  returning all available fonts
* [HexaPDF::Layout::Style] to check for valid values where possible

### Fixed

* Line spacing of empty lines for [HexaPDF::Layout::TextLayouter]
* Handling of `/DecodeParms` when exporting to PNG images


## 0.10.0 - 2019-10-02

### Added

* [HexaPDF::Reference#to_s] to return the serialized form of the PDF reference
* [HexaPDF::Revision#xref] for getting cross-reference entries
* HexaPDF::XRefSection::Entry#to_s to return a description of the
  cross-reference entry

### Changed

* Enhanced the `hexapdf images` command to also show information on PPI (pixels
  per inch) and size
* Completely revamped the `hexapdf inspect` command with an interactive mode,
  structure output, cross-reference entry output and object search
* Output of validation problem messages for `hexapdf` command to include more
  information
* The Validation feature to automatically correct String-for-Symbol and
  Symbol-for-String problems

### Fixed

* [HexaPDF::Document#wrap] to better handle subtype mappings in case of unknown
  type information
* [HexaPDF::DictionaryFields::DictionaryConverter] to not allow conversion to a
  [HexaPDF::Stream] subclass from objects without stream data
* Import of JPEG images with YCCK color encoding
* Export of images without `/FlateDecode` filter or `/DecodeParms` to PNG files
* Mistyped name of field type for field `/Popup` of
  [HexaPDF::Type::Annotations::MarkupAnnotation]
* Loading and saving of encrypted and signed PDFs
* CLI commands that optimize font data structures won't crash when encountering
  invalid font objects


## 0.9.3 - 2019-06-13

### Changed

* Behaviour of how object streams are generated to work around a bug (?) in
  Adobe Acrobat

### Fixed

* Fix problem with [HexaPDF::Encryption::StandardSecurityHandler] due to
  behaviour change of Ruby 2.6.0 in `String#setbyte`

## 0.9.2 - 2019-05-22

### Changed

* [HexaPDF::Encryption::AES] to handle invalid padding
* [HexaPDF::Filter::FlateDecode] to correctly handle invalid empty streams

## 0.9.1 - 2019-03-26

### Fixed

* [HexaPDF::Serializer] to avoid infinite loops for self-referencing streams
* Bug due to frozen string in [HexaPDF::Font::CMap::Writer]


## 0.9.0 - 2018-12-31

### Added

* [HexaPDF::Composer] for composing PDF documents in a high-level way
* Incremental writing support (i.e. appending a single revision with all the
  changes to an existing document) to [HexaPDF::Writer] and [HexaPDF::Document]
* CLI command `hexapdf split` to split a PDF file into individual pages
* [HexaPDF::Revisions#parser] for accessing the parser object that is created
  when a document is read from an IO stream
* [HexaPDF::Document#each] argument `only_loaded` for iteration over loaded
  objects only
* [HexaPDF::Document#validate] argument `only_loaded` for validating only loaded
  objects
* [HexaPDF::Revision#each_modified_object] for iterating over all modified
  objects of a revision
* [HexaPDF::Layout::Box#split] and [HexaPDF::Layout::TextBox#split] for
  splitting a box into two parts
* [HexaPDF::Layout::Frame#full?] for testing whether the frame has any space
  left
* [HexaPDF::Layout::Style] property `last_line_gap` for controlling the spacing
  after the last line of text
* HexaPDF::Layout::Box#draw_content for use by subclasses
* [HexaPDF::Type::Form#width] and [HexaPDF::Type::Form#height] for compatibility
  with [HexaPDF::Type::Image]
* [HexaPDF::Layout::ImageBox] for displaying an image inside a frame

### Changed

* [HexaPDF::Revision#each] to allow iteration over loaded objects only
* [HexaPDF::Document#each] method argument from `current` to `only_current`
* [HexaPDF::Object#==] and [HexaPDF::Reference#==] so that Object and Reference
  objects can be compared
* Refactored [HexaPDF::Layout::Frame] to allow separate fitting, splitting and
  drawing of boxes
* [HexaPDF::Layout::Style::LineSpacing::new] to allow setting of line spacing
  via a single hash argument
* Made [HexaPDF::Layout::Style] copyable

### Fixed

* Configuration so that annotation objects are correctly mapped to classes
* Fix problem with [HexaPDF::Filter::Predictor] due to behaviour change of Ruby
  2.6.0 in `String#setbyte`
* Fitting of [HexaPDF::Layout::TextBox] when the box has padding and/or borders
* Fitting of [HexaPDF::Layout::TextBox] when width and/or height has been set
* Fitting of absolutely positioned boxes in [HexaPDF::Layout::Frame]
* Fix bug in variable width line wrapping due to not considering line spacing
  correctly ([HexaPDF::Layout::Line::HeightCalculator#simulate_height] return
  value needed to be changed for this fix)

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
