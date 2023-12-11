# # Frame - Mask Mode
#
# This example shows how to use the style property 'mask_mode' to achieve
# certain effects like overlaying boxes on each other or using multiple
# horizontal alignments on one line.
#
# Usage:
# : `ruby frame_mask_mode.rb`
#
require 'hexapdf'

HexaPDF::Composer.create('frame_mask_mode.pdf') do |composer|
  box = composer.image(File.join(__dir__, 'machupicchu.jpg'),
                       border: {width: 1}, mask_mode: :none)
  composer.text('Text overlaid over image', height: box.height, text_align: :center,
               font_size: 50, text_valign: :center, text_rendering_mode: :fill_stroke,
               fill_color: 'white', stroke_color: 'hp-blue', margin: [0, 0, 10])
  composer.column(columns: 1, style: {border: {width: 1}, padding: 10}) do |col|
    col.text('Center', mask_mode: :box, position_hint: :center)
    col.text('Left', mask_mode: :fill_horizontal)
    col.text('Right', position_hint: :right)
  end
end
