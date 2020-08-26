# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/font_true_type'

describe HexaPDF::Type::FontTrueType do
  before do
    @doc = HexaPDF::Document.new
    font_descriptor = @doc.add({Type: :FontDescriptor, FontName: :Something, Flags: 0b100,
                                FontBBox: [0, 1, 2, 3], ItalicAngle: 0, Ascent: 900,
                                Descent: -100, CapHeight: 800, StemV: 20})
    @font = @doc.add({Type: :Font, Subtype: :TrueType, Encoding: :WinAnsiEncoding,
                      FirstChar: 32, LastChar: 34, Widths: [600, 0, 700],
                      BaseFont: :Something, FontDescriptor: font_descriptor})
  end

  describe "validation" do
    it "ignores some missing fields if the font name is one of the standard PDF fonts" do
      @font[:BaseFont] = :'Arial,Bold'
      [:FirstChar, :LastChar, :Widths, :FontDescriptor].each {|field| @font.delete(field) }
      assert(@font.validate)
    end

    it "requires that the FontDescriptor key is set" do
      assert(@font.validate)
      @font.delete(:FontDescriptor)
      refute(@font.validate)
    end
  end
end
