# HEXAPDF 1 "October 2016"

## NAME

hexapdf - A Versatile PDF Manipulation Application


## SYNOPSIS

`hexapdf` [`OPTIONS`] `command` [`COMMAND OPTIONS`]...


## DESCRIPTION

hexapdf is an application for PDF manipulation. It is part of the [hexapdf] library which also
allows PDF creation, among other things.

Using the hexapdf application the following tasks can be performed with PDF files:

* Extracting embedded files (see the `extract` command)
* Showing general information of a PDF file (see the `info` command)
* Inspecting the internal structure of a PDF file (see the `inspect` command)
* Modifying an existing PDF file (see the `modify` command)

The application contains a built-in `help` command that can be used to provide a quick reminder of a
command's purpose and its options.


## OPTIONS

The following options can only be used when no command is specified:

* `-v`, `--version`:
  Show the version of the hexapdf application and exit.

These options are available on every command (except if they are overridden):

* `-h`, `--help`:
  Show the help for the application if no command was specified, or the command help otherwise.


## COMMANDS

hexapdf uses a command-style interface. This means that it provides different functionalities
depending on the used command and each command can have its own options.

There is no need to write the full command name for hexapdf to understand it, the only requirement
is that is must be unambiguous. So using `e` for the `extract` command is sufficient.


### extract

Synopsis: `extract` [`OPTIONS`] <FILE>

This command extracts embedded files from the PDF <FILE>. If the `--indices` option is not
specified, the names and indices of the embedded files are just listed.

* `-i`, `--indices` *A,B,C,...*:
  The indices of the embedded files that should be extract. The value *0* can be used to extract all
  embedded files.

* `-s`, `--[no-]search`:
  Search the whole PDF file instead of the standard locations, i.e. files attached to the document
  as a whole or to an individual page. Defaults to *false*.

* `-p`, `--password` <PASSWORD>:
  The password to decrypt the PDF <FILE>.


### help

Synopsis: `help` <COMMAND>...

This command prints the application help if no arguments are given. If one or more command names are
given as arguments, these arguments are interpreted as a list of commands with sub-commands and the
help for the innermost command is shown.


### info

Synopsis: `info` [`OPTIONS`] <FILE>

This command reads the <FILE> file and shows general information about it, like author information,
PDF version used, encryption information and so on.

* `-p`, `--password` <PASSWORD>:
  The password to decrypt the PDF <FILE>.


### inspect

Synopsis: `inspect` [`OPTIONS`] <FILE>

This command is useful when one needs to inspect the internal object structure or a stream of a PDF
file.

If no option is given, the main PDF object, the catalog, is shown. Otherwise the various, mutually
exclusive display options define what is shown. If multiple such options are specified only the last
one is respected. Note that PDF objects are always shown in the PDF syntax.

* `-t`, `--trailer`:
  Show the trailer dictionary.

* `-c`, `--page-count`:
  Print the number of pages.

* `--pages` [<PAGES>]:
  Show the pages with their object and generation numbers and their associated content streams. If a
  range is specified, only those pages are listed. See the **PAGES SPECIFICATION** below for details
  on the allowed format of <PAGES>.

* `-o`, `--object` <OID>[,<GEN>]:
  Show the object with the given object and generation numbers. The generation number defaults to 0
  if not given.

* `-s`, `--stream` <OID>[,<GEN>]:
  Show the filtered stream data (add `--raw` to get the raw stream data) of the object with the
  given object and generation numbers. The generation number defaults to 0 if not given.

* `--raw`:
  Modifies `--stream` to show the raw stream data instead of the filtered one.

* `-p`, `--password` <PASSWORD>:
  The password to decrypt the PDF <FILE>.


### modify

Synopsis: `modify` [`OPTIONS`] <INPUT_FILE> <OUTPUT_FILE>

This command modifies a PDF file. It can be used to encrypt/decrypt a file, to optimize it and
remove unused entries and to generate or delete object and cross-reference streams.

