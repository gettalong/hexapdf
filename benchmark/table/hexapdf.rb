#!/usr/bin/env ruby

$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

rows = ARGV[0].to_i
image = ARGV[1]

HexaPDF::Composer.create(ARGV[2], page_size: :A4, margin: 72) do |pdf|
  pdf.style(:image, position_hint: :center)
  pdf.style(:text_col1, font: 'Helvetica', font_size: 10)
  pdf.style(:text_col3, base: :text_col1, align: :right)
  data = rows.times.map do |i|
    ibox = pdf.document.layout.image(image, height: 40, style: :image)
    ["Line #{i}", ibox, i.to_s]
  end
  pdf.table(data, column_widths: [200, 100, 100], padding: -0.5) do |args|
    args[] = {style: :text_col1}
    args[0..-1, -1] = {style: :text_col3}
  end
end
