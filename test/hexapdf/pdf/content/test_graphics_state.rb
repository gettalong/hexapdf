# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/graphics_state'

describe HexaPDF::PDF::Content::NamedValue do
  before do
    @val = HexaPDF::PDF::Content::NamedValue.new(:round, 1)
  end

  it "freezes a new object on creation" do
    assert(@val.frozen?)
  end

  it "can be compared to name, value or NamedValue objects" do
    assert_equal(@val, :round)
    assert_equal(@val, 1)
    assert_equal(@val, @val)
  end

  it "returns the value when operands are requested" do
    assert_equal(@val.value, @val.to_operands)
  end
end

describe HexaPDF::PDF::Content::LineCapStyle do
  it "can normalize a style argument" do
    [[:BUTT_CAP, :butt, 0], [:ROUND_CAP, :round, 1],
     [:PROJECTING_SQUARE_CAP, :projecting_square, 2]].each do |const_name, name, value|
      const = HexaPDF::PDF::Content::LineCapStyle.const_get(const_name)
      assert_equal(const, HexaPDF::PDF::Content::LineCapStyle.normalize(name))
      assert_equal(const, HexaPDF::PDF::Content::LineCapStyle.normalize(value))
      assert_equal(const, HexaPDF::PDF::Content::LineCapStyle.normalize(const))
    end
  end

  it "fails when trying to normalize an invalid argument" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::LineCapStyle.normalize(:invalid) }
  end
end

describe HexaPDF::PDF::Content::LineJoinStyle do
  it "can normalize a style argument" do
    [[:MITER_JOIN, :miter, 0], [:ROUND_JOIN, :round, 1],
     [:BEVEL_JOIN, :bevel, 2]].each do |const_name, name, value|
      const = HexaPDF::PDF::Content::LineJoinStyle.const_get(const_name)
      assert_equal(const, HexaPDF::PDF::Content::LineJoinStyle.normalize(name))
      assert_equal(const, HexaPDF::PDF::Content::LineJoinStyle.normalize(value))
      assert_equal(const, HexaPDF::PDF::Content::LineJoinStyle.normalize(const))
    end
  end

  it "fails when trying to normalize an invalid argument" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::LineJoinStyle.normalize(:invalid) }
  end
end

describe HexaPDF::PDF::Content::RenderingIntent do
  it "can normalize an intent argument" do
    assert_equal(HexaPDF::PDF::Content::RenderingIntent::ABSOLUTE_COLORIMETRIC,
                 HexaPDF::PDF::Content::RenderingIntent.normalize(:AbsoluteColorimetric))
    assert_equal(HexaPDF::PDF::Content::RenderingIntent::RELATIVE_COLORIMETRIC,
                 HexaPDF::PDF::Content::RenderingIntent.normalize(:RelativeColorimetric))
    assert_equal(HexaPDF::PDF::Content::RenderingIntent::PERCEPTUAL,
                 HexaPDF::PDF::Content::RenderingIntent.normalize(:Perceptual))
    assert_equal(HexaPDF::PDF::Content::RenderingIntent::SATURATION,
                 HexaPDF::PDF::Content::RenderingIntent.normalize(:Saturation))
  end

  it "fails when trying to normalize an invalid argument" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::RenderingIntent.normalize(:invalid) }
  end
end

describe HexaPDF::PDF::Content::LineDashPattern do
  it "fails on initialization if the phase is negative" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::LineDashPattern.new([], -1) }
  end

  it "fails on initialization if all the dash array values are zero " do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::LineDashPattern.new([0, 0], 0) }
  end

  it "fails on initialization if a dash array value is negative" do
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Content::LineDashPattern.new([-2, 0], 0) }
  end

  it "can be compared to another line dash pattern object" do
    assert_equal(HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 0),
                 HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 0))
    refute_equal(HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 0),
                 HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 1))
    refute_equal(HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 0),
                 HexaPDF::PDF::Content::LineDashPattern.new([2, 2], 0))
  end

  it "returns the operands needed for the line dash pattern operator" do
    assert_equal([[2, 3], 0], HexaPDF::PDF::Content::LineDashPattern.new([2, 3], 0).to_operands)
  end
end

describe HexaPDF::PDF::Content::GraphicsState do
  before do
    @gs = HexaPDF::PDF::Content::GraphicsState.new
  end

  it "allows saving and restoring the graphics state" do
    @gs.save
    @gs.line_width = 10
    @gs.restore
    assert_equal(1, @gs.line_width)
  end

  it "fails when restoring the graphics state if the stack is empty" do
    assert_raises(HexaPDF::Error) { @gs.restore }
  end
end
