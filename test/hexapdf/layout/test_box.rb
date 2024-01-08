# -*- encoding: utf-8 -*-

require 'test_helper'
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

    it "allows specifying a style object" do
      box = HexaPDF::Layout::Box.create(style: {background_color: 20})
      assert_equal(20, box.style.background_color)
    end

    it "allows specifying style properties" do
      box = HexaPDF::Layout::Box.create(background_color: 20)
      assert_equal(20, box.style.background_color)
    end

    it "applies the additional style properties to the style object" do
      box = HexaPDF::Layout::Box.create(style: {background_color: 20}, background_color: 15)
      assert_equal(15, box.style.background_color)
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

    it "allows setting custom properties" do
      assert_equal({}, create_box(properties: nil).properties)
      assert_equal({'key' => :value}, create_box(properties: {'key' => :value}).properties)
    end
  end

  it "returns false when asking whether it is a split box by default" do
    refute(create_box.split_box?)
  end

  it "doesn't support the position :flow" do
    refute(create_box.supports_position_flow?)
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

    it "uses float comparison" do
      box = create_box(width: 50.0000002, height: 49.9999996)
      assert(box.fit(50, 50, @frame))
      assert_equal(50.0000002, box.width)
      assert_equal(49.9999996, box.height)
    end

    it "returns false if the box doesn't fit" do
      box = create_box(width: 101)
      refute(box.fit(100, 100, @frame))
    end
  end

  describe "split" do
    before do
      @box = create_box(width: 100, height: 100)
      @box.fit(100, 100, nil)
    end

    it "doesn't need to be split if it completely fits" do
      assert_equal([@box, nil], @box.split(100, 100, nil))
    end

    it "can't be split if it doesn't (completely) fit and its width is greater than the available width" do
      @box.fit(90, 100, nil)
      assert_equal([nil, @box], @box.split(50, 150, nil))
    end

    it "can't be split if it doesn't (completely) fit and its height is greater than the available height" do
      @box.fit(90, 100, nil)
      assert_equal([nil, @box], @box.split(150, 50, nil))
    end

    it "can't be split if it doesn't (completely) fit and its content width is zero" do
      box = create_box(width: 0, height: 100)
      assert_equal([nil, box], box.split(150, 150, nil))
    end

    it "can't be split if it doesn't (completely) fit and its content height is zero" do
      box = create_box(width: 100, height: 0)
      assert_equal([nil, box], box.split(150, 150, nil))
    end

    it "can't be split if it doesn't (completely) fit as the default implementation " \
      "knows nothing about the content" do
      @box.style.position = :flow # make sure we would generally be splitable
      @box.fit(90, 100, nil)
      assert_equal([nil, @box], @box.split(150, 150, nil))
    end
  end

  it "can create a cloned box for splitting" do
    box = create_box
    box.fit(100, 100, nil)
    cloned_box = box.send(:create_split_box)
    assert(cloned_box.split_box?)
    refute(cloned_box.instance_variable_get(:@fit_successful))
    assert_equal(0, cloned_box.width)
    assert_equal(0, cloned_box.height)
  end

  describe "draw" do
    before do
      @canvas = HexaPDF::Document.new.pages.add.canvas
    end

    it "draws the box onto the canvas" do
      box = create_box(width: 150, height: 130) do |canvas, _|
        canvas.line_width(15)
      end
      box.style.background_color = 0.5
      box.style.background_alpha = 0.5
      box.style.border(width: 5)
      box.style.padding([10, 20])
      box.style.underlays.add {|canvas, _| canvas.line_width(10) }
      box.style.overlays.add {|canvas, _| canvas.line_width(20) }

      box.draw(@canvas, 5, 5)
      assert_operators(@canvas.contents, [[:save_graphics_state],
                                          [:set_graphics_state_parameters, [:GS1]],
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
      box = create_box
      box.draw(@canvas, 5, 5)
      assert_operators(@canvas.contents, [])
      refute(box.style.background_color?)
      refute(box.style.underlays?)
      refute(box.style.border?)
      refute(box.style.overlays?)
    end

    it "wraps the box in optional content markers if the optional_content property is set" do
      box = create_box(properties: {'optional_content' => 'Text'})
      box.draw(@canvas, 0, 0)
      assert_operators(@canvas.contents, [[:begin_marked_content_with_property_list, [:OC, :P1]],
                                          [:end_marked_content]])
    end
  end

  describe "empty?" do
    it "is empty when no drawing operation is specified" do
      assert(create_box.empty?)
      refute(create_box {}.empty?)
      refute(create_box(style: {background_color: [5]}).empty?)
      refute(create_box(style: {border: {width: 1}}).empty?)
      refute(create_box(style: {underlays: [proc {}]}).empty?)
      refute(create_box(style: {overlays: [proc {}]}).empty?)
    end
  end
end
