#!/usr/bin/env ruby

$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'

file = ARGV[0]
width = ARGV[1].to_i
height = 1000

doc = HexaPDF::Document.new
tf = HexaPDF::Layout::TextFragment.create(File.read(file),
                                          font_features: {kern: false}, font_size: 10,
                                          font: doc.fonts.add(ARGV[3] || "Times"))
tf.style.line_spacing(:fixed, 11.16)
tb = HexaPDF::Layout::TextBox.new([tf], style: tf.style)

while tb
  frame = HexaPDF::Layout::Frame.new(0, 0, width, height)
  canvas = doc.pages.add([0, 0, width, height]).canvas
  if frame.fit(tb)
    frame.draw(canvas, tb)
    tb = nil
  else
    boxes = frame.split(tb)
    if boxes[0]
      frame.draw(canvas, boxes[0])
    else
      raise "Problem with fitting contents"
    end
    tb = boxes[1]
  end
end

doc.write(ARGV[2])
