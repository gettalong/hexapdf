# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../font/true_type/table/common'
require 'hexapdf/document'
require 'hexapdf/font/true_type_wrapper'
require 'hexapdf/layout/text_shaper'

using HexaPDF::Layout::NumericRefinements

describe HexaPDF::Layout::TextShaper do
  before do
    @doc = HexaPDF::Document.new
    @shaper = HexaPDF::Layout::TextShaper.new
  end

  def setup_fragment(items, **options)
    style = HexaPDF::Layout::Style.new(font: @font, font_size: 20, **options)
    HexaPDF::Layout::TextFragment.new(items, style)
  end

  describe "Type1 font features" do
    before do
      @font = @doc.fonts.add("Times", custom_encoding: true)
    end

    it "handles ligatures" do
      fragment = setup_fragment(@font.decode_utf8('fish fish fi').insert(1, 100).
        insert(0, 100), font_features: {liga: true})
      @shaper.shape_text(fragment)
      assert_equal([100, :fi, :s, :h, :space, :fi, :s, :h, :space, :fi],
                   fragment.items.map {|item| item.kind_of?(Numeric) ? item : item.id })
    end

    it "handles kerning" do
      fragment = setup_fragment(@font.decode_utf8('fish fish wow').insert(1, 100),
                                font_features: {kern: true})
      @shaper.shape_text(fragment)
      assert_equal([:f, 100, :i, :s, :h, :space, :f, 20, :i, :s, :h, :space, :w, 10, :o, 25, :w],
                   fragment.items.map {|item| item.kind_of?(Numeric) ? item : item.id })
    end
  end

  describe "TrueType font features" do
    before do
      font_file = File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf")
      @wrapped_font = HexaPDF::Font::TrueType::Font.new(File.open(font_file))
      @font = HexaPDF::Font::TrueTypeWrapper.new(@doc, @wrapped_font)
    end

    it "handles kerning via the kern table" do
      data = [0, 1].pack('n2') <<
        [0, 6 + 8 + 12, 0x1].pack('n3') <<
        [2, 0, 0, 0, 53, 80, -20, 80, 81, -10].pack('n4n2s>n2s>')
      table = create_table(:Kern, data, standalone: true)
      @wrapped_font.instance_eval { @tables[:kern] = table }
      fragment = setup_fragment(@font.decode_utf8('Top Top').insert(1, 100),
                                shaping_engine: :internal, font_features: {kern: true})
      @shaper.shape_text(fragment)
      assert_equal([53, [100], 80, [10], 81, 3, 53, [20], 80, [10], 81],
                   fragment.items.map {|item| item.kind_of?(Numeric) ? [item] : item.id })
    end

    describe "HarfBuzz OpenType shaper" do
      before do
        @font = @doc.fonts.add('Inter')
      end

      it "performs the shaping" do
        # Test composition of o+diaresis, invalid char \n, kerning WA, x/y offsets with marks
        fragment = setup_fragment(@font.decode_utf8("ö\nWAď̄"), shaping_engine: :harfbuzz,
                                  font_features: {kern: true})
        assert_equal(8, fragment.items.size)
        result = @shaper.shape_text(fragment)
        assert_equal(2, result.size)
        [[791, 0, 459, [56.640625], 2, 603],
         [[664.55078125], 1773, [-664.55078125]]].each_with_index do |expected, index|
          assert_equal(expected,
                       result[index].items.map {|item| item.kind_of?(Numeric) ? [item] : item.id })
        end
        assert_equal("\n", result[0].items[1].str)
      end

      it "handles glyphs with the same cluster number" do
        # Force Harfbuzz into cluster level 0 to force the same cluster numbers
        cluster_level_method = HarfBuzz::Buffer.instance_method(:cluster_level=)
        HarfBuzz::Buffer.remove_method(:cluster_level=)
        HarfBuzz::Buffer.define_method(:cluster_level=) {|val| }

        fragment = setup_fragment(@font.decode_utf8("ď̄aď̄"), shaping_engine: :harfbuzz)
        result = @shaper.shape_text(fragment)
        assert_equal("ď̄", result[0].items[0].str)
        assert_equal("", result[1].items[1].str)
      ensure
        HarfBuzz::Buffer.remove_method(:cluster_level=)
        HarfBuzz::Buffer.define_method(:cluster_level=, cluster_level_method)
      end

      it "raises an error if the harfbuzz-ruby gem is not available" do
        Object.send(:remove_const, :HARFBUZZ_AVAILABLE)
        Object.const_set(:HARFBUZZ_AVAILABLE, false)
        fragment = setup_fragment(@font.decode_utf8('test'), shaping_engine: :harfbuzz)
        error = assert_raises(HexaPDF::Error) { @shaper.shape_text(fragment) }
        assert_match(/harfbuzz-ruby/, error.message)
      ensure
        Object.send(:remove_const, :HARFBUZZ_AVAILABLE)
        Object.const_set(:HARFBUZZ_AVAILABLE, true)
      end
    end
  end
end
