# -*- encoding: utf-8 -*-

require 'stringio'
require 'test_helper'
require 'hexapdf/font/true_type'

describe HexaPDF::Font::TrueType::Optimizer do
  before do
    font_file = File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf")
    @font = HexaPDF::Font::TrueType::Font.new(File.open(font_file))
    @subsetter = HexaPDF::Font::TrueType::Subsetter.new(@font)
  end

  after do
    @font.io.close
  end

  describe "build_for_pdf" do
    it "builds a font file that is optimized for use with PDFs" do
      font_data = HexaPDF::Font::TrueType::Optimizer.build_for_pdf(@font)
      built_font = HexaPDF::Font::TrueType::Font.new(StringIO.new(font_data))
      %I(FFTM GDEF GPOS GSUB name post).each do |table|
        refute(built_font[table])
      end
    end
  end
end
