# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/invalid_glyph'

describe HexaPDF::Font::InvalidGlyph do
  before do
    font = Object.new
    font.define_singleton_method(:missing_glyph_id) { 0 }
    @glyph = HexaPDF::Font::InvalidGlyph.new(font, "str")
  end

  it "returns the missing glyph id for id/name" do
    assert_equal(0, @glyph.id)
    assert_equal(0, @glyph.name)
  end

  it "returns 0 for all glyph dimensions" do
    assert_equal(0, @glyph.x_min)
    assert_equal(0, @glyph.x_max)
    assert_equal(0, @glyph.y_min)
    assert_equal(0, @glyph.y_max)
  end

  it "is a glyph" do
    assert(@glyph.glyph?)
  end

  it "doesn't allow the application of word spacing" do
    refute(@glyph.apply_word_spacing?)
  end
end
