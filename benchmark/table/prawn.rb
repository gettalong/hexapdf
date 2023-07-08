#!/usr/bin/env ruby

require 'prawn'
require 'prawn/table'

rows = ARGV[0].to_i
image = ARGV[1]

Prawn::Document.generate(ARGV[2], page_size: 'A4', margin: 72, compress: true) do |doc|
  data = rows.times.map do |i|
    ["Line #{i}", {image: image, image_height: 40, position: :center}, i.to_s]
  end
  doc.table(data, column_widths: [200, 100, 100], cell_style: {font: 'Helvetica', size: 10, padding: 6}) do |table|
    table.column(-1).align = :right
  end
end
