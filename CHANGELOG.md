## 0.2.0 - unreleased

### Added

* PDF file merge ability to `hexapdf modify`, i.e. adding pages from other PDFs
* Page interleaving support to 'hexapdf modify'
* Step values in pages definitions for CLI commands
* Convenience class for working with pages through `Document#pages` with a more
  Ruby-like interface
* Method `XObject#canvas`
* Method `Page#index`
* Validation for `Rectangle` objects
* `Type1::FontMetrics#weight_class` for returning the numeric weight

### Changed

* Refactor document utilities into own classes with a more Ruby-like interface;
  concern fonts, images and files, now accessible through `Document#fonts`,
  `Document#images` and `Document#files`
* Validate nested collection values in `HexaPDF::Object`
* Allow `Dictionary#[]` to always unwrap nil values
* Update `Task::Optimize` to delete unused objects on `:compact`
* Allow `PageTreeNode#delete_page` to take a page object or a page index
* Don't set /EFF key in encryption dictionary
* Better error handling for hexapdf CLI commands
* Show help output when no command is given for `hexapdf` CLI
* Set /FontWeight in `Type1Wrapper`
* Use kramdown's man page support for the `hexapdf` man page instead of ronn

### Removed

* Remove unneeded parts of TrueType implementation

### Fixed

* Problem with unnamed classes/modules on serialization
* Handle potentially indirect objects correctly in HexaPDF::Object.deep_copy
* `Revisions#merge` for objects that appear in multiple revisions
* Output of `--pages` option of 'hexapdf inspect' command
* Infinite recursion problem in `Task::Dereference`
* Problem with iteration over images in certain cases
* `Page#[]` with respect to inherited fields
* Problems with access permissions on encryption
* Encryption routine of standard security handler with respect to owner password
* Invalid check in validation of standard encryption dictionary
* 'hexapdf modify' command to support files with many pages
* Validation of encryption key for encryption revision 6
* Various parts of the API documentation


## 0.1.0 - 2016-10-26

* Initial release
