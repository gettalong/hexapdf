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
      assert_equal([[5, 10], [105, 10], [105, 160], [5, 160]], @frame.contour_line.polygons[0].to_a)
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

  describe "fit and draw" do
    before do
      @frame = HexaPDF::Layout::Frame.new(10, 10, 100, 100)
      @canvas = Minitest::Mock.new
    end

    # Creates a box with the given option, storing it in @box, and draws it inside @frame. It is
    # checked whether the box coordinates are pos and whether the frame has the shape given by
    # points.
    def check_box(box_opts, pos, points)
      @box = HexaPDF::Layout::Box.create(**box_opts) {}
      @canvas.expect(:translate, nil, pos)
      assert(@frame.draw(@canvas, @box))
      assert_equal(points, @frame.shape.polygons.map(&:to_a))
      @canvas.verify
    end

    # Removes a 10pt area from the :left, :right or :top.
    def remove_area(*areas)
      areas.each do |area|
        @frame.remove_area(
          case area
          when :left then Geom2D::Polygon([10, 10], [10, 110], [20, 110], [20, 10])
          when :right then Geom2D::Polygon([100, 10], [100, 110], [110, 110], [110, 10])
          when :top then Geom2D::Polygon([10, 110], [110, 110], [110, 100], [10, 100])
          end
        )
      end
    end

    describe "absolute position" do
      it "draws the box at the given absolute position" do
        check_box(
          {width: 50, height: 50, position: :absolute, position_hint: [10, 10]},
          [20, 20],
          [[[10, 10], [110, 10], [110, 110], [10, 110]],
           [[20, 20], [70, 20], [70, 70], [20, 70]]]
        )
      end

      it "determines the available space for #fit by using the space to the right and above" do
        check_box(
          {position: :absolute, position_hint: [10, 10]},
          [20, 20],
          [[[10, 10], [110, 10], [110, 20], [20, 20], [20, 110], [10, 110]]]
        )
      end

      it "always removes the whole margin box from the frame" do
        check_box(
          {width: 50, height: 50, position: :absolute, position_hint: [10, 10],
           margin: [10, 20, 30, 40]},
          [20, 20],
          [[[10, 80], [90, 80], [90, 10], [110, 10], [110, 110], [10, 110]]]
        )
      end
    end

    describe "default position" do
      it "draws the box on the left side" do
        check_box({width: 50, height: 50},
                  [10, 60],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      it "draws the box on the right side" do
        check_box({width: 50, height: 50, position_hint: :right},
                  [60, 60],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      it "draws the box in the center" do
        check_box({width: 50, height: 50, position_hint: :center},
                  [35, 60],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      describe "with margin" do
        [:left, :center, :right].each do |hint|
          it "ignores all margins if the box fills the whole frame, with position hint #{hint}" do
            check_box({margin: 10, position_hint: hint},
                      [10, 10], [])
            assert_equal(100, @box.width)
            assert_equal(100, @box.height)
          end

          it "ignores the left/top/right margin if the available bounds coincide with the " \
            "frame's, with position hint #{hint}" do
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 60],
                      [[[10, 10], [110, 10], [110, 50], [10, 50]]])
          end

          it "doesn't ignore top margin if the available bounds' top doesn't coincide with the " \
            "frame's top, with position hint #{hint}" do
            remove_area(:top)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 40],
                      [[[10, 10], [110, 10], [110, 30], [10, 30]]])
            assert_equal(100, @box.width)
          end

          it "doesn't ignore left margin if the available bounds' left doesn't coincide with the " \
            "frame's left, with position hint #{hint}" do
            remove_area(:left)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [30, 60],
                      [[[20, 10], [110, 10], [110, 50], [20, 50]]])
            assert_equal(80, @box.width)
          end

          it "doesn't ignore right margin if the available bounds' right doesn't coincide with " \
            "the frame's right, with position hint #{hint}" do
            remove_area(:right)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 60],
                      [[[10, 10], [100, 10], [100, 50], [10, 50]]])
            assert_equal(80, @box.width)
          end
        end

        it "perfectly centers a box if possible, margins ignored" do
          check_box({width: 50, height: 10, margin: [10, 10, 10, 20], position_hint: :center},
                    [35, 100],
                    [[[10, 10], [110, 10], [110, 90], [10, 90]]])
        end

        it "perfectly centers a box if possible, margins not ignored" do
          remove_area(:left, :right)
          check_box({width: 40, height: 10, margin: [10, 10, 10, 20], position_hint: :center},
                    [40, 100],
                    [[[20, 10], [100, 10], [100, 90], [20, 90]]])
        end

        it "centers a box as good as possible when margins aren't equal" do
          remove_area(:left, :right)
          check_box({width: 20, height: 10, margin: [10, 10, 10, 40], position_hint: :center},
                    [65, 100],
                    [[[20, 10], [100, 10], [100, 90], [20, 90]]])
        end
      end
    end

    describe "floating boxes" do
      it "draws the box on the left side" do
        check_box({width: 50, height: 50, position: :float},
                  [10, 60],
                  [[[10, 10], [110, 10], [110, 110], [60, 110], [60, 60], [10, 60]]])
      end

      it "draws the box on the right side" do
        check_box({width: 50, height: 50, position: :float, position_hint: :right},
                  [60, 60],
                  [[[10, 10], [110, 10], [110, 60], [60, 60], [60, 110], [10, 110]]])
      end

      describe "with margin" do
        [:left, :right].each do |hint|
          it "ignores all margins if the box fills the whole frame, with position hint #{hint}" do
            check_box({margin: 10, position: :float, position_hint: hint},
                      [10, 10], [])
            assert_equal(100, @box.width)
            assert_equal(100, @box.height)
          end
        end

        it "ignores the left, but not the right margin if aligned left to the frame border" do
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :left},
                    [10, 60],
                    [[[10, 10], [110, 10], [110, 110], [70, 110], [70, 50], [10, 50]]])
        end

        it "uses the left and the right margin if aligned left and not to the frame border" do
          remove_area(:left)
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :left},
                    [30, 60],
                    [[[20, 10], [110, 10], [110, 110], [90, 110], [90, 50], [20, 50]]])
        end

        it "ignores the right, but not the left margin if aligned right to the frame border" do
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :right},
                    [60, 60],
                    [[[10, 10], [110, 10], [110, 50], [50, 50], [50, 110], [10, 110]]])
        end

        it "uses the left and the right margin if aligned right and not to the frame border" do
          remove_area(:right)
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :right},
                    [40, 60],
                    [[[10, 10], [100, 10], [100, 50], [30, 50], [30, 110], [10, 110]]])
        end
      end
    end

    describe "flowing boxes" do
      it "flows inside the frame's outline" do
        check_box({width: 10, height: 20, position: :flow},
                  [0, 90],
                  [[[10, 10], [110, 10], [110, 90], [10, 90]]])
      end
    end

    it "doesn't draw the box if it doesn't fit into the available space" do
      box = HexaPDF::Layout::Box.create(width: 150, height: 50)
      refute(@frame.draw(@canvas, box))
    end

    it "can't fit the box if there is no available space" do
      @frame.remove_area(Geom2D::Polygon([0, 0], [110, 0], [110, 110], [0, 110]))
      box = HexaPDF::Layout::Box.create
      refute(@frame.fit(box))
    end

    it "draws the box even if the box's height is zero" do
      box = HexaPDF::Layout::Box.create
      box.define_singleton_method(:height) { 0 }
      assert(@frame.draw(@canvas, box))
    end
  end

  describe "split" do
    it "splits the box if necessary" do
      box = HexaPDF::Layout::Box.create(width: 10, height: 10)
      assert_equal([nil, box], @frame.split(box))
      assert_nil(@frame.instance_variable_get(:@fit_data).box)
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

  describe "remove_area" do
    it "recalculates the contour line only if necessary" do
      contour = Geom2D::Polygon([10, 10], [10, 90], [90, 90], [90, 10])
      frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100, contour_line: contour)
      frame.remove_area(Geom2D::Polygon([0, 0], [20, 0], [20, 100], [0, 100]))
      assert_equal([[[20, 10], [90, 10], [90, 90], [20, 90]]],
                   frame.contour_line.polygons.map(&:to_a))
    end
  end
end
