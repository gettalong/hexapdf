# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/graphics_state'

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
