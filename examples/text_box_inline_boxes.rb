# ## Text Box with Inline Boxes
#
# The [HexaPDF::Layout::TextBox] class can be used to easily lay out text mixed
# with inline boxes.
#
# Inline boxes are used for showing graphics that follow the flow of the text.
# This means that their horizontal and their general vertical position is
# determined by the text layout functionality. However, inline boxes may be
# vertically aligned to various positions, like the baseline, the top/bottom of
# the text and the top/bottom of the line.
#
# This example shows some text containing emoticons that are replaced with their
# graphical representation, with normal smileys being aligned to the baseline
# and winking smileys to the top of the line.
#
# Usage:
# : `ruby text_box_inline_boxes.rb`
#

require 'hexapdf'

include HexaPDF::Layout

sample_text = "Lorem ipsum :-) dolor sit amet, consectetur adipiscing
;-) elit, sed do eiusmod tempor incididunt :-) ut labore et dolore magna
aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco
laboris nisi ut aliquip ex ea commodo consequat ;-). Duis aute irure
dolor in reprehenderit in voluptate velit esse cillum :-) dolore eu
fugiat nulla pariatur. ".tr("\n", ' ') * 4

doc = HexaPDF::Document.new
emoji_smile = doc.images.add(File.join(__dir__, "emoji-smile.png"))
emoji_wink = doc.images.add(File.join(__dir__, "emoji-wink.png"))
size = 10

items = sample_text.split(/(:-\)|;-\))/).map do |part|
  case part
  when ':-)'
    InlineBox.new(size * 2, size * 2, valign: :baseline) do |box, canvas|
      canvas.image(emoji_smile, at: [0, 0], width: box.width)
    end
  when ';-)'
    InlineBox.new(size, size, valign: :top) do |box, canvas|
      canvas.image(emoji_wink, at: [0, 0], width: box.width)
    end
  else
    TextFragment.create(part, font: doc.fonts.load("Times"), font_size: 18)
  end
end

box = TextBox.new(items: items, width: 500, height: 700)
box.style.align = :justify
box.style.line_spacing(:proportional, 1.5)
box.draw(doc.pages.add.canvas, 50, 800)

doc.write("text_box_inline_boxes.pdf")
