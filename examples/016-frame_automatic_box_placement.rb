# # Frame - Automatic Box Placement
#
# The [HexaPDF::Layout::Frame] class is used for placing rectangular boxes.
#
# This example shows how to create a frame and how different box styles can be
# used to specify where a box should be placed. After each box is drawn, the
# frame's shape is drawn and then a new page is started. This is done to easily
# compare the changes after each added box.
#
# Note how the absolutely positioned box cuts a hole into the frame's shape and
# how that influences the positioning.
#
# Usage:
# : `ruby frame_automatic_box_placement.rb`
#

require 'hexapdf'

include HexaPDF::Layout

doc = HexaPDF::Document.new
page = doc.pages.add
media_box = page.box(:media)
canvas = page.canvas

frame = Frame.new(media_box.left + 20, media_box.bottom + 20,
                  media_box.width - 40, media_box.height - 40)

box_counter = 1
draw_box = lambda do |**args|
  b = Box.create(**args, border: {width: 1, color: [[255, 0, 0]]}) do |canv, box|
    canv.save_graphics_state do
      canv.stroke_color(255, 0, 0)
      canv.line(0, 0, box.content_width, box.content_height).
        line(0, box.content_height, box.content_width, 0).
        stroke
    end
    text = box_counter.to_s << "\n" + args.map {|k, v| "#{k}: #{v}"}.join("\n")
    canv.font("Times", size: 15).leading(15).
      text(text, at: [10, box.content_height - 20])
    box_counter += 1
  end

  drawn = false
  until drawn
    drawn = frame.draw(canvas, b)
    frame.find_next_region unless drawn
  end

  canvas.line_width(3).draw(:geom2d, object: frame.shape)
  canvas = doc.pages.add.canvas
end

# Absolutely positioned box with margin
draw_box.call(width: 100, height: 100, position: :absolute, margin: 10,
              position_hint: [250, 250])

# Fixed sized box with automatic width
draw_box.call(height: 100)

# Fixed sized box
draw_box.call(width: 100, height: 100)

# Fixed sized box, placed below the other because the space to the right can't
# be used
draw_box.call(width: 100, height: 100)

# Fixed sized floating box, space to the right can be used
draw_box.call(width: 100, height: 100, position: :float, position_hint: :left)

# Fixed sized floating box again, floating to the right
draw_box.call(width: 100, height: 100, position: :float, position_hint: :right)

# Fixed sized floating box again, floating to the left with margin
draw_box.call(width: 100, height: 100, position: :float, position_hint: :left,
              margin: [0, 10])

# Fixed sized box, no floating
draw_box.call(width: 100, height: 100)

# Fixed sized box, center aligned in the available space
draw_box.call(width: 100, height: 100, position_hint: :center)

# Fixed sized box, right aligned in the available space
draw_box.call(width: 100, height: 100, position_hint: :right)

# Fixed sized box, consuming the whole remaining available space
draw_box.call

doc.write("frame_automatic_box_placement.pdf", optimize: true)
