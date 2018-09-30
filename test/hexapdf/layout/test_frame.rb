# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/frame'
require 'hexapdf/layout/box'

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

  it "allows access to the current region attributes" do
    assert_equal(5, @frame.x)
    assert_equal(160, @frame.y)
    assert_equal(100, @frame.available_width)
    assert_equal(150, @frame.available_height)
  end

  describe "contour_line" do
    it "has a contour line equal to the bounding box by default" do
      assert_equal([[5, 10], [5, 160], [105, 160], [105, 10]], @frame.contour_line.polygons[0].to_a)
    end

    it "can have a custom contour line polygon" do
      contour_line = Geom2D::Polygon([0, 0], [10, 10], [10, 0])
      frame = HexaPDF::Layout::Frame.new(0, 0, 10, 10, contour_line: contour_line)
      assert_same(contour_line, frame.contour_line)
    end
  end

  it "returns an appropriate width specification object" do
    ws = @frame.width_specification(10)
    assert_kind_of(HexaPDF::Layout::WidthFromPolygon, ws)
  end

  describe "draw" do
    before do
      @frame = HexaPDF::Layout::Frame.new(10, 10, 100, 100)
      @canvas = Minitest::Mock.new
    end

    it "draws the box at the given absolute position" do
      box = HexaPDF::Layout::Box.create(width: 50, height: 50,
                                        position: :absolute, position_hint: [10, 10])
      assert(@frame.draw(@canvas, box))
      assert_equal([[[10, 10], [110, 10], [110, 110], [10, 110]],
                    [[20, 20], [70, 20], [70, 70], [20, 70]]], @frame.shape.polygons.map(&:to_a))
    end

    describe "default position" do
      it "draws the box on the left side" do
        box = HexaPDF::Layout::Box.create(width: 50, height: 50) {}
        @canvas.expect(:translate, nil, [10, 60])
        assert(@frame.draw(@canvas, box))
        assert_equal([[[10, 10], [110, 10], [110, 60], [10, 60]]], @frame.shape.polygons.map(&:to_a))
        @canvas.verify
      end

      it "draws the box on the right side" do
        box = HexaPDF::Layout::Box.create(width: 50, height: 50, position_hint: :right) {}
        @canvas.expect(:translate, nil, [60, 60])
        assert(@frame.draw(@canvas, box))
        assert_equal([[[10, 10], [110, 10], [110, 60], [10, 60]]], @frame.shape.polygons.map(&:to_a))
        @canvas.verify
      end

      it "draws the box in the center" do
        box = HexaPDF::Layout::Box.create(width: 50, height: 50, position_hint: :center) {}
        @canvas.expect(:translate, nil, [35, 60])
        assert(@frame.draw(@canvas, box))
        assert_equal([[[10, 10], [110, 10], [110, 60], [10, 60]]], @frame.shape.polygons.map(&:to_a))
        @canvas.verify
      end
    end

    describe "floating boxes" do
      it "draws the box on the left side" do
        box = HexaPDF::Layout::Box.create(width: 50, height: 50, position: :float) {}
        @canvas.expect(:translate, nil, [10, 60])
        assert(@frame.draw(@canvas, box))
        assert_equal([[[10, 10], [110, 10], [110, 110], [60, 110], [60, 60], [10, 60]]],
                     @frame.shape.polygons.map(&:to_a))
        @canvas.verify
      end

      it "draws the box on the right side" do
        box = HexaPDF::Layout::Box.create(width: 50, height: 50,
                                          position: :float, position_hint: :right) {}
        @canvas.expect(:translate, nil, [60, 60])
        assert(@frame.draw(@canvas, box))
        assert_equal([[[10, 10], [110, 10], [110, 60], [60, 60], [60, 110], [10, 110]]],
                     @frame.shape.polygons.map(&:to_a))
        @canvas.verify
      end
    end

    it "doesn't draw the box if it doesn't fit into the available space" do
      box = HexaPDF::Layout::Box.create(width: 150, height: 50)
      refute(@frame.draw(@canvas, box))
    end
  end

  describe "find_next_region" do
    # Checks all availability regions of the frame
    def check_regions(frame, regions)
      regions.each_with_index do |region, index|
        assert_equal(region[0], frame.x, "region #{index} invalid x")
        assert_equal(region[1], frame.y, "region #{index} invalid y")
        assert_equal(region[2], frame.available_width, "region #{index} invalid available width")
        assert_equal(region[3], frame.available_height, "region #{index} invalid available height")
        frame.find_next_region
      end
      assert_equal(0, frame.x)
      assert_equal(0, frame.y)
      assert_equal(0, frame.available_width)
      assert_equal(0, frame.available_height)
    end

    # o------+
    # |      |
    # |      |
    # |      |
    # +------+
    it "works for a rectangular region" do
      frame = HexaPDF::Layout::Frame.new(0, 0, 100, 300)
      check_regions(frame, [[0, 300, 100, 300]])
    end

    # o--------+
    # |        |
    # |  +--+  |
    # |  |  |  |
    # |  +--+  |
    # |        |
    # +--------+
    it "works for a region with a hole" do
      frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
      frame.remove_area(Geom2D::Polygon([20, 20], [80, 20], [80, 80], [20, 80]))
      check_regions(frame, [[0, 100, 100, 20], [0, 100, 20, 100],
                            [0, 80, 20, 80], [0, 20, 100, 20]])
    end

    # o--+  +--+
    # |  |  |  |
    # |  +--+  |
    # |        |
    # +--------+
    it "works for a u-shaped frame" do
      frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
      frame.remove_area(Geom2D::Polygon([30, 100], [70, 100], [70, 60], [30, 60]))
      check_regions(frame, [[0, 100, 30, 100], [0, 60, 100, 60]])
    end

    # o---+     +--+
    # |   |  +--+  |
    # |   +--+     |
    # |            |
    # +----+       |
    # +----+       |
    # |            |
    # +------------+
    it "works for a complicated frame" do
      frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
      top_cut = Geom2D::Polygon([20, 100], [20, 80], [40, 80], [40, 90], [60, 90], [60, 100])
      left_cut = Geom2D::Polygon([0, 20], [30, 20], [30, 40], [0, 40])
      frame.remove_area(Geom2D::PolygonSet(top_cut, left_cut))

      check_regions(frame, [[0, 100, 20, 60], [0, 90, 20, 50], [0, 80, 100, 40],
                            [30, 40, 70, 40], [0, 20, 100, 20]])
    end
  end

end
