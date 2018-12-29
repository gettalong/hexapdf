#!/usr/bin/env ruby

$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

file = ARGV[0]
width = ARGV[1].to_i
height = 1000

HexaPDF::Composer.create(ARGV[2], page_size: [0, 0, width, height], margin: 0) do |pdf|
  pdf.text(File.read(file), font_features: {kern: false},
           font: ARGV[3] || "Times", font_size: 10, last_line_gap: true,
           line_spacing: {type: :fixed, value: 11.16})
end
