$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

a4 = HexaPDF::Type::Page::PAPER_SIZE[:A4]
top_margin = a4[3] - 72 - 0.5 * 72
bottom_margin = 72 + 0.5 * 72

doc = HexaPDF::Document.new
font = doc.fonts.add(ARGV[2] || 'Times')
y = 0
canvas = nil

File.foreach(ARGV[0], mode: 'r') do |line|
  if y < bottom_margin
    # Remove the canvas object out of scope for garbage collection
    if canvas
      doc.clear_cache(canvas.context.data)
      canvas.context.contents = canvas.context.contents
    end
    canvas = doc.pages.add.canvas
    canvas.font(font, size: 12)
    canvas.leading = 14
    canvas.move_text_cursor(offset: [72, top_margin])
    y = top_margin
  end

  canvas.show_glyphs_only(font.decode_utf8(line.rstrip!))
  canvas.move_text_cursor
  y -= 14
end

doc.write(ARGV[1])
