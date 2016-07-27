# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/type1_wrapper'
require 'hexapdf/document'

FONT_TIMES = HexaPDF::Font::Type1::Font.from_afm(File.join(HexaPDF.data_dir, 'afm', "Times-Roman.afm"))
FONT_SYMBOL = HexaPDF::Font::Type1::Font.from_afm(File.join(HexaPDF.data_dir, 'afm', "Symbol.afm"))

describe HexaPDF::Font::Type1Wrapper do
  before do
    @doc = HexaPDF::Document.new
    @times_wrapper = HexaPDF::Font::Type1Wrapper.new(@doc, FONT_TIMES)
    @symbol_wrapper = HexaPDF::Font::Type1Wrapper.new(@doc, FONT_SYMBOL)
  end

  describe "decode_utf8" do
    it "returns an array of glyph objects" do
      assert_equal([:T, :e, :s, :t], @times_wrapper.decode_utf8("Test").map(&:name))
    end

    it "UTF-8 characters for which no glyph name exist are mapped to themselves" do
      gotten = nil
      @doc.config['font.on_missing_glyph'] = proc {|c| gotten = c; :A }
      assert_equal([:A], @times_wrapper.decode_utf8("😁").map(&:name))
      assert_equal("😁", gotten)
    end
  end

  describe "glyph" do
    it "returns the glyph object for the given name" do
      glyph = @times_wrapper.glyph(:A)
      assert_equal(:A, glyph.name)
      assert_equal(722, glyph.width)
      refute(glyph.space?)
    end

    it "invokes font.on_missing_glyph for missing glyphs" do
      @doc.config['font.on_missing_glyph'] = proc { :A }
      assert_equal(:A, @times_wrapper.glyph(:ffi).name)
    end
  end

  describe "encode" do
    describe "uses WinAnsiEncoding as initial encoding for non-symbolic fonts" do
      it "returns the PDF font dictionary using WinAnsiEncoding and encoded glyph" do
        dict, code = @times_wrapper.encode(@times_wrapper.glyph(:a))
        @doc.dispatch_message(:complete_objects)
        assert_equal("a", code)
        assert_equal(:WinAnsiEncoding, dict[:Encoding])
      end

      it "returns another PDF font dictionary for glyphs not encoded by WinAnsiEncoding" do
        dict, code = @times_wrapper.encode(@times_wrapper.glyph(:uring))
        @doc.dispatch_message(:complete_objects)
        assert_equal("\x21", code)
        assert_equal({Differences: [32, :space, :uring]}, dict[:Encoding])
      end
    end

    describe "uses an empty encoding as initial encoding for symbolic fonts" do
      it "returns the PDF font dictionary and encoded glyph" do
        dict, code = @symbol_wrapper.encode(@symbol_wrapper.glyph(:plus))
        @doc.dispatch_message(:complete_objects)
        assert_equal("\x21", code)
        assert_equal({Differences: [32, :space, :plus]}, dict[:Encoding])
      end
    end
  end
end
