#!/usr/bin/env ruby

require 'prawn'

bottom_margin = 72 + 0.5 * 72

Prawn::Document.generate(ARGV[1], page_size: "A4", compress: true, margin: 72) do |doc|
  doc.font(ARGV[2] ? ARGV[2] : 'Times-Roman')
  doc.font_size(12)
  y = doc.margin_box.absolute_top - 0.5 * 72
  x = doc.margin_box.absolute_left
  opts = {}

  File.foreach(ARGV[0], mode: 'r') do |line|
    doc.add_text_content(line.rstrip!, x, y, opts)
    y -= 14

    if y < bottom_margin
      doc.start_new_page
      y = doc.margin_box.absolute_top - 0.5 * 72
    end
  end

  page_num = doc.page_number
end
