# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../content/common'
require 'hexapdf/document'
require 'hexapdf/layout/box'

describe HexaPDF::Layout::Box do
  def create_box(**args, &block)
    HexaPDF::Layout::Box.new(**args, &block)
  end

  describe "::create" do
    it "passes the block on to #initialize" do
      block = proc {}
      box = HexaPDF::Layout::Box.create(&block)
      assert_same(block, box.instance_eval { @draw_block })
    end

    it "allows specifying style options" do
      box = HexaPDF::Layout::Box.create(background_color: 20)
      assert_equal(20, box.style.background_color)
    end

    it "takes content width and height" do
      box = HexaPDF::Layout::Box.create(width: 100, height: 200, content_box: true,
                                        padding: [10, 8, 6, 4],
                                        border: {width: [10, 8, 6, 4]})
      assert_equal(100, box.content_width)
      assert_equal(200, box.content_height)
    end
  end

  describe "initialize" do
    it "takes box width and height" do
      box = create_box(width: 100, height: 200)
      assert_equal(100, box.width)
      assert_equal(200, box.height)
    end

    it "allows passing a Style object or a hash" do
      box = create_box(style: {padding: 20})
      assert_equal(20, box.style.padding.top)

      box = create_box(style: HexaPDF::Layout::Style.new(padding: 20))
      assert_equal(20, box.style.padding.top)
    end
  end

  describe "fit" do
    before do
      @frame = Object.new
    end

    it "fits a fixed sized box" do
      box = create_box(width: 50, height: 50)
      assert(box.fit(100, 100, @frame))
      assert_equal(50, box.width)
      assert_equal(50, box.height)
    end

    it "uses the maximum available width" do
      box = create_box(height: 50)
      assert(box.fit(100, 100, @frame))
      assert_equal(100, box.width)
      assert_equal(50, box.height)
    end

    it "uses the maximum available height" do
      box = create_box(width: 50)
      assert(box.fit(100, 100, @frame))
      assert_equal(50, box.width)
      assert_equal(100, box.height)
    end

    it "returns false if the box doesn't fit" do
      box = create_box(width: 101)
      refute(box.fit(100, 100, @frame))
    end
  end

  it "can't be split into two parts" do
    box = create_box(width: 100, height: 100)
    assert_equal([nil, box], box.split(50, 50, nil))
  end

  describe "draw" do
    it "draws the box onto the canvas" do
      box = create_box(width: 150, height: 130) do |canvas, _|
        canvas.line_width(15)
      end
      box.style.background_color = 0.5
      box.style.border(width: 5)
      box.style.padding([10, 20])
      box.style.underlays.add {|canvas, _| canvas.line_width(10) }
      box.style.overlays.add {|canvas, _| canvas.line_width(20) }

      @canvas = HexaPDF::Document.new.pages.add.canvas
      box.draw(@canvas, 5, 5)
      assert_operators(@canvas.contents, [[:save_graphics_state],
                                          [:set_device_gray_non_stroking_color, [0.5]],
                                          [:append_rectangle, [5, 5, 150, 130]],
                                          [:fill_path_non_zero],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:concatenate_matrix, [1, 0, 0, 1, 5, 5]],
                                          [:save_graphics_state],
                                          [:set_line_width, [10]],
                                          [:restore_graphics_state],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:set_line_width, [5]],
                                          [:append_rectangle, [5, 5, 150, 130]],
                                          [:clip_path_non_zero], [:end_path],
                                          [:append_rectangle, [7.5, 7.5, 145, 125]],
                                          [:stroke_path],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:concatenate_matrix, [1, 0, 0, 1, 30, 20]],
                                          [:set_line_width, [15]],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:concatenate_matrix, [1, 0, 0, 1, 5, 5]],
                                          [:save_graphics_state],
                                          [:set_line_width, [20]],
                                          [:restore_graphics_state],
                                          [:restore_graphics_state]])
    end

    it "draws nothing onto the canvas if the box is empty" do
      @canvas = HexaPDF::Document.new.pages.add.canvas
      box = create_box
      box.draw(@canvas, 5, 5)
      assert_operators(@canvas.contents, [])
      refute(box.style.background_color?)
      refute(box.style.underlays?)
      refute(box.style.border?)
      refute(box.style.overlays?)
    end
  end

  describe "empty?" do
    it "is only empty when no drawing operation is specified" do
      assert(create_box.empty?)
      refute(create_box {}.empty?)
      refute(create_box(style: {background_color: [5]}).empty?)
      refute(create_box(style: {border: {width: 1}}).empty?)
      refute(create_box(style: {underlays: [proc {}]}).empty?)
      refute(create_box(style: {overlays: [proc {}]}).empty?)
    end
  end
end
