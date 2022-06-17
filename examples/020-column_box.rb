# ## Column Box
#
# This example shows how [HexaPDF::Layout::ColumnBox] can be used to place
# contents into columns.
#
# Three boxes are placed repeatedly onto the frame until it is filled: two
# floating boxes (one left, one right) and a text box. The text box is styled to
# flow its content around the other two boxes.
#
# Usage:
# : `ruby column_box.rb`
#

require 'hexapdf'

doc = HexaPDF::Document.new
page = doc.pages.add
media_box = page.box(:media)
frame = HexaPDF::Layout::Frame.new(media_box.left + 20, media_box.bottom + 20,
                                   media_box.width - 40, media_box.height - 40)

boxes = []
5.times do
  boxes << doc.layout.image_box(File.join(__dir__, 'machupicchu.jpg'), width: 100,
                                style: {margin: [10, 30], position: :float})
  boxes << HexaPDF::Layout::Box.create(width: 50, height: 50, margin: 20,
                                       position: :float, position_hint: :right,
                                       border: {width: 1, color: [[255, 0, 0]]})
  boxes << doc.layout.lorem_ipsum_box(count: 2, position: :flow, align: :justify)
end

polygon = Geom2D::Polygon([200, 350], [400, 350], [400, 450], [200, 450])
frame.remove_area(polygon)
page.canvas.draw(:geom2d, object: polygon)

columns = doc.layout.box(:column, children: boxes, columns: 2, style: {position: :flow})
result = frame.fit(columns)
frame.draw(page.canvas, result)

doc.write("column_box.pdf", optimize: true)
