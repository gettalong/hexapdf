# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/font_type1'

describe HexaPDF::Type::FontType1::StandardFonts do
  before do
    @obj = HexaPDF::Type::FontType1::StandardFonts
  end

  it "checks whether a given name corresponds to a standard font via #standard_font?" do
    assert(@obj.standard_font?(:"Times-Roman"))
    assert(@obj.standard_font?(:TimesNewRoman))
    refute(@obj.standard_font?(:LibreSans))
  end

  it "returns the standard PDF name for an alias via #standard_name" do
    assert_equal(:"Times-Roman", @obj.standard_name(:TimesNewRoman))
  end

  describe "font" do
    it "returns the Type1 font object for a given standard name" do
      font = @obj.font(:"Times-Roman")
      assert_equal("Times Roman", font.full_name)
    end

    it "caches the font for reuse" do
      font = @obj.font(:"Times-Roman")
      assert_same(font, @obj.font(:"Times-Roman"))
    end

    it "returns nil if the given name doesn't belong to a standard font" do
      refute_nil(@obj.font(:TimesNewRoman))
    end
  end
end

describe HexaPDF::Type::FontType1 do
  before do
    @doc = HexaPDF::Document.new
    @font = @doc.add(Type: :Font, Subtype: :Type1, Encoding: :WinAnsiEncoding,
                     BaseFont: :"Times-Roman")

    font_file = @doc.add({}, stream: <<-EOF)
      /Encoding 256 array
      0 1 255 {1 index exch /.notdef put} for
      dup 32 /A put
      dup 34 /B put
      readonly def
    EOF
    cmap = @doc.add({}, stream: <<-EOF)
      2 beginbfchar
      <20> <0041>
      <22> <0042>
      endbfchar
    EOF
    font_descriptor = @doc.add(Type: :FontDescriptor, FontName: :Embedded, Flags: 0b100,
                               FontBBox: [0, 1, 2, 3], ItalicAngle: 0, Ascent: 900,
                               Descent: -100, CapHeight: 800, StemV: 20, FontFile: font_file)
    @embedded_font = @doc.add(Type: :Font, Subtype: :Type1, Encoding: :WinAnsiEncoding,
                              BaseFont: :Embedded, FontDescriptor: font_descriptor, ToUnicode: cmap,
                              FirstChar: 32, LastChar: 34, Widths: [600, 0, 700])
  end

  describe "encoding" do
    it "returns the font's internal encoding if /Encoding is absent" do
      @embedded_font.delete(:Encoding)
      assert_equal({32 => :A, 34 => :B}, @embedded_font.encoding.code_to_name)
    end

    describe "/Encoding is a name" do
      it "returns a predefined encoding if /Encoding specifies one" do
        @font[:Encoding] = :WinAnsiEncoding
        assert_equal(HexaPDF::Font::Encoding.for_name(:WinAnsiEncoding), @font.encoding)
      end

      it "returns the font's internal encoding if /Encoding is an invalid name" do
        @embedded_font[:Encoding] = :SomethingUnknown
        assert_equal({32 => :A, 34 => :B}, @embedded_font.encoding.code_to_name)
      end
    end

    describe "/Encoding is a dictionary" do
      before do
        @font[:Encoding] = {}
        @embedded_font[:Encoding] = {}
      end

      describe "no /BaseEncoding is specified" do
        it "returns the font's internal encoding if the font is embedded" do
          assert_equal({32 => :A, 34 => :B}, @embedded_font.encoding.code_to_name)
        end

        it "returns the StandardEncoding for a non-symbolic non-embedded font" do
          assert_equal(HexaPDF::Font::Encoding.for_name(:StandardEncoding), @font.encoding)
        end

        it "returns the font's internal encoding for a symbolic non-embedded font" do
          @font[:BaseFont] = :Symbol
          symbol_font = HexaPDF::Type::FontType1::StandardFonts.font(:Symbol)
          assert_equal(symbol_font.encoding, @font.encoding)
        end
      end

      it "returns the encoding specified by /BaseEncoding" do
        @font[:Encoding] = {BaseEncoding: :WinAnsiEncoding}
        assert_equal(HexaPDF::Font::Encoding.for_name(:WinAnsiEncoding), @font.encoding)
      end

      it "returns the font's internal encoding if /BaseEncoding is an invalid name" do
        @font[:Encoding] = {BaseEncoding: :SomethingUnknown}
        assert_equal(HexaPDF::Font::Encoding.for_name(:StandardEncoding), @font.encoding)
      end

      it "returns a difference encoding if /Differences is specified" do
        @font[:Encoding][:Differences] = [32, :A, :B, 34, :Z]
        refute_equal(HexaPDF::Font::Encoding.for_name(:StandardEncoding), @font.encoding)
        assert_equal(:A, @font.encoding.name(32))
        assert_equal(:B, @font.encoding.name(33))
        assert_equal(:Z, @font.encoding.name(34))
      end

      it "fails if the /Differences array contains invalid data" do
        @font[:Encoding][:Differences] = [:B, 32, :A, :B, 34, :Z]
        assert_raises(HexaPDF::Error) { @font.encoding }

        @font[:Encoding][:Differences] = [32, "data", :A, :B, 34, :Z]
        assert_raises(HexaPDF::Error) { @font.encoding }
      end
    end

    it "fails if /Encoding contains an invalid value" do
      @font[:Encoding] = 5
      assert_raises(HexaPDF::Error) { @font.encoding }
    end

    it "fails if /Encoding is absent and the font is not embedded" do
      @embedded_font.delete(:Encoding)
      @embedded_font[:FontDescriptor].delete(:FontFile)
      assert_raises(HexaPDF::Error) { @embedded_font.encoding }
    end
  end

  describe "decode" do
    it "just returns the bytes of the string since this is a simple 1-byte-per-code font" do
      assert_equal([65, 66], @font.decode("AB"))
    end
  end

  describe "to_utf" do
    it "uses a /ToUnicode CMap if it is available" do
      assert_equal("A", @embedded_font.to_utf8(32))
      assert_equal("B", @embedded_font.to_utf8(34))
    end

    it "uses the font's encoding to map the code to an UTF-8 string" do
      assert_equal(" ", @font.to_utf8(32))
    end

    it "returns an empty string if no correct mapping could be found" do
      assert_equal("", @font.to_utf8(0))
    end
  end

  describe "writing_mode" do
    it "is always horizontal" do
      assert_equal(:horizontal, @font.writing_mode)
    end
  end

  describe "width" do
    it "returns the glyph width when using a standard font" do
      assert_equal(250, @font.width(32))
    end

    it "returns the glyph width when using a non-standard font" do
      assert_equal(600, @embedded_font.width(32))
    end

    it "returns 0 when the width for the code point is not specified" do
      assert_equal(0, @font.width(0))
      assert_equal(0, @embedded_font.width(0))
    end

    it "returns the /MissingWidth of a /FontDescriptor if available and the width was not found" do
      @embedded_font[:FontDescriptor][:MissingWidth] = 99
      assert_equal(99, @embedded_font.width(0))
    end

    it "fails if no valid glyph width information is available" do
      @embedded_font.delete(:FontDescriptor)
      assert_raises(HexaPDF::Error) { @embedded_font.width(0) }
    end
  end

  describe "bounding_box" do
    it "returns the bounding box for a standard font" do
      font = HexaPDF::Type::FontType1::StandardFonts.font(:"Times-Roman")
      assert_equal(font.bounding_box, @font.bounding_box)
    end

    it "returns the bounding box for a non-standard font" do
      assert_equal([0, 1, 2, 3], @embedded_font.bounding_box)
    end

    it "raises an error if no bounding box information can be found" do
      @embedded_font[:FontDescriptor].delete(:FontBBox)
      assert_raises(HexaPDF::Error) {  @embedded_font.bounding_box }
    end
  end

  describe "embedded" do
    it "returns true if the font is embedded" do
      assert(@embedded_font.embedded?)
      refute(@font.embedded?)
    end
  end

  describe "symbolic?" do
    it "return true if the font is symbolic" do
      refute(@font.symbolic?)

      @font[:BaseFont] = :Symbol
      assert(@font.symbolic?)

      @font[:BaseFont] = :ZapfDingbats
      assert(@font.symbolic?)

      assert(@embedded_font.symbolic?)
    end

    it "returns nil if it cannot be determined whether the font is symbolic" do
      @embedded_font.delete(:FontDescriptor)
      assert_nil(@embedded_font.symbolic?)
    end
  end

  describe "validation" do
    it "validates the existence of required keys for non-standard fonts" do
      assert(@font.validate)
      assert(@embedded_font.validate)

      @embedded_font.delete(:FirstChar)
      refute(@embedded_font.validate)
    end

    it "validates the lengths of the /Widths field" do
      @embedded_font[:Widths] = [65]
      refute(@embedded_font.validate)
    end
  end
end
