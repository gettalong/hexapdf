# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/type1'

describe HexaPDF::Font::Type1::Font do
  before do
    metrics = HexaPDF::Font::Type1::FontMetrics.new
    @font = HexaPDF::Font::Type1::Font.new(metrics)
  end

  describe "::from_afm" do
    it "can load the Font object from an AFM file" do
      font = HexaPDF::Font::Type1::Font.from_afm(File.join(HexaPDF.data_dir, 'afm/Symbol.afm'))
      assert_equal('Symbol', font.family_name)
    end
  end

  describe "encoding" do
    it "uses the StandardEncoding if possible" do
      @font.metrics.encoding_scheme = 'AdobeStandardEncoding'
      assert_equal(HexaPDF::Font::Encoding.for_name(:StandardEncoding), @font.encoding)
    end

    it "generates an encoding object if necessary" do
      char_metrics = HexaPDF::Font::Type1::CharacterMetrics.new
      char_metrics.code = 5
      char_metrics.name = :A
      @font.metrics.character_metrics[5] = char_metrics.dup
      char_metrics.code = 6
      char_metrics.name = :Z
      @font.metrics.character_metrics[6] = char_metrics.dup

      assert_equal({5 => :A, 6 => :Z}, @font.encoding.code_to_name)
    end
  end

  describe "width" do
    before do
      @char_metrics = HexaPDF::Font::Type1::CharacterMetrics.new
      @char_metrics.width = 100
    end

    it "returns the width for a code point in the built-in encoding" do
      @font.metrics.character_metrics[5] = @char_metrics
      assert_equal(100, @font.width(5))
    end

    it "returns the width for a named glyph" do
      @font.metrics.character_metrics[:A] = @char_metrics
      assert_equal(100, @font.width(:A))
    end
  end
end
