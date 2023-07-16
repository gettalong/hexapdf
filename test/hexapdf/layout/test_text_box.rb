# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/layout/text_box'

describe HexaPDF::Layout::TextBox do
  before do
    @frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
    @inline_box = HexaPDF::Layout::InlineBox.create(width: 10, height: 10) {}
  end

  def create_box(items, **kwargs)
    HexaPDF::Layout::TextBox.new(items: items, **kwargs)
  end

  describe "initialize" do
    it "takes the inline items to be layed out in the box" do
      box = create_box([], width: 100)
      assert_equal(100, box.width)
    end

    it "supports flowing text around other content" do
      assert(create_box([]).supports_position_flow?)
    end
  end

  describe "fit" do
    it "fits into a rectangular area" do
      box = create_box([@inline_box] * 5, style: {padding: 10})
      assert(box.fit(100, 100, @frame))
      assert_equal(70, box.width)
      assert_equal(30, box.height)
    end

    it "respects the set width and height" do
      box = create_box([@inline_box], width: 40, height: 50, style: {padding: 10})
      assert(box.fit(100, 100, @frame))
      assert_equal(40, box.width)
      assert_equal(50, box.height)
      assert_equal([10], box.instance_variable_get(:@result).lines.map(&:width))
    end

    it "fits into the frame's outline" do
      inline_box = HexaPDF::Layout::InlineBox.create(width: 10, height: 10) {}
      box = create_box([inline_box] * 20, style: {position: :flow})
      assert(box.fit(100, 100, @frame))
      assert_equal(100, box.width)
      assert_equal(20, box.height)
    end

    it "takes the style option last_line_gap into account" do
      box = create_box([@inline_box] * 5, style: {last_line_gap: true, line_spacing: :double})
      assert(box.fit(100, 100, @frame))
      assert_equal(50, box.width)
      assert_equal(20, box.height)
    end

    it "uses the whole available width when aligning to the center or right" do
      [:center, :right].each do |align|
        box = create_box([@inline_box], style: {align: align})
        assert(box.fit(100, 100, @frame))
        assert_equal(100, box.width)
      end
    end

    it "uses the whole available height when vertically aligning to the center or bottom" do
      [:center, :bottom].each do |valign|
        box = create_box([@inline_box], style: {valign: valign})
        assert(box.fit(100, 100, @frame))
        assert_equal(100, box.height)
      end
    end

    it "can't fit the text box if the set width is bigger than the available width" do
      box = create_box([@inline_box], width: 101)
      refute(box.fit(100, 100, @frame))
    end

    it "can't fit the text box if the set height is bigger than the available height" do
      box = create_box([@inline_box], height: 101)
      refute(box.fit(100, 100, @frame))
    end
  end

  describe "split" do
    it "works for an empty text box" do
      box = create_box([])
      assert_equal([box], box.split(100, 100, @frame))
    end

    it "doesn't need to split the box if it completely fits" do
      box = create_box([@inline_box] * 5)
      assert_equal([box], box.split(50, 100, @frame))
    end

    it "works if no item of the text box fits" do
      box = create_box([@inline_box])
      assert_equal([nil, box], box.split(5, 20, @frame))
    end

    it "works if the whole text box doesn't fits" do
      box = create_box([@inline_box], width: 102)
      assert_equal([nil, box], box.split(100, 100, @frame))

      box = create_box([@inline_box], height: 102)
      assert_equal([nil, box], box.split(100, 100, @frame))
    end

    it "works if the box fits exactly (+/- float divergence)" do
      box = create_box([@inline_box] * 5)
      box.fit(50, 10, @frame)
      box.instance_variable_set(:@width, 50.00000000006)
      box.instance_variable_set(:@height, 10.00000000003)
      assert_equal([box], box.split(50, 10, @frame))
    end

    it "splits the box if necessary when using non-flowing text" do
      box = create_box([@inline_box] * 10)
      boxes = box.split(50, 10, @frame)
      assert_equal(2, boxes.length)
      assert_equal(box, boxes[0])
      refute(boxes[0].split_box?)
      assert(boxes[1].split_box?)
      assert_equal(5, boxes[1].instance_variable_get(:@items).length)
    end

    it "splits the box if necessary when using flowing text that results in a wider box" do
      @frame.remove_area(Geom2D::Polygon.new([[0, 100], [50, 100], [50, 10], [0, 10]]))
      box = create_box([@inline_box] * 60, style: {position: :flow})
      boxes = box.split(50, 100, @frame)
      assert_equal(2, boxes.length)
      assert_equal(box, boxes[0])
      assert_equal(5, boxes[1].instance_variable_get(:@items).length)
    end
  end

  describe "draw" do
    it "draws the layed out inline items onto the canvas" do
      inline_box = HexaPDF::Layout::InlineBox.create(width: 10, height: 10,
                                                     border: {width: 1})
      box = create_box([inline_box], width: 100, height: 30, style: {padding: [10, 5]})
      box.fit(100, 100, nil)

      @canvas = HexaPDF::Document.new.pages.add.canvas
      box.draw(@canvas, 0, 0)
      assert_operators(@canvas.contents, [[:save_graphics_state],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:concatenate_matrix, [1, 0, 0, 1, 5, 10]],
                                          [:save_graphics_state],
                                          [:append_rectangle, [0, 0, 10, 10]],
                                          [:clip_path_non_zero],
                                          [:end_path],
                                          [:append_rectangle, [0.5, 0.5, 9.0, 9.0]],
                                          [:stroke_path],
                                          [:restore_graphics_state],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:restore_graphics_state]])
    end

    it "draws nothing onto the canvas if the box is empty" do
      @canvas = HexaPDF::Document.new.pages.add.canvas
      box = create_box([])
      box.draw(@canvas, 5, 5)
      assert_operators(@canvas.contents, [])
    end
  end

  it "is empty if there is a result without any text lines" do
    box = create_box([])
    assert(box.empty?)
    box.fit(100, 100, @frame)
    assert(box.empty?)

    box = create_box([@inline_box])
    box.fit(100, 100, @frame)
    refute(box.empty?)
  end
end
