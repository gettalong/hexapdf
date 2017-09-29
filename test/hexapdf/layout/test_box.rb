# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../content/common'
require 'hexapdf/document'
require 'hexapdf/layout/box'

describe HexaPDF::Layout::Box do
  def create_box(*args, &block)
    HexaPDF::Layout::Box.new(*args, &block)
  end

  describe "initialize" do
    it "takes content width and height" do
      box = create_box(content_width: 100, content_height: 200)
      assert_equal(100, box.content_width)
      assert_equal(200, box.content_height)
    end

    it "takes box width and height" do
      box = create_box(width: 100, height: 200)
      assert_equal(100, box.content_width)
      assert_equal(200, box.content_height)

      box = create_box(width: 100, height: 200, style: {padding: [20, 10], border: {width: [10, 5]}})
      assert_equal(70, box.content_width)
      assert_equal(140, box.content_height)
    end

    it "allows passing a Style object or a hash" do
      box = create_box(style: {padding: 20})
      assert_equal(20, box.style.padding.top)

      box = create_box(style: HexaPDF::Layout::Style.new(padding: 20))
      assert_equal(20, box.style.padding.top)
    end
  end

  it "returns the full width and height of the box" do
    box = create_box(content_width: 100, content_height: 200,
                     style: {padding: [20, 10], border: {width: [10, 5]}})
    assert_equal(130, box.width)
    assert_equal(260, box.height)
  end

  it "draws the box onto the canvas" do
    box = create_box(content_width: 100, content_height: 100) do |canvas, _|
      canvas.line_width(15)
    end
    box.style.background_color = 0.5
    box.style.border(width: 5)
    box.style.padding([10, 20])
    box.style.underlay_callback {|canvas, _| canvas.line_width(10) }
    box.style.overlay_callback {|canvas, _| canvas.line_width(20) }

    @canvas = HexaPDF::Document.new.pages.add.canvas
    box.draw(@canvas, 5, 5)
    assert_operators(@canvas.contents, [[:save_graphics_state],
                                        [:set_device_gray_non_stroking_color, [0.5]],
                                        [:append_rectangle, [5, 5, 150, 130]],
                                        [:fill_path_non_zero],
                                        [:restore_graphics_state],
                                        [:save_graphics_state],
                                        [:concatenate_matrix, [1, 0, 0, 1, 5, 5]],
                                        [:set_line_width, [10]],
                                        [:restore_graphics_state],
                                        [:save_graphics_state],
                                        [:set_line_width, [5]],
                                        [:append_rectangle, [7.5, 7.5, 145, 125]],
                                        [:stroke_path],
                                        [:restore_graphics_state],
                                        [:save_graphics_state],
                                        [:concatenate_matrix, [1, 0, 0, 1, 30, 20]],
                                        [:set_line_width, [15]],
                                        [:restore_graphics_state],
                                        [:save_graphics_state],
                                        [:concatenate_matrix, [1, 0, 0, 1, 5, 5]],
                                        [:set_line_width, [20]],
                                        [:restore_graphics_state],
                                       ])
  end
end
