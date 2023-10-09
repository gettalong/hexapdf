# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/frame'
require 'hexapdf/layout/box'
require 'hexapdf/document'

describe HexaPDF::Layout::Frame::FitResult do
  it "shows the box's mask area on #draw when using debug output" do
    doc = HexaPDF::Document.new(config: {'debug' => true})
    canvas = doc.pages.add.canvas
    box = HexaPDF::Layout::Box.create(width: 20, height: 20) {}
    result = HexaPDF::Layout::Frame::FitResult.new(box)
    result.mask = Geom2D::Rectangle(0, 0, 20, 20)
    result.x = result.y = 0
    result.draw(canvas)
    assert_equal(<<~CONTENTS, canvas.contents)
      /OC /P1 BDC
      q
      0.0 0.501961 0.0 rg
      0.0 0.392157 0.0 RG
      /GS1 gs
      0 0 20 20 re
      B
      Q
      EMC
      q
      1 0 0 1 0 0 cm
      Q
    CONTENTS
    ocg = doc.optional_content.ocgs.first
    assert_equal([['Debug', ocg]], doc.optional_content.default_configuration[:Order])
  end
end

describe HexaPDF::Layout::Frame do
  before do
    @frame = HexaPDF::Layout::Frame.new(5, 10, 100, 150)
  end

  it "allows accessing the context's document" do
    assert_nil(@frame.document)
    context = Minitest::Mock.new
    context.expect(:document, :document)
    assert_equal(:document, HexaPDF::Layout::Frame.new(0, 0, 10, 10, context: context).document)
    context.verify
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

  it "allows setting the shape of the frame on initialization" do
    shape = Geom2D::Polygon([50, 10], [55, 100], [105, 100], [105, 10])
    frame = HexaPDF::Layout::Frame.new(5, 10, 100, 150, shape: shape)
    assert_equal(shape, frame.shape)
    assert_equal(55, frame.x)
    assert_equal(100, frame.y)
    assert_equal(50, frame.available_width)
    assert_equal(90, frame.available_height)
  end

  it "returns an appropriate width specification object" do
    ws = @frame.width_specification(10)
    assert_kind_of(HexaPDF::Layout::WidthFromPolygon, ws)
  end

  describe "fit and draw" do
    before do
      @frame = HexaPDF::Layout::Frame.new(10, 10, 100, 100)
      @canvas = Minitest::Mock.new
      def @canvas.context
        Object.new.tap do |ctx|
          def ctx.document; Object.new.tap {|doc| def doc.config; Hash.new(false); end } end
        end
      end
    end

    # Creates a box with the given option, storing it in @box, and draws it inside @frame. It is
    # checked whether the box coordinates are pos and whether the frame has the shape given by
    # points.
    def check_box(box_opts, pos, mask, points)
      flow_supported = !box_opts.delete(:doesnt_support_position_flow)
      @box = HexaPDF::Layout::Box.create(**box_opts) {}
      @box.define_singleton_method(:supports_position_flow?) { true } if flow_supported
      @canvas.expect(:translate, nil, pos)
      fit_result = @frame.fit(@box)
      refute_nil(fit_result)
      @frame.draw(@canvas, fit_result)
      assert_equal(mask, fit_result.mask.bbox.to_a)
      if @frame.shape.respond_to?(:polygons)
        assert_equal(points, @frame.shape.polygons.map(&:to_a))
      else
        assert_equal(points, [@frame.shape.to_a])
      end
      @canvas.verify
    end

    # Removes a 10pt area from the :left, :right or :top.
    def remove_area(*areas)
      areas.each do |area|
        @frame.remove_area(
          case area
          when :left then Geom2D::Rectangle(10, 10, 10, 100)
          when :right then Geom2D::Rectangle(100, 10, 10, 100)
          when :top then Geom2D::Rectangle(10, 100, 100, 10)
          end
        )
      end
    end

    describe "absolute position" do
      it "draws the box at the given absolute position" do
        check_box(
          {width: 50, height: 50, position: :absolute, position_hint: [10, 10]},
          [20, 20],
          [20, 20, 70, 70],
          [[[10, 10], [110, 10], [110, 110], [10, 110]],
           [[20, 20], [70, 20], [70, 70], [20, 70]]]
        )
      end

      it "determines the available space for #fit by using the space to the right and above" do
        check_box(
          {position: :absolute, position_hint: [10, 10]},
          [20, 20],
          [20, 20, 110, 110],
          [[[10, 10], [110, 10], [110, 20], [20, 20], [20, 110], [10, 110]]]
        )
      end

      it "always removes the whole margin box from the frame" do
        check_box(
          {width: 50, height: 50, position: :absolute, position_hint: [10, 10],
           margin: [10, 20, 30, 40]},
          [20, 20],
          [-20, -10, 90, 80],
          [[[10, 80], [90, 80], [90, 10], [110, 10], [110, 110], [10, 110]]]
        )
      end
    end

    describe "default position" do
      it "draws the box on the left side" do
        check_box({width: 50, height: 50},
                  [10, 60],
                  [10, 60, 110, 110],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      it "draws the box on the right side" do
        check_box({width: 50, height: 50, position_hint: :right},
                  [60, 60],
                  [10, 60, 110, 110],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      it "draws the box in the center" do
        check_box({width: 50, height: 50, position_hint: :center},
                  [35, 60],
                  [10, 60, 110, 110],
                  [[[10, 10], [110, 10], [110, 60], [10, 60]]])
      end

      describe "with margin" do
        [:left, :center, :right].each do |hint|
          it "ignores all margins if the box fills the whole frame, with position hint #{hint}" do
            check_box({margin: 10, position_hint: hint},
                      [10, 10], [10, 10, 110, 110], [])
            assert_equal(100, @box.width)
            assert_equal(100, @box.height)
          end

          it "ignores the left/top/right margin if the available bounds coincide with the " \
            "frame's, with position hint #{hint}" do
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 60],
                      [10, 50, 110, 110],
                      [[[10, 10], [110, 10], [110, 50], [10, 50]]])
          end

          it "doesn't ignore top margin if the available bounds' top doesn't coincide with the " \
            "frame's top, with position hint #{hint}" do
            remove_area(:top)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 40],
                      [10, 30, 110, 100],
                      [[[10, 10], [110, 10], [110, 30], [10, 30]]])
            assert_equal(100, @box.width)
          end

          it "doesn't ignore left margin if the available bounds' left doesn't coincide with the " \
            "frame's left, with position hint #{hint}" do
            remove_area(:left)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [30, 60],
                      [10, 50, 110, 110],
                      [[[20, 10], [110, 10], [110, 50], [20, 50]]])
            assert_equal(80, @box.width)
          end

          it "doesn't ignore right margin if the available bounds' right doesn't coincide with " \
            "the frame's right, with position hint #{hint}" do
            remove_area(:right)
            check_box({height: 50, margin: 10, position_hint: hint},
                      [10, 60],
                      [10, 50, 110, 110],
                      [[[10, 10], [100, 10], [100, 50], [10, 50]]])
            assert_equal(80, @box.width)
          end
        end

        it "perfectly centers a box if possible, margins ignored" do
          check_box({width: 50, height: 10, margin: [10, 10, 10, 20], position_hint: :center},
                    [35, 100],
                    [10, 90, 110, 110],
                    [[[10, 10], [110, 10], [110, 90], [10, 90]]])
        end

        it "perfectly centers a box if possible, margins not ignored" do
          remove_area(:left, :right)
          check_box({width: 40, height: 10, margin: [10, 10, 10, 20], position_hint: :center},
                    [40, 100],
                    [10, 90, 110, 110],
                    [[[20, 10], [100, 10], [100, 90], [20, 90]]])
        end

        it "centers a box as good as possible when margins aren't equal" do
          remove_area(:left, :right)
          check_box({width: 20, height: 10, margin: [10, 10, 10, 40], position_hint: :center},
                    [65, 100],
                    [10, 90, 110, 110],
                    [[[20, 10], [100, 10], [100, 90], [20, 90]]])
        end
      end
    end

    describe "floating boxes" do
      it "draws the box on the left side" do
        check_box({width: 50, height: 50, position: :float},
                  [10, 60],
                  [10, 60, 60, 110],
                  [[[10, 10], [110, 10], [110, 110], [60, 110], [60, 60], [10, 60]]])
      end

      it "draws the box on the right side" do
        check_box({width: 50, height: 50, position: :float, position_hint: :right},
                  [60, 60],
                  [60, 60, 110, 110],
                  [[[10, 10], [110, 10], [110, 60], [60, 60], [60, 110], [10, 110]]])
      end

      it "draws the box in the center" do
        check_box({width: 50, height: 50, position: :float, position_hint: :center},
                  [35, 60],
                  [35, 60, 85, 110],
                  [[[10, 10], [110, 10], [110, 110], [85, 110], [85, 60], [35, 60],
                    [35, 110], [10, 110]]])
      end

      describe "with margin" do
        [:left, :center, :right].each do |hint|
          it "ignores all margins if the box fills the whole frame, with position hint #{hint}" do
            check_box({margin: 10, position: :float, position_hint: hint},
                      [10, 10], [10, 10, 110, 110], [])
            assert_equal(100, @box.width)
            assert_equal(100, @box.height)
          end
        end

        it "ignores the left, but not the right margin if aligned left to the frame border" do
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :left},
                    [10, 60],
                    [10, 50, 70, 110],
                    [[[10, 10], [110, 10], [110, 110], [70, 110], [70, 50], [10, 50]]])
        end

        it "uses the left and the right margin if aligned left and not to the frame border" do
          remove_area(:left)
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :left},
                    [30, 60],
                    [20, 50, 90, 110],
                    [[[20, 10], [110, 10], [110, 110], [90, 110], [90, 50], [20, 50]]])
        end

        it "uses the left and the right margin if aligned center" do
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :center},
                    [35, 60],
                    [25, 50, 95, 110],
                    [[[10, 10], [110, 10], [110, 110], [95, 110], [95, 50], [25, 50],
                      [25, 110], [10, 110]]])
        end

        it "ignores the right, but not the left margin if aligned right to the frame border" do
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :right},
                    [60, 60],
                    [50, 50, 110, 110],
                    [[[10, 10], [110, 10], [110, 50], [50, 50], [50, 110], [10, 110]]])
        end

        it "uses the left and the right margin if aligned right and not to the frame border" do
          remove_area(:right)
          check_box({width: 50, height: 50, margin: 10, position: :float, position_hint: :right},
                    [40, 60],
                    [30, 50, 100, 110],
                    [[[10, 10], [100, 10], [100, 50], [30, 50], [30, 110], [10, 110]]])
        end
      end
    end

    describe "flowing boxes" do
      it "flows inside the frame's outline" do
        check_box({width: 10, height: 20, margin: 10, position: :flow},
                  [0, 90],
                  [10, 80, 110, 110],
                  [[[10, 10], [110, 10], [110, 80], [10, 80]]])
      end

      it "uses position=default if the box indicates it doesn't support flowing contents" do
        check_box({width: 10, height: 20, margin: 10, position: :flow, doesnt_support_position_flow: true},
                  [10, 90],
                  [10, 80, 110, 110],
                  [[[10, 10], [110, 10], [110, 80], [10, 80]]])
      end
    end

    it "can't fit the box if there is no available space" do
      @frame.remove_area(Geom2D::Rectangle(0, 0, 110, 110))
      box = HexaPDF::Layout::Box.create
      refute(@frame.fit(box).success?)
    end

    it "handles (but doesn't draw) the box if the its height or width is zero" do
      result = Minitest::Mock.new
      box = Minitest::Mock.new

      result.expect(:box, box)
      box.expect(:height, 0)
      @frame.draw(@canvas, result)

      result.expect(:box, box)
      box.expect(:height, 5)
      result.expect(:box, box)
      box.expect(:width, 0)
      @frame.draw(@canvas, result)

      result.verify
    end
  end

  describe "split" do
    it "splits the box if necessary" do
      box = HexaPDF::Layout::Box.create(width: 10, height: 10)
      assert_equal([box, nil], @frame.split(@frame.fit(box)))
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
      frame.remove_area(Geom2D::Rectangle(20, 20, 60, 60))
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
      frame.remove_area(Geom2D::Rectangle(30, 60, 40, 40))
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
      left_cut = Geom2D::Rectangle(0, 20, 30, 20)
      frame.remove_area(Geom2D::PolygonSet(top_cut, left_cut))

      check_regions(frame, [[0, 100, 20, 60], [0, 90, 20, 50], [0, 80, 100, 40],
                            [30, 80, 70, 80], [0, 20, 100, 20]])
    end
  end
end
