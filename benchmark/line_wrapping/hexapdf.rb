$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

file = ARGV[0]
width = ARGV[1].to_i
height = 1000

doc = HexaPDF::Document.new
tl = HexaPDF::Layout::TextLayouter.create(File.read(file), width: width, height: height,
                                          font_features: {kern: false}, font_size: 10,
                                          font: doc.fonts.add(ARGV[3] || "Times"))
tl.style.line_spacing(:fixed, 11.16)

while !tl.items.empty?
  canvas = doc.pages.add([0, 0, width, height]).canvas
  tl.items, = tl.draw(canvas, 0, height)
end

doc.write(ARGV[2])
