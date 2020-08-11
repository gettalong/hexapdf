# # Text Layouter - Alignment
#
# The [HexaPDF::Layout::TextLayouter] class can be used to easily lay out text
# inside a rectangular area, with various horizontal and vertical alignment
# options.
#
# The text can be aligned horizontally by setting [HexaPDF::Layout::Style#align]
# and vertically by [HexaPDF::Layout::Style#valign]. In this example, a sample
# text is laid out in all possible combinations.
#
# Usage:
# : `ruby text_layouter_alignment.rb`
#

require 'hexapdf'

sample_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit,
sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. at".tr("\n", ' ')

doc = HexaPDF::Document.new
canvas = doc.pages.add.canvas
canvas.font("Times", size: 10, variant: :bold)

width = 100
height = 150
y_base = 800
tf = HexaPDF::Layout::TextFragment.create(sample_text,
                                          font: doc.fonts.add("Times"))
tl = HexaPDF::Layout::TextLayouter.new

[:left, :center, :right, :justify].each_with_index do |align, x_index|
  x = x_index * (width + 20) + 70
  canvas.text(align.to_s, at: [x + 40, y_base + 15])

  [:top, :center, :bottom].each_with_index do |valign, y_index|
    y = y_base - (height + 30) * y_index
    canvas.text(valign.to_s, at: [20, y - height / 2]) if x_index == 0

    tl.style.align(align).valign(valign)
    tl.fit([tf], width, height).draw(canvas, x, y)
    canvas.stroke_color(128, 0, 0).rectangle(x, y, width, -height).stroke
  end
end

doc.write("text_layouter_alignment.pdf", optimize: true)
