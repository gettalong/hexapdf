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

  describe "font_wrapper" do
    it "returns the default value if the font is subset" do
      @font[:BaseFont] = :'ABCDEF+Something'
      assert_nil(@font.font_wrapper)
    end

    it "returns the default value if the font has no embedded font file" do
      assert_nil(@font.font_wrapper)
    end

    it "uses a fully embedded TrueType font file" do
      font_file = File.binread(File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf"))
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: font_file)
      font_wrapper = @font.font_wrapper
      assert(font_wrapper)
      assert_equal(font_file, font_wrapper.wrapped_font.io.string)
      assert_same(font_wrapper, @font.font_wrapper)
    end
  end

  describe "encoding" do
    before do
      @font.delete(:Encoding)
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: ubuntu_font_data)
    end

    it "returns an encoding backed by the embedded font's Unicode cmap" do
      enc = @font.encoding
      assert_equal("A", enc.unicode(65))
      assert_nil(enc.unicode(0))  # U+0000 not mapped in Ubuntu-Title.ttf
    end

    it "returns nil for a code mapping to glyph 0 (notdef)" do
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: build_minimal_ttf(0, 3))
      enc = @font.encoding
      assert_nil(enc.unicode(0))    # glyph_id=0 -> nil
      assert_equal("A", enc.unicode(65))
    end

    it "returns MacRomanEncoding when only a Mac Roman cmap is available" do
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: build_minimal_ttf(1, 0))
      assert_equal(HexaPDF::Font::Encoding.for_name(:MacRomanEncoding), @font.encoding)
    end

    it "fails if the font is not embedded" do
      @font[:FontDescriptor].delete(:FontFile2)
      assert_raises(HexaPDF::Error) { @font.encoding }
    end

    it "fails if no usable cmap is found in the embedded font" do
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: build_minimal_ttf(3, 4))
      assert_raises(HexaPDF::Error) { @font.encoding }
    end

    it "fails if the embedded font has no cmap table" do
      @font[:FontDescriptor][:FontFile2] = @doc.add({}, stream: build_minimal_ttf_no_cmap)
      assert_raises(HexaPDF::Error) { @font.encoding }
    end

    private

    def ubuntu_font_data
      File.binread(File.join(TEST_DATA_DIR, "fonts", "Ubuntu-Title.ttf"))
    end

    # Builds a minimal TTF binary containing a single format-0 cmap subtable.
    # Code 65 maps to glyph 1, all other codes map to glyph 0.
    def build_minimal_ttf(platform_id, encoding_id)
      glyph_ids = Array.new(256, 0)
      glyph_ids[65] = 1
      subtable = [0, 262, 0].pack("n3") + glyph_ids.pack("C256")
      cmap_data = [0, 1].pack("n2") +
                  [platform_id, encoding_id, 12].pack("n2N") +
                  subtable
      cmap_offset = 28
      "\x00\x01\x00\x00".b + [1, 16, 0, 0].pack("n4") +
        "cmap".b + [0, cmap_offset, cmap_data.bytesize].pack("N3") +
        cmap_data
    end

    # Builds a minimal TTF binary with no tables (simulates a font missing the cmap table).
    def build_minimal_ttf_no_cmap
      "\x00\x01\x00\x00".b + [0, 0, 0, 0].pack("n4")
    end
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
