# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/ttf_wrapper'
require 'hexapdf/document'

describe HexaPDF::Font::TTFWrapper do
  before do
    @doc = HexaPDF::Document.new
    font_file = File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf")
    @font = HexaPDF::Font::TTF::Font.new(io: File.open(font_file))
    @cmap = @font[:cmap].preferred_table
    @font_wrapper = HexaPDF::Font::TTFWrapper.new(@doc, @font)
  end

  after do
    @font.io.close
  end

  describe "initialize" do
    it "fails if the TrueType font has no Unicode cmap table" do
      @font[:cmap].tables.clear
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TTFWrapper.new(@doc, @font) }
    end
  end

  describe "decode_utf8" do
    it "returns an array of glyph objects" do
      assert_equal("Test",
                   @font_wrapper.decode_utf8("Test").map {|g| @cmap.gid_to_code(g.id)}.pack('U*'))
    end

    it "UTF-8 characters for which no glyph exists are mapped to the .notdef glyph" do
      gotten = nil
      @doc.config['font.on_missing_glyph'] = proc {|c| gotten = c; 0 }
      assert_equal([0], @font_wrapper.decode_utf8("😁").map(&:id))
      assert_equal(128513, gotten)
    end
  end

  describe "glyph" do
    it "returns the glyph object for the given id" do
      glyph = @font_wrapper.glyph(3)
      assert_equal(3, glyph.id)
      assert_equal(338, glyph.width)
      assert(glyph.space?)
    end

    it "invokes font.on_missing_glyph for missing glyphs" do
      assert_raises(HexaPDF::Error) { @font_wrapper.glyph(9999) }
    end
  end

  describe "encode" do
    it "returns the PDF font dictionary and the encoded glyph" do
      dict = @font_wrapper.dict

      code = @font_wrapper.encode(@font_wrapper.glyph(3))
      assert_equal([3].pack('n'), code)
      glyph = @font_wrapper.decode_utf8('H').first
      code = @font_wrapper.encode(glyph)
      assert_equal([glyph.id].pack('n'), code)

      @doc.dispatch_message(:complete_objects)

      # Checking Type 0 font dictionary
      assert_equal(:Font, dict[:Type])
      assert_equal(:Type0, dict[:Subtype])
      assert_equal(:'Identity-H', dict[:Encoding])
      assert_equal(1, dict[:DescendantFonts].length)
      assert_equal(dict[:BaseFont], dict[:DescendantFonts][0][:BaseFont])
      assert_equal(HexaPDF::Font::CMap.create_to_unicode_cmap([[3, ' '.ord], [glyph.id, 'H'.ord]]),
                   dict[:ToUnicode].stream)

      # Checking CIDFont dictionary
      cidfont = dict[:DescendantFonts][0]
      assert_equal(:Font, cidfont[:Type])
      assert_equal(:CIDFontType2, cidfont[:Subtype])
      assert_equal({Registry: "Adobe", Ordering: "Identity", Supplement: 0}, cidfont[:CIDSystemInfo])
      assert_equal(:Identity, cidfont[:CIDToGIDMap])
      assert_equal(@font_wrapper.glyph(3).width, cidfont[:DW])
      assert_equal([glyph.id, [glyph.width]], cidfont[:W])

      # Checking font descriptor
      fd = cidfont[:FontDescriptor]
      assert_equal(dict[:BaseFont], fd[:FontName])
      assert(fd.flagged?(:symbolic))
      assert(fd.key?(:FontFile2))
      assert(fd.validate)

      @cmap.stub(:[], nil) do
        @font[:'OS/2'].typo_ascender = 1000
        font_wrapper = HexaPDF::Font::TTFWrapper.new(@doc, @font)
        font_wrapper.encode(glyph)
        fd = font_wrapper.dict[:DescendantFonts][0][:FontDescriptor]
        assert_equal(800, fd[:CapHeight])
        assert_equal(500, fd[:XHeight])
      end

      @font[:'OS/2'].version = 2
      @font[:'OS/2'].x_height = 500 * @font[:head].units_per_em / 1000
      @font[:'OS/2'].cap_height = 1000 * @font[:head].units_per_em / 1000
      font_wrapper = HexaPDF::Font::TTFWrapper.new(@doc, @font)
      font_wrapper.encode(glyph)
      fd = font_wrapper.dict[:DescendantFonts][0][:FontDescriptor]
      assert_equal(1000, fd[:CapHeight])
      assert_equal(500, fd[:XHeight])
    end
  end
end
