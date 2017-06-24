# ## Text Box Styling
#
# The text used as part of a [HexaPDF::Layout::TextBox] class can be styled
# using [HexaPDF::Layout::Style]. To do this [HexaPDF::Layout::TextFragment]
# objects have to be created with the needed styling and then added to a text
# box. In addition the style objects can be used for styling text boxes
# themselves.
#
# This example shows how to do this and shows off the various styling option.
#
# Usage:
# : `ruby text_box_styling.rb`
#

require 'hexapdf'

# Wraps the text in a TextFragment using the given style.
def fragment(text, style)
  HexaPDF::Layout::TextFragment.new(items: style.font.decode_utf8(text),
                                    style: style)
end

# Draws the text box at the given [x, y] position onto the canvas.
def draw_box(box, canvas, x, y)
  rest, height = box.fit
  raise "Error" unless rest.empty?
  box.draw(canvas, x, y)
  y - height
end

sample_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit,
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit
in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
Excepteur sint occaecat cupidatat non proident, sunt in culpa qui
officia deserunt mollit anim id est laborum. ".tr("\n", ' ') * 3

doc = HexaPDF::Document.new

heading = HexaPDF::Layout::Style.new(font: doc.fonts.load("Helvetica", variant: :bold),
                                     font_size: 16, align: :center)
body = HexaPDF::Layout::Style.new(font: doc.fonts.load("Times"),
                                  font_size: 10, align: :justify,
                                  text_indent: 20)
body.line_spacing(:proportional, 1.5)
standout = HexaPDF::Layout::Style.new(font: doc.fonts.load("Times", variant: :bold),
                                      font_size: 14)

canvas = doc.pages.add.canvas
y_base = 800
left = 50
width = 500

box = HexaPDF::Layout::TextBox.new(items: [fragment("This is a header", heading)],
                                   width: width, style: heading)
y_base = draw_box(box, canvas, left, y_base)

box = HexaPDF::Layout::TextBox.new(items: [fragment(sample_text, body)],
                                   width: width, style: body)
y_base = draw_box(box, canvas, left, y_base - 20)

items = [
  fragment(sample_text[0, 50], body), fragment(sample_text[50, 15], standout),
  fragment(sample_text[65, 150], body), fragment(sample_text[215, 50], standout),
  fragment(sample_text[265...800], body), fragment(sample_text[800, 40], standout),
  fragment(sample_text[840..-1], body)
]
box = HexaPDF::Layout::TextBox.new(items: items, width: width, style: body)
draw_box(box, canvas, left, y_base - 20)

doc.write("text_box_styling.pdf", optimize: true)
