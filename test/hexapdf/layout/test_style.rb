# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/style'
require 'hexapdf/layout/text_box'

describe HexaPDF::Layout::Style::LineSpacing do
  before do
    @line1 = Object.new
    @line1.define_singleton_method(:y_min) { - 1}
    @line1.define_singleton_method(:y_max) { 2 }
    @line2 = Object.new
    @line2.define_singleton_method(:y_min) { -3 }
    @line2.define_singleton_method(:y_max) { 4 }
  end

  def line_spacing(type, value = nil)
    HexaPDF::Layout::Style::LineSpacing.new(type, value: value)
  end

  it "allows single line spacing" do
    obj = line_spacing(:single)
    assert_equal(:proportional, obj.type)
    assert_equal(1, obj.value)
    assert_equal(1 + 4, obj.baseline_distance(@line1, @line2))
    assert_equal(0, obj.gap(@line1, @line2))
  end

  it "allows double line spacing" do
    obj = line_spacing(:double)
    assert_equal(:proportional, obj.type)
    assert_equal(2, obj.value)
    assert_equal((1 + 4) * 2, obj.baseline_distance(@line1, @line2))
    assert_equal(1 + 4, obj.gap(@line1, @line2))
  end

  it "allows proportional line spacing" do
    obj = line_spacing(:proportional, 1.5)
    assert_equal(:proportional, obj.type)
    assert_equal(1.5, obj.value)
    assert_equal((1 + 4) * 1.5, obj.baseline_distance(@line1, @line2))
    assert_equal((1 + 4) * 0.5, obj.gap(@line1, @line2))
  end

  it "allows fixed line spacing" do
    obj = line_spacing(:fixed, 7)
    assert_equal(:fixed, obj.type)
    assert_equal(7, obj.value)
    assert_equal(7, obj.baseline_distance(@line1, @line2))
    assert_equal(7 - 1 -  4, obj.gap(@line1, @line2))
  end

  it "allows line spacing using a leading value" do
    obj = line_spacing(:leading, 3)
    assert_equal(:leading, obj.type)
    assert_equal(3, obj.value)
    assert_equal(1 + 4 + 3, obj.baseline_distance(@line1, @line2))
    assert_equal(3, obj.gap(@line1, @line2))
  end

  it "allows using a LineSpacing object as type" do
    obj = line_spacing(line_spacing(:single))
    assert_equal(:proportional, obj.type)
  end

  it "raises an error if a value is needed and none is provided" do
    assert_raises(ArgumentError) { line_spacing(:proportional) }
  end

  it "raises an error if an invalid type is provided" do
    assert_raises(ArgumentError) { line_spacing(:invalid) }
  end
end

describe HexaPDF::Layout::Style do
  before do
    @style = HexaPDF::Layout::Style.new
  end

  it "can assign values on initialization" do
    style = HexaPDF::Layout::Style.new(font_size: 10)
    assert_equal(10, style.font_size)
  end

  it "has several dynamically generated properties with default values" do
    assert_raises(HexaPDF::Error) { @style.font }
    assert_equal(10, @style.font_size)
    assert_equal(0, @style.character_spacing)
    assert_equal(0, @style.word_spacing)
    assert_equal(100, @style.horizontal_scaling)
    assert_equal(0, @style.text_rise)
    assert_equal({}, @style.font_features)
    assert_equal(:fill, @style.text_rendering_mode)
    assert_equal([0], @style.fill_color.components)
    assert_equal(1, @style.fill_alpha)
    assert_equal([0], @style.stroke_color.components)
    assert_equal(1, @style.stroke_alpha)
    assert_equal(1, @style.stroke_width)
    assert_equal(:butt, @style.stroke_cap_style)
    assert_equal(:miter, @style.stroke_join_style)
    assert_equal(10.0, @style.stroke_miter_limit)
    assert_equal(:left, @style.align)
    assert_equal(:top, @style.valign)
  end

  it "can set and retrieve stroke dash pattern objects" do
    assert_equal([[], 0], @style.stroke_dash_pattern.to_operands)
    @style.stroke_dash_pattern(5, 2)
    assert_equal([[5], 2], @style.stroke_dash_pattern.to_operands)
  end

  it "can set and retrieve line spacing objects" do
    assert_equal([:proportional, 1], [@style.line_spacing.type, @style.line_spacing.value])
    @style.line_spacing = :double
    assert_equal([:proportional, 2], [@style.line_spacing.type, @style.line_spacing.value])
  end

  it "can set and retrieve text segmentation algorithms" do
    assert_equal(HexaPDF::Layout::TextBox::SimpleTextSegmentation,
                 @style.text_segmentation_algorithm)
    block = proc { :y }
    @style.text_segmentation_algorithm(&block)
    assert_equal(block, @style.text_segmentation_algorithm)
  end

  it "can set and retrieve line wrapping algorithms" do
    assert_equal(HexaPDF::Layout::TextBox::SimpleLineWrapping,
                 @style.text_line_wrapping_algorithm)
    @style.text_line_wrapping_algorithm(:callable)
    assert_equal(:callable, @style.text_line_wrapping_algorithm)
  end

  it "has methods for some derived and cached values" do
    assert_equal(0.01, @style.scaled_font_size)
    assert_equal(0, @style.scaled_character_spacing)
    assert_equal(0, @style.scaled_word_spacing)
    assert_equal(1, @style.scaled_horizontal_scaling)

    wrapped_font = Object.new
    wrapped_font.define_singleton_method(:ascender) { 600 }
    wrapped_font.define_singleton_method(:descender) { -100 }
    font = Object.new
    font.define_singleton_method(:scaling_factor) { 1 }
    font.define_singleton_method(:wrapped_font) { wrapped_font }
    @style.font = font

    assert_equal(6, @style.scaled_font_ascender)
    assert_equal(-1, @style.scaled_font_descender)
  end

  it "can clear cached values" do
    assert_equal(0.01, @style.scaled_font_size)
    @style.font_size = 20
    assert_equal(0.01, @style.scaled_font_size)
    @style.clear_cache
    assert_equal(0.02, @style.scaled_font_size)
  end
end
