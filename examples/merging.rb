# ## Merging PDF Files
#
# Merging of PDF files can be done in various ways of sophistication.
#
# The easiest way, which this example shows, just imports the pages of
# the source files into the target file. This preserves the page
# contents themselves but nothing else.
#
# For example, named destinations are not properly handled by the code.
# Sometimes other things like attached files or a document outline
# should also be preserved.
#
# Usage:
# : `ruby merging.rb INPUT1.PDF INPUT2.PDF ...`
#

require 'hexapdf'

target = HexaPDF::Document.new
ARGV.each do |file|
  pdf = HexaPDF::Document.open(file)
  pdf.pages.each_page {|page| target.pages.add_page(target.import(page))}
end
target.write("merging.pdf")
