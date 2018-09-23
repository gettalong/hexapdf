# ## Text in Polygon
#
# While creating width specifications for the [HexaPDF::Layout::TextLayouter]
# class by hand is possible, the [HexaPDF::Layout::WidthFromPolygon] class
# provides an easier way by using polygons.
#
# Most of the times text is laid out within polygonal shapes, so direct support
# for these makes text layout in HexaPDF easier.
#
# This examples shows how much easier text layout is by re-doing the "house"
# example from the [Text Layouter - Shapes example](text_layouter_shapes.html).
#
# Usage:
# : `ruby text_in_polygon.rb`
#

require 'hexapdf'
require 'geom2d'

include HexaPDF::Layout

doc = HexaPDF::Document.new
canvas = doc.pages.add([0, 0, 600, 300]).canvas

sample_text = "Lorem ipsum dolor sit amet, con\u{00AD}sectetur
adipis\u{00AD}cing elit, sed do eiusmod tempor incididunt ut labore et
dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation
ullamco laboris nisi ut aliquip ex ea commodo consequat.
".tr("\n", ' ') * 10
items = [TextFragment.create(sample_text, font: doc.fonts.add("Times"))]

house = Geom2D::Polygon([100, 200], [400, 200], [500, 100], [400, 100], [400, 0],
                        [300, 0], [300, 100], [200, 100], [200, 0], [100, 0],
                        [100, 100], [0, 100])
width_spec = WidthFromPolygon.new(house)
layouter = TextLayouter.new
layouter.style.align = :justify
result = layouter.fit(items, width_spec, house.bbox.height)
result.draw(canvas, 50, 250)

doc.write("text_in_polygon.pdf", optimize: true)
