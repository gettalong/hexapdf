# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/frame'

describe HexaPDF::Layout::Frame::WidthFromPolygon do
  def create_width_spec(polygon, offset = 0)
    HexaPDF::Layout::Frame::WidthFromPolygon.new(polygon, offset)
  end

  it "respects the offset" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [10, 5]), 5)
    assert_equal([0, 8], ws.call(0, 1))
  end

  it "works in the case bottom and top line are the same" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [10, 5]))
    assert_equal([0, 0], ws.call(0, 0))
    assert_equal([0, 0], ws.call(5, 0))
  end

  it "works when the first segment has not the minimal x-value" do
    ws = create_width_spec(Geom2D::Polygon([10, 10], [10, 0], [0, 0], [5, 10]))
    assert_equal([5, 5], ws.call(0, 1))
    assert_equal([2.5, 7.5], ws.call(5, 1))
  end

  it "works when the polygon is specified in counterclockwise order" do
    ws = create_width_spec(Geom2D::Polygon([10, 10], [5, 10], [0, 0], [10, 0]))
    assert_equal([5, 5], ws.call(0, 1))
    assert_equal([2.5, 7.5], ws.call(5, 1))
  end

  it "works if some segments only cross the top line" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [2, 11], [4, 9], [6, 11], [10, 10],
                                           [10, 0]))
    assert_equal([0, 3, 2, 5], ws.call(1, 2))
  end

  it "works if some segments only cross the bottom line" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [2, 4], [4, 6], [6, 4], [10, 10],
                                           [10, 0]))
    assert_equal([0, 1, 7, 2], ws.call(3, 2))
  end

  it "works if some non-horizontal segments don't cross the top/bottom line at all" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [2, 4], [4, 6.5], [6, 6], [10, 10],
                                           [10, 0]))
    assert_equal([0, 1, 6, 3], ws.call(3, 2))
  end

  it "works if there is no available space" do
    ws = create_width_spec(Geom2D::Polygon([0, 0], [0, 10], [5, 9], [10, 10], [10, 0]))
    assert_equal([0, 0], ws.call(0, 2))
  end

  it "works if the first processed segment doesn't cross both lines" do
    ws = create_width_spec(Geom2D::Polygon([0, 5], [0, 0], [10, 0], [10, 10], [5, 10], [5, 5]))
    assert_equal([5, 5], ws.call(4, 2))
  end

  describe "multiple polygons" do
    it "rectangle in rectangle" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 2], [2, 8], [8, 8], [8, 2])))
      assert_equal([0, 2, 6, 2], ws.call(1, 8))
      assert_equal([0, 10], ws.call(0, 2))
      assert_equal([0, 2, 6, 2], ws.call(2, 1))
      assert_equal([0, 2, 6, 2], ws.call(7, 2))
    end

    it "rectangle in rectangle with reverse direction" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 8], [2, 2], [8, 2], [8, 8])))
      assert_equal([0, 2, 6, 2], ws.call(7, 2))
      assert_equal([0, 2, 6, 2], ws.call(1, 8))
      assert_equal([0, 10], ws.call(0, 2))
      assert_equal([0, 2, 6, 2], ws.call(2, 1))
    end

    it "first segment of inner polygon is between the lines, polygon crosses both lines" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 4], [2, 6], [8, 8], [8, 2])))
      assert_equal([0, 10], ws.call(0, 2))
      assert_equal([0, 5, 3, 2], ws.call(2, 1).map {|f| f.round(5) })
      assert_equal([0, 2, 6, 2], ws.call(3, 4))
    end

    it "first segment of inner polygon is between the lines, polygon crosses one line" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 4], [4, 6], [8, 2])))
      assert_equal([0, 2, 5, 3], ws.call(3, 4))
    end

    it "polygon is partly between the lines, maximum between the lines" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 4], [2, 6], [8, 8], [9, 5],
                                                                [8, 2])))
      assert_equal([0, 2, 7, 1], ws.call(3, 4))
    end

    it "polygon is partly between the lines, maximum is at an line crossing" do
      ws = create_width_spec(Geom2D::PolygonSet(Geom2D::Polygon([0, 0], [0, 10], [10, 10], [10, 0]),
                                                Geom2D::Polygon([2, 4], [8, 8], [5, 5], [8, 2])))
      assert_equal([0, 2, 5, 3], ws.call(3, 4))
    end
  end
end

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
    assert_kind_of(HexaPDF::Layout::Frame::WidthFromPolygon, ws)
  end
end
