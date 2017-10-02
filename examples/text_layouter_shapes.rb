# ## Text Layouter - Shapes
#
# The [HexaPDF::Layout::TextLayouter] class can be used to easily lay out text,
# not limiting the area to a rectangle but any shape. There is only one
# restriction: In the case of arbitrary shapes the vertical alignment has to be
# "top".
#
# Arbitrary shapes boil down to varying line widths and horizontal offsets from
# left. Imagine a circle: If text is fit in a circle, the line widths start at
# zero, getting larger and larger until the middle of the cirle. And then they
# get smaller until zero again. The x-values of the left half circle determine
# the horizontal offsets.
#
# Both, the line widths and the horizontal offsets can be calculated given a
# certain height, and this is exactly what HexaPDF uses. If the `width` argument
# to [HexaPDF::Layout::TextLayouter::new] is an object responding to #call (e.g.
# a lambda), it is used for determining the line widths. And the `x_offsets`
# argument can be used in a similar way for the horizontal offsets.
#
# This example shows text layed out in various shapes, using the above mentioned
# techniques.
#
# Usage:
# : `ruby text_layouter_shapes.rb`
#

require 'hexapdf'

include HexaPDF::Layout

doc = HexaPDF::Document.new
page = doc.pages.add
canvas = page.canvas
canvas.font("Times", size: 10, variant: :bold)
canvas.stroke_color(255, 0, 0).line_width(0.2)

sample_text = "Lorem ipsum dolor sit amet, con\u{00AD}sectetur
adipis\u{00AD}cing elit, sed do eiusmod tempor incididunt ut labore et
dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation
ullamco laboris nisi ut aliquip ex ea commodo consequat.
".tr("\n", ' ') * 10

########################################################################
# Circly things on the top
radius = 100
circle_top = 800
half_circle_widths = lambda do |height, line_height|
  sum = height + line_height
  if sum <= radius * 2
    [Math.sqrt(radius**2 - (radius - height)**2),
     Math.sqrt([radius**2 - (radius - sum)**2, 0].max)].min
  else
    0
  end
end
circle_widths = lambda do |height, line_height|
  2 * half_circle_widths.call(height, line_height)
end
left_half_circle_offsets = lambda do |height, line_height|
  radius - half_circle_widths.call(height, line_height)
end

# Left: right half circle
layouter = TextLayouter.create(sample_text,
                               width: half_circle_widths,
                               height: radius * 2,
                               font: doc.fonts.load("Times"))
layouter.draw(canvas, 0, circle_top)
canvas.circle(0, circle_top - radius, radius).stroke

# Center: full circle
layouter = TextLayouter.create(sample_text,
                               width: circle_widths,
                               x_offsets: left_half_circle_offsets,
                               height: radius * 2,
                               font: doc.fonts.load("Times"),
                               align: :justify)
layouter.draw(canvas, page.box(:media).width / 2.0 - radius, circle_top)
canvas.circle(page.box(:media).width / 2.0, circle_top - radius, radius).stroke

# Right: left half circle
layouter = TextLayouter.create(sample_text,
                               width: half_circle_widths,
                               x_offsets: left_half_circle_offsets,
                               height: radius * 2,
                               font: doc.fonts.load("Times"),
                               align: :right)
layouter.draw(canvas, page.box(:media).width - radius, circle_top)
canvas.circle(page.box(:media).width, circle_top - radius, radius).stroke


########################################################################
# Pointy, diamondy things in the middle

diamond_width = 100
diamond_top = circle_top - 2 * radius - 50
half_diamond_widths = lambda do |height, line_height|
  sum = height + line_height
  if sum < diamond_width
    height
  else
    [diamond_width * 2 - sum, 0].max
  end
end
full_diamond_widths = lambda do |height, line_height|
  2 * half_diamond_widths.call(height, line_height)
end
left_half_diamond_offsets = lambda do |height, line_height|
  diamond_width - half_diamond_widths.call(height, line_height)
end

# Left: right half diamond
layouter = TextLayouter.create(sample_text,
                               width: half_diamond_widths,
                               height: 2 * diamond_width,
                               font: doc.fonts.load("Times"))
layouter.draw(canvas, 0, diamond_top)
canvas.polyline(0, diamond_top, diamond_width, diamond_top - diamond_width,
                0, diamond_top - 2 * diamond_width).stroke

# Center: full diamond
layouter = TextLayouter.create(sample_text,
                               width: full_diamond_widths,
                               x_offsets: left_half_diamond_offsets,
                               height: 2 * diamond_width,
                               font: doc.fonts.load("Times"),
                               align: :justify)
left = page.box(:media).width / 2.0 - diamond_width
layouter.draw(canvas, left, diamond_top)
canvas.polyline(left + diamond_width, diamond_top,
                left + 2 * diamond_width, diamond_top - diamond_width,
                left + diamond_width, diamond_top - 2 * diamond_width,
                left, diamond_top - diamond_width).close_subpath.stroke

# Right: left half diamond
layouter = TextLayouter.create(sample_text,
                               width: half_diamond_widths,
                               x_offsets: left_half_diamond_offsets,
                               height: 2 * diamond_width,
                               font: doc.fonts.load("Times"),
                               align: :right)
middle = page.box(:media).width
layouter.draw(canvas, middle - diamond_width, diamond_top)
canvas.polyline(middle, diamond_top,
                middle - diamond_width, diamond_top - diamond_width,
                middle, diamond_top - 2 * diamond_width).stroke

########################################################################
# Sine wave thing at the bottom

sine_wave_height = 200.0
sine_wave_top = diamond_top - 2 * diamond_width - 50
sine_wave_offsets = lambda do |height, line_height|
  [40 * Math.sin(2 * Math::PI * (height / sine_wave_height)),
   40 * Math.sin(2 * Math::PI * (height + line_height) / sine_wave_height)].max
end
sine_wave_widths = lambda do |height, line_height|
  sine_wave_height + 100 + sine_wave_offsets.call(height, line_height) * -2
end
layouter = TextLayouter.create(sample_text,
                               width: sine_wave_widths,
                               x_offsets: sine_wave_offsets,
                               height: sine_wave_height,
                               font: doc.fonts.load("Times"),
                               align: :justify)
middle = page.box(:media).width / 2.0
layouter.draw(canvas, middle - (sine_wave_height + 100) / 2, sine_wave_top)

doc.write("text_layouter_shapes.pdf", optimize: true)
