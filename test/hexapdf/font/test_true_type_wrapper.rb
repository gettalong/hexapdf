# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/true_type_wrapper'
require 'hexapdf/document'

describe HexaPDF::Font::TrueTypeWrapper do
  before do
    @doc = HexaPDF::Document.new
    @font_file = File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf")
    @font = HexaPDF::Font::TrueType::Font.new(File.open(@font_file))
    @cmap = @font[:cmap].preferred_table
    @font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font)
  end

  after do
    @font.io.close
  end

  describe "initialize" do
    it "fails if the TrueType font has no Unicode cmap table" do
      @font[:cmap].tables.clear
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TrueTypeWrapper.new(@doc, @font) }
    end
  end

  it "can be asked whether font wil be subset" do
    assert(@font_wrapper.subset?)
    refute(HexaPDF::Font::TrueTypeWrapper.new(@doc, @font, subset: false).subset?)
  end

  describe "decode_utf8" do
    it "returns an array of glyph objects" do
      assert_equal("Test",
                   @font_wrapper.decode_utf8("Test").map {|g| @cmap.gid_to_code(g.id) }.pack('U*'))
    end

    it "invokes font.on_missing_glyph for UTF-8 characters for which no glyph exists" do
      glyphs = @font_wrapper.decode_utf8("😁")
      assert_equal(1, glyphs.length)
      assert_kind_of(HexaPDF::Font::InvalidGlyph, glyphs.first)
      assert_equal('' << 128_513, glyphs.first.str)
    end
  end

  describe "glyph" do
    it "returns the glyph object for the given id" do
      glyph = @font_wrapper.glyph(17)
      assert_equal(17, glyph.id)
      assert_equal("0", glyph.str)
      assert_equal(628, glyph.width)
      assert_equal(47, glyph.x_min)
      assert_equal(0, glyph.y_min)
      assert_equal(584, glyph.x_max)
      assert_equal(696, glyph.y_max)
      refute(glyph.apply_word_spacing?)
      assert_equal('#<HexaPDF::Font::TrueTypeWrapper::Glyph font="Ubuntu-Title" id=17 "0">',
                   glyph.inspect)
    end

    it "invokes font.on_missing_glyph for missing glyphs" do
      glyph = @font_wrapper.glyph(9999)
      assert_kind_of(HexaPDF::Font::InvalidGlyph, glyph)
      assert_equal(0, glyph.id)
      assert_equal('' << 0xFFFD, glyph.str)
    end
  end

  describe "encode" do
    it "returns the encoded glyph ID for fonts that are subset" do
      code = @font_wrapper.encode(@font_wrapper.glyph(3))
      assert_equal([1].pack('n'), code)
      code = @font_wrapper.encode(@font_wrapper.glyph(10))
      assert_equal([2].pack('n'), code)
    end

    it "returns the encoded glyph ID for fonts that are not subset" do
      @font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font, subset: false)
      code = @font_wrapper.encode(@font_wrapper.glyph(3))
      assert_equal([3].pack('n'), code)
      code = @font_wrapper.encode(@font_wrapper.glyph(10))
      assert_equal([10].pack('n'), code)
    end

    it "raises an error if an InvalidGlyph is encoded" do
      assert_raises(HexaPDF::Error) { @font_wrapper.encode(@font_wrapper.glyph(9999)) }
    end
  end

  describe "creates the necessary PDF dictionaries" do
    it "with fonts that are subset" do
      @font_wrapper.encode(@font_wrapper.glyph(3))
      glyph = @font_wrapper.decode_utf8('H').first
      @font_wrapper.encode(glyph)
      @doc.dispatch_message(:complete_objects)

      dict = @font_wrapper.pdf_object

      # Checking the circular reference
      assert_same(@font_wrapper, dict.font_wrapper)

      # Checking Type 0 font dictionary
      assert_equal(:Font, dict[:Type])
      assert_equal(:Type0, dict[:Subtype])
      assert_equal(:'Identity-H', dict[:Encoding])
      assert_equal(1, dict[:DescendantFonts].length)
      assert_equal(dict[:BaseFont], dict[:DescendantFonts][0][:BaseFont])
      assert_equal(HexaPDF::Font::CMap.create_to_unicode_cmap([[1, ' '.ord], [2, 'H'.ord]]),
                   dict[:ToUnicode].stream)
      assert_match(/\A[A-Z]{6}\+Ubuntu-Title\z/, dict[:BaseFont])

      # Checking CIDFont dictionary
      cidfont = dict[:DescendantFonts][0]
      assert_equal(:Font, cidfont[:Type])
      assert_equal(:CIDFontType2, cidfont[:Subtype])
      assert_equal({Registry: "Adobe", Ordering: "Identity", Supplement: 0},
                   cidfont[:CIDSystemInfo].value)
      assert_equal(:Identity, cidfont[:CIDToGIDMap])
      assert_equal(@font_wrapper.glyph(3).width, cidfont[:DW])
      assert_equal([2, [glyph.width]], cidfont[:W].value)
      assert(cidfont.validate)

      # Checking font descriptor
      fd = cidfont[:FontDescriptor]
      assert_equal(dict[:BaseFont], fd[:FontName])
      assert(fd.flagged?(:symbolic))
      assert(fd.key?(:FontFile2))
      assert(fd.validate)

      # Two special cases for determining cap height and x-height
      @cmap.stub(:[], nil) do
        @font[:'OS/2'].typo_ascender = 1000
        font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font)
        font_wrapper.encode(glyph)
        fd = font_wrapper.pdf_object[:DescendantFonts][0][:FontDescriptor]
        assert_equal(800, fd[:CapHeight])
        assert_equal(500, fd[:XHeight])
      end

      @font[:'OS/2'].version = 2
      @font[:'OS/2'].x_height = 500 * @font[:head].units_per_em / 1000
      @font[:'OS/2'].cap_height = 1000 * @font[:head].units_per_em / 1000
      font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font)
      font_wrapper.encode(glyph)
      fd = font_wrapper.pdf_object[:DescendantFonts][0][:FontDescriptor]
      assert_equal(1000, fd[:CapHeight])
      assert_equal(500, fd[:XHeight])
    end

    it "with fonts that are not subset (only differences to other case)" do
      @font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font, subset: false)
      @font_wrapper.encode(@font_wrapper.glyph(3))
      glyph = @font_wrapper.decode_utf8('H').first
      @font_wrapper.encode(glyph)
      @doc.dispatch_message(:complete_objects)

      dict = @font_wrapper.pdf_object

      assert_equal(HexaPDF::Font::CMap.create_to_unicode_cmap([[3, ' '.ord], [glyph.id, 'H'.ord]]),
                   dict[:ToUnicode].stream)
      assert_equal([glyph.id, [glyph.width]], dict[:DescendantFonts][0][:W].value)
    end
  end

  describe "font file embedding" do
    it "embeds subset fonts" do
      @font_wrapper.encode(@font_wrapper.glyph(10))
      @doc.dispatch_message(:complete_objects)

      font_data = @font_wrapper.pdf_object[:DescendantFonts][0][:FontDescriptor][:FontFile2].stream
      font = HexaPDF::Font::TrueType::Font.new(StringIO.new(font_data))
      assert_equal(@font[:glyf][0].raw_data, font[:glyf][0].raw_data)
      assert_equal(@font[:glyf][10].raw_data, font[:glyf][1].raw_data)
    end

    it "embeds full fonts" do
      @font_wrapper = HexaPDF::Font::TrueTypeWrapper.new(@doc, @font, subset: false)
      @doc.dispatch_message(:complete_objects)

      assert_equal(File.size(@font_file),
                   @font_wrapper.pdf_object[:DescendantFonts][0][:FontDescriptor][:FontFile2][:Length1])
      assert_equal(File.binread(@font_file),
                   @font_wrapper.pdf_object[:DescendantFonts][0][:FontDescriptor][:FontFile2].stream)
    end
  end
end
