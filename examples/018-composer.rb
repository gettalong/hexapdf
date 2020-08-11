# # Composer
#
# This example shows how [HexaPDF::Composer] simplifies the creation of PDF
# documents by providing a high-level interface to the box layouting engine.
#
# Basic style properties can be set on the [HexaPDF::Composer#base_style] style.
# These properties are reused by every box and can be adjusted on a box-by-box
# basis.
#
# Various methods allow the easy creation of boxes, for example, text and image
# boxes. All these boxes are automatically drawn on the page. If the page has
# not enough room left for a box, the box is split across pages (which are
# automatically created) if possible or just drawn on the new page.
#
# Usage:
# : `ruby composer.rb`
#

require 'hexapdf'

lorem_ipsum = "Lorem ipsum dolor sit amet, con\u{00AD}sectetur
adipis\u{00AD}cing elit, sed do eiusmod tempor incidi\u{00AD}dunt ut labore et
dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exer\u{00AD}citation
ullamco laboris nisi ut aliquip ex ea commodo consequat. ".tr("\n", " ")

HexaPDF::Composer.create('composer.pdf') do |pdf|
  pdf.base_style.update(line_spacing: {type: :proportional, value: 1.5},
                        last_line_gap: true, align: :justify)
  image_style = pdf.base_style.dup.update(border: {width: 1}, padding: 5, margin: 10)
  link_style = pdf.base_style.dup.update(fill_color: [6, 158, 224], underline: true)
  image = File.join(__dir__, 'machupicchu.jpg')

  pdf.text(lorem_ipsum * 2)
  pdf.image(image, style: image_style, width: 200, position: :float)
  pdf.image(image, style: image_style, width: 200, position: :absolute,
            position_hint: [200, 300])
  pdf.text(lorem_ipsum * 20, position: :flow)

  pdf.formatted_text(["Produced by ",
                      {link: "https://hexapdf.gettalong.org", text: "HexaPDF",
                       style: link_style},
                      " via HexaPDF::Composer"],
                      font_size: 15, align: :center, padding: 15)
end