* `-p`, `--password` <PASSWORD>:
  The password to decrypt the PDF <INPUT_FILE>.

* `--pages` <PAGES>:
  The pages that should be included in the <OUTPUT_FILE>. See the **PAGES SPECIFICATION** below for
  details on the allowed format of <PAGES>. Default: *1-e* (i.e. all pages).

* `--[no-]compact`:
  Delete unnecessary PDF objects. This includes merging the base revision and all incremental
  updates into a single revision. Default: *yes*.

* `--object-streams MODE`:
  Defines how object streams should be treated: *generate* will remove all exisiting object streams
  and generate new ones, *delete* will only remove existing object streams and *preserve* will do
  nothing. Default: *preserve*.

* `--xref-streams MODE`:
  Defines how cross-reference streams should be treated: *generate* will add them, *delete* will
  remove them and *preserve* will do nothing. Default: *preserve*.

Encryption related options (all options except **--decrypt** automatically enabled **--encrypt**):

* `--decrypt`:
  Remove any encryption.

  If neither **--decrypt** nor **--encrypt** is specified, the existing encryption configuration is
  preserved.

* `--encrypt`:
  Encrypt the <OUTPUT_FILE>.

  If neither **--decrypt** nor **--encrypt** is specified, the existing encryption configuration is
  preserved.

* `--owner-password` <PASSWORD>:
  The owner password to be set on the <OUTPUT_FILE>. This password is needed when operations not
  allowed by the permissions need to be done. It can also be used when opening the PDF file.

* `--user-password` <PASSWORD>:
  The user password to be set on the <OUTPUT_FILE>. This password is needed when opening the PDF
  file. The application should restrict the operations to those allowed by the permissions.

* `--algorithm` <ALGORITHM>:
  The encryption algorithm to use on the <OUTPUT_FILE>. Allowed algorithms are *aes* and *arc4* but
  *arc4* should only be used if it is absolutely necessary. Default: *aes*.

* `--key-length` <BITS>:
  The length of the encryption key in bits. The allowed values differ based on the chosen algorithm:
  A number divisible by eight between 40 to 128 for *arc4* and 128 or 256 for *aes*. Default:
  **128**

* `--force-V4`:
  Force the use of PDF encryption version 4 if key length is *128* and algorithm is *arc4*. This
  option is probably only useful for testing the implementation of PDF libraries' encryption
  handling.

* `--permissions` <PERMS>:
  A comma separated list of permissions to be set on the <OUTPUT_FILE>.

  Possible values: *print* (allow printing), *modify_content* (allow modification of the content
  of pages), *copy_content* (allow text extraction and similar operations), *modify_annotation*
  (allow creation and modification of annotations and filling in of forms), *fill_in_forms* (allow
  filling in of forms even if *modify_annotation* is not set), *extract_content* (allow text and
  graphics extraction in accessibility cases), *assemble_document* (allow page modifications and
  bookmark creation), and *high_quality_print* (allow high quality printing).


### version

This command shows the version of the hexapdf application. It is an alternative to using the global
`--version` option.


## PAGES SPECIFICATION

Some commands all the specification of pages using a <PAGES> argument. This argument is expected to
be a comma separated list of single page numbers or page ranges of the form <START>-<END>. The
character '**e**' represents the last page and can be used instead of a single number or in a range.
The pages are used in the order in which the are specified.

Examples:

* **1,2,3**: The pages one, two and three.
* **11,4-9,1,e**: The pages eleven, four to nine, one and the last page, in exactly this order.
* **1-e**: All pages of the document.
* **e-1**: All pages of the document in reverse order.


## EXIT STATUS

The exit status is 0 if no error happened. Otherwise it is 1.


## SEE ALSO

The [hexapdf website](http://hexapdf.gettalong.org/) for more information


## AUTHOR

hexapdf was written by Thomas Leitner <t_leitner@gmx.at>.

This manual page was written by Thomas Leitner <t_leitner@gmx.at>.

[hexapdf]: http://hexapdf.gettalong.org
