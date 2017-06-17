# ## Text Box Line Wrapping
#
# The [HexaPDF::Layout::TextBox] class can be used to easily lay out text,
# automatically wrapping it appropriately.
#
# Text is broken only at certain characters:
#
# * The most important break points are **spaces**.
#
# * Lines can be broken at **tabulators** which represent eight spaces.
#
# * **Newline characters** are respected when wrapping and introduce a line
#   break. They have to be removed beforehand if this is not wanted. All Unicode
#   newline separators are recognized.
#
# * **Hyphens** are used as break points, possibly breaking just after them.
#
# * In addition to hyphens, **soft-hyphens** can be used to indicate break
#   points. In contrast to hyphens, soft-hyphens won't be visible unless a line
#   is broken at its position.
#
# * **Zero-width spaces** can be used to indicate break points at any position.
#
# This example shows all these specially handled characters in action, e.g. a
# hard line break after "Fly-fishing", soft-hyphen in "wandering", tabulator
# instead of space after "wandering" and zero-width space in "fantastic".
#
# Usage:
# : `ruby text_box_line_wrapping.rb`
#

require 'hexapdf'

doc = HexaPDF::Document.new
canvas = doc.pages.add(doc.add(Type: :Page, MediaBox: [0, 0, 180, 210])).canvas
canvas.font("Times", size: 10, variant: :bold)

text = "Hello! Fly-fishing\nand wand\u{00AD}ering\taround - fanta\u{200B}stic"

x = 10
y = 200
[30, 60, 100, 160].each do |width|
  box = HexaPDF::Layout::TextBox.create(text, width: width,
                                        font: doc.fonts.load("Times"))
  _, height = box.fit
  box.draw(canvas, x, y)
  canvas.stroke_color(255, 0, 0).line_width(0.2)
  canvas.rectangle(x, y, width, -height).stroke
  y -= height + 5
end

doc.write("text_box_line_wrapping.pdf", optimize: true)
