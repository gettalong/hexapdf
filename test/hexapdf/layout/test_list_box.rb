# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/layout/list_box'

describe HexaPDF::Layout::ListBox do
  before do
    @frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
    inline_box = HexaPDF::Layout::InlineBox.create(width: 10, height: 10) {}
    @text_boxes = 5.times.map do
      HexaPDF::Layout::TextBox.new(items: [inline_box] * 15, style: {position: :default})
    end
  end

  def create_box(**kwargs)
    HexaPDF::Layout::ListBox.new(content_indentation: 10, **kwargs)
  end

  def check_box(box, width, height, fit_pos = nil)
    assert(box.fit(@frame.available_width, @frame.available_height, @frame), "box didn't fit")
    assert_equal(width, box.width, "box width")
    assert_equal(height, box.height, "box height")
    if fit_pos
      results = box.instance_variable_get(:@results)
      results.each_with_index do |box_fitter, item_index|
        box_fitter.fit_results.each_with_index do |fit_result, result_index|
          x, y = fit_pos.shift
          assert_equal(x, fit_result.x, "item #{item_index}, result #{result_index}, x")
          assert_equal(y, fit_result.y, "item #{item_index}, result #{result_index}, y")
        end
      end
      assert(fit_pos.empty?)
    end
  end

  describe "initialize" do
    it "creates a new instance with the given arguments" do
      box = create_box(children: [:a], item_type: :circle, content_indentation: 15,
                       start_number: 4, item_spacing: 20)
      assert_equal([:a], box.children)
      assert_equal(:circle, box.item_type)
      assert_equal(15, box.content_indentation)
      assert_equal(4, box.start_number)
      assert_equal(20, box.item_spacing)
      assert(box.supports_position_flow?)
    end
  end

  describe "empty?" do
    it "is empty if nothing was fit yet" do
      assert(create_box.empty?)
    end

    it "is empty if nothing could be fit" do
      box = create_box(children: [@text_boxes[0]], width: 5)
      box.fit(@frame.available_width, @frame.available_height, @frame)
      assert(create_box.empty?)
    end
  end

  describe "fit" do
    [:default, :flow].each do |position|
      it "respects the set initial width, position #{position}" do
        box = create_box(children: @text_boxes[0, 2], width: 50, style: {position: position})
        check_box(box, 50, 80)
      end

      it "respects the set initial height, position #{position}" do
        box = create_box(children: @text_boxes[0, 2], height: 50, style: {position: position})
        check_box(box, 100, 40)
      end

      it "respects the border and padding around all list items, position #{position}" do
        box = create_box(children: @text_boxes[0, 2],
                         style: {border: {width: [5, 4, 3, 2]}, padding: [5, 4, 3, 2], position: position})
        check_box(box, 100, 76, [[14, 60], [14, 30]])
      end
    end

    it "uses the frame's current cursor position and available width/height when position=:default" do
      @frame.remove_area(Geom2D::Polygon([0, 0], [10, 0], [10, 90], [100, 90], [100, 100], [0, 100]))
      box = create_box(children: @text_boxes[0, 2])
      check_box(box, 90, 40, [[20, 70], [20, 50]])
    end

    it "respects the frame's shape when style position=:flow" do
      @frame.remove_area(Geom2D::Polygon([0, 0], [0, 40], [40, 40], [40, 0]))
      box = create_box(children: @text_boxes[0, 4], style: {position: :flow})
      check_box(box, 100, 90, [[10, 80], [10, 60], [10, 40], [50, 10]])
    end

    it "respects the content indentation" do
      box = create_box(children: @text_boxes[0, 1], content_indentation: 30)
      check_box(box, 100, 30, [[30, 70]])
    end

    it "respects the spacing between list items" do
      box = create_box(children: @text_boxes[0, 2], item_spacing: 30)
      check_box(box, 100, 70, [[10, 80], [10, 30]])
    end
  end

  describe "split" do
    it "splits before a list item if no part of it will fit" do
      box = create_box(children: @text_boxes[0, 2], height: 20)
      box.fit(100, 100, @frame)
      box_a, box_b = box.split(100, 100, @frame)
      assert_same(box, box_a)
      assert_equal(:show_first_marker, box_b.split_box?)
      assert_equal(1, box_a.instance_variable_get(:@results)[0].fit_results.size)
      assert_equal(1, box_b.children.size)
      assert_equal(2, box_b.start_number)
    end

    it "splits a list item if some part of it will fit" do
      box = create_box(children: @text_boxes[0, 2], height: 10)
      box.fit(100, 100, @frame)
      box_a, box_b = box.split(100, 100, @frame)
      assert_same(box, box_a)
      assert_equal(:hide_first_marker, box_b.split_box?)
      assert_equal(1, box_a.instance_variable_get(:@results)[0].fit_results.size)
      assert_equal(2, box_b.children.size)
      assert_equal(1, box_b.start_number)
    end
  end

  describe "draw" do
    before do
      @canvas = HexaPDF::Document.new.pages.add.canvas
      draw_block = lambda {|canvas, box| }
      @fixed_size_boxes = 5.times.map { HexaPDF::Layout::Box.new(width: 20, height: 10, &draw_block) }
    end

    it "draws the result" do
      box = create_box(children: @fixed_size_boxes[0, 2])
      box.fit(100, 100, @frame)
      box.draw(@canvas, 0, 100 - box.height)
      operators = [
        [:save_graphics_state],
        [:set_font_and_size, [:F1, 10]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 1.5, 93.17]],
        [:show_text, ["\x95".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 90]],
        [:restore_graphics_state],

        [:save_graphics_state],
        [:set_font_and_size, [:F1, 10]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 1.5, 83.17]],
        [:show_text, ["\x95".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 80]],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "draws a cicle as marker" do
      box = create_box(children: @fixed_size_boxes[0, 1], item_type: :circle)
      box.fit(100, 100, @frame)
      box.draw(@canvas, 0, 100 - box.height)
      operators = [
        [:save_graphics_state],
        [:set_font_and_size, [:F1, 5]],
        [:set_text_rise, [-5.555556]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 0.635, 100]],
        [:show_text, ["m".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 90]],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "draws a square as marker" do
      box = create_box(children: @fixed_size_boxes[0, 1], item_type: :square)
      box.fit(100, 100, @frame)
      box.draw(@canvas, 0, 100 - box.height)
      operators = [
        [:save_graphics_state],
        [:set_font_and_size, [:F1, 5]],
        [:set_text_rise, [-5.555556]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 1.195, 100]],
        [:show_text, ["n".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 90]],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "draws decimal numbers as marker" do
      box = create_box(children: @fixed_size_boxes[0, 2], item_type: :decimal,
                       content_indentation: 20)
      box.fit(100, 100, @frame)
      box.draw(@canvas, 0, 100 - box.height)
      operators = [
        [:save_graphics_state],
        [:set_font_and_size, [:F1, 10]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 7.5, 93.17]],
        [:show_text, ["1.".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 20, 90]],
        [:restore_graphics_state],

        [:save_graphics_state],
        [:set_font_and_size, [:F1, 10]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 7.5, 83.17]],
        [:show_text, ["2.".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 20, 80]],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "allows drawing custom markers" do
      marker = lambda do |_doc, _list_box, _index|
        HexaPDF::Layout::Box.create(width: 10, height: 10) {}
      end
      box = create_box(children: @fixed_size_boxes[0, 1], item_type: marker)
      box.fit(100, 100, @frame)
      box.draw(@canvas, 0, 100 - box.height)
      operators = [
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 0, 90]],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 90]],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "takes a different final location into account" do
      box = create_box(children: @fixed_size_boxes[0, 1])
      box.fit(100, 100, @frame)
      box.draw(@canvas, 20, 10)
      operators = [
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 20, -80]],
        [:save_graphics_state],
        [:set_font_and_size, [:F1, 10]],
        [:begin_text],
        [:set_text_matrix, [1, 0, 0, 1, 1.5, 93.17]],
        [:show_text, ["\x95".b]],
        [:end_text],
        [:restore_graphics_state],
        [:save_graphics_state],
        [:concatenate_matrix, [1, 0, 0, 1, 10, 90]],
        [:restore_graphics_state],
        [:restore_graphics_state],
      ]
      assert_operators(@canvas.contents, operators)
    end

    it "fails for unknown item types" do
      box = create_box(children: @fixed_size_boxes[0, 1], item_type: :unknown)
      box.fit(100, 100, @frame)
      assert_raises(HexaPDF::Error) { box.draw(@canvas, 0, 0) }
    end
  end
end
