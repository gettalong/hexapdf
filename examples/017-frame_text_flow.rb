# # Frame - Text Flow
#
# This example shows how [HexaPDF::Layout::Frame] and [HexaPDF::Layout::TextBox]
# can be used to flow text around objects.
#
# Three boxes are placed repeatedly onto the frame until it is filled: two
# floating boxes (one left, one right) and a text box. The text box is styled to
# flow its content around the other two boxes.
#
# Usage:
# : `ruby frame_text_flow.rb`
#

require 'hexapdf'
require 'hexapdf/utils/graphics_helpers'

include HexaPDF::Layout
include HexaPDF::Utils::GraphicsHelpers

doc = HexaPDF::Document.new

sample_text = "Lorem ipsum dolor sit amet, con\u{00AD}sectetur
adipis\u{00AD}cing elit, sed do eiusmod tempor incididunt ut labore et
dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation
ullamco laboris nisi ut aliquip ex ea commodo consequat.
".tr("\n", ' ') * 10
items = [TextFragment.create(sample_text, font: doc.fonts.add("Times"))]

page = doc.pages.add
media_box = page.box(:media)
canvas = page.canvas
frame = Frame.new(media_box.left + 20, media_box.bottom + 20,
                  media_box.width - 40, media_box.height - 40)

image = doc.images.add(File.join(__dir__, 'machupicchu.jpg'))
iw, ih = calculate_dimensions(image.width, image.height, rwidth: 100)

boxes = []
boxes << Box.create(width: iw, height: ih,
                    margin: [10, 30], position: :float) do |canv, box|
  canv.image(image, at: [0, 0], width: 100)
end
boxes << Box.create(width: 50, height: 50, margin: 20,
                    position: :float, position_hint: :right,
                    border: {width: 1, color: [[255, 0, 0]]})
boxes << TextBox.new(items, style: {position: :flow, align: :justify})

i = 0
frame_filled = false
until frame_filled
  box = boxes[i]
  drawn = false
  until drawn || frame_filled
    drawn = frame.draw(canvas, box)
    frame_filled = !frame.find_next_region unless drawn
  end
  i = (i + 1) % boxes.length
end

doc.write("frame_text_flow.pdf", optimize: true)
