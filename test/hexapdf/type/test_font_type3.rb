# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/font_type3'

describe HexaPDF::Type::FontType3 do
  before do
    @doc = HexaPDF::Document.new
    @font = @doc.add({Type: :Font, Subtype: :Type3, Encoding: :WinAnsiEncoding,
                      FirstChar: 32, LastChar: 34, Widths: [600, 0, 700],
                      FontBBox: [0, 0, 100, 100], FontMatrix: [1, 0, 0, 1, 0, 0],
                      CharProcs: {}})
  end

  describe "validation" do
    it "works for valid objects" do
      assert(@font.validate)
    end

    it "fails if the Encoding key is missing" do
      @font.delete(:Encoding)
      refute(@font.validate)
    end
  end
end
