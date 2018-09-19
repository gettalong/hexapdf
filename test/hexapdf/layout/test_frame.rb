# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/frame'

describe HexaPDF::Layout::Frame do
  before do
    @frame = HexaPDF::Layout::Frame.new(5, 10, 100, 150)
  end

  it "allows access to the bounding box attributes" do
    assert_equal(5, @frame.left)
    assert_equal(10, @frame.bottom)
    assert_equal(100, @frame.width)
    assert_equal(150, @frame.height)
  end

  describe "outline" do
    it "has an outline equal to the bounding box by default" do
      assert_equal([[5, 10], [5, 160], [105, 160], [105, 10]], @frame.outline.to_a)
    end

    it "can have a custom outline polygon" do
      outline = Geom2D::Polygon([0, 0], [10, 10], [10, 0])
      frame = HexaPDF::Layout::Frame.new(0, 0, 10, 10, outline: outline)
      assert_same(outline, frame.outline)
    end
  end

  it "returns an appropriate width specification object" do
    ws = @frame.width_specification(10)
    assert_kind_of(HexaPDF::Layout::WidthFromPolygon, ws)
  end
end
