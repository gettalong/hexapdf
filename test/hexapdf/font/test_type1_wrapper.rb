# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative 'type1/common'
require 'hexapdf/font/type1_wrapper'
require 'hexapdf/document'

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
      assert_equal(15, glyph.x_min)
      assert_equal(0, glyph.y_min)
      assert_equal(706, glyph.x_max)
      assert_equal(674, glyph.y_max)
      assert(glyph.glyph?)
      refute(glyph.apply_word_spacing?)
    end

    it "invokes font.on_missing_glyph for missing glyphs" do
      assert_raises(HexaPDF::Error) { @times_wrapper.glyph(:ffi) }
    end
  end

  describe "encode" do
    describe "uses WinAnsiEncoding as initial encoding for non-symbolic fonts" do
      it "returns the PDF font dictionary using WinAnsiEncoding and encoded glyph" do
        code = @times_wrapper.encode(@times_wrapper.glyph(:a))
        @doc.dispatch_message(:complete_objects)
        assert_equal("a", code)
        assert_equal(:WinAnsiEncoding, @times_wrapper.dict[:Encoding])
      end

      it "fails if the encoding does not support the given glyph" do
        assert_raises(HexaPDF::Error) { @times_wrapper.encode(@times_wrapper.glyph(:uring)) }
      end
    end

    describe "uses an empty encoding as initial encoding for symbolic fonts" do
      it "returns the PDF font dictionary and encoded glyph" do
        code = @symbol_wrapper.encode(@symbol_wrapper.glyph(:plus))
        @doc.dispatch_message(:complete_objects)
        assert_equal("\x21", code)
        assert_equal({Differences: [32, :space, :plus]}, @symbol_wrapper.dict[:Encoding])
      end
    end
  end
end
