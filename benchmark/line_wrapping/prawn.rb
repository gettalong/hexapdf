#!/usr/bin/env ruby

require 'prawn'

file = ARGV[0]
width = ARGV[1].to_i
height = 1000

Prawn::Document.generate(ARGV[2], page_size: [width, height], compress: true, margin: 0) do |doc|
  doc.font(ARGV[3] ? ARGV[3] : 'Times-Roman')
  doc.font_size(10)

  # It would be possible to just use doc.text(File.read(file), kerning: false), however the
  # performance would be worse.
  File.readlines(file).each do |text|
    doc.text(text, kerning: false)
  end
end
