$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

file = ARGV[0]
width = ARGV[1].to_i
height = 1000

doc = HexaPDF::Document.new
tf = HexaPDF::Layout::TextFragment.create(File.read(file),
                                          font_features: {kern: false}, font_size: 10,
                                          font: doc.fonts.add(ARGV[3] || "Times"))
tf.style.line_spacing(:fixed, 11.16)
items = [tf]
tl = HexaPDF::Layout::TextLayouter.new(tf.style)

while !items.empty?
  canvas = doc.pages.add([0, 0, width, height]).canvas
  result = tl.fit(items, width, height)
  result.draw(canvas, 0, height)
  items = result.remaining_items
end

doc.write(ARGV[2])
