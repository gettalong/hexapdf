# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative 'content/common'
require 'hexapdf/document'
require 'hexapdf/composer'
require 'stringio'

describe HexaPDF::Composer do
  before do
    @composer = HexaPDF::Composer.new
  end

  describe "initialize" do
    it "creates a composer object with default values" do
      assert_kind_of(HexaPDF::Document, @composer.document)
      assert_kind_of(HexaPDF::Type::Page, @composer.page)
      assert_equal(36, @composer.frame.left)
      assert_equal(36, @composer.frame.bottom)
      assert_equal(523, @composer.frame.width)
      assert_equal(770, @composer.frame.height)
      assert_equal("Times", @composer.base_style.font)
    end

    it "allows the customization of the page size" do
      composer = HexaPDF::Composer.new(page_size: [0, 0, 100, 100])
      assert_equal([0, 0, 100, 100], composer.page.box.value)
    end

    it "allows the customization of the page orientation" do
      composer = HexaPDF::Composer.new(page_orientation: :landscape)
      assert_equal([0, 0, 842, 595], composer.page.box.value)
    end

    it "allows the customization of the margin" do
      composer = HexaPDF::Composer.new(margin: [100, 80, 60, 40])
      assert_equal(40, composer.frame.left)
      assert_equal(60, composer.frame.bottom)
      assert_equal(475, composer.frame.width)
      assert_equal(682, composer.frame.height)
    end

    it "yields itself" do
      yielded = nil
      composer = HexaPDF::Composer.new {|c| yielded = c }
      assert_same(composer, yielded)
    end
  end

  describe "::create" do
    it "creates, yields, and writes a document" do
      io = StringIO.new
      HexaPDF::Composer.create(io, &:new_page)
      io.rewind
      assert_equal(2, HexaPDF::Document.new(io: io).pages.count)
    end
  end

  describe "new_page" do
    it "creates a new page with the stored information" do
      c = HexaPDF::Composer.new(page_size: [0, 0, 50, 100], margin: 10)
      c.new_page
      assert_equal([0, 0, 50, 100], c.page.box.value)
      assert_equal(10, c.frame.left)
      assert_equal(10, c.frame.bottom)
    end

    it "uses the provided information for the new and all following pages" do
      @composer.new_page(page_size: [0, 0, 50, 100], margin: 10)
      assert_equal([0, 0, 50, 100], @composer.page.box.value)
      assert_equal(10, @composer.frame.left)
      assert_equal(10, @composer.frame.bottom)
      @composer.new_page
      assert_same(@composer.document.pages[2], @composer.page)
      assert_equal([0, 0, 50, 100], @composer.page.box.value)
      assert_equal(10, @composer.frame.left)
      assert_equal(10, @composer.frame.bottom)
    end
  end

  it "returns the current x-position" do
    assert_equal(36, @composer.x)
  end

  it "returns the current y-position" do
    assert_equal(806, @composer.y)
  end

  describe "text" do
    it "creates a text box and draws it on the canvas" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.text("Test", width: 10, height: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_same(@composer.document.fonts.add("Times"), box.style.font)
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.length)
      assert_same(box.style, items.first.style)
    end

    it "allows setting of a custom style" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.text("Test", style: HexaPDF::Layout::Style.new(font_size: 20))
      assert_same(@composer.document.fonts.add("Times"), box.style.font)
      assert_equal(20, box.style.font_size)
    end

    it "updates the used style with the provided options" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.text("Test", style: HexaPDF::Layout::Style.new, font_size: 20)
      assert_equal(20, box.style.font_size)
    end
  end

  describe "formatted_text" do
    it "creates a text box with the formatted text and draws it on the canvas" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.formatted_text(["Test"], width: 10, height: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal(1, box.instance_variable_get(:@items).length)
    end

    it "a hash can be used for custom style properties" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.formatted_text([{text: "Test", font_size: 20}], align: :center)
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.length)
      assert_equal(20, items.first.style.font_size)
      assert_equal(:center, items.first.style.align)
      assert_equal(10, box.style.font_size)
    end

    it "a hash can be used to provide a custom style" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.formatted_text([{text: "Test", style: HexaPDF::Layout::Style.new(fill_color: 128),
                                 font_size: 20}], align: :center)
      items = box.instance_variable_get(:@items)
      assert_equal(20, items.first.style.font_size)
      assert_equal(128, items.first.style.fill_color)
      assert_equal(:center, items.first.style.align)
    end

    it "a hash can be used to link to an URL" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }

      @composer.formatted_text([{text: "Test", link: "URI"}, {link: "URI"}])
      items = box.instance_variable_get(:@items)
      assert_equal(2, items.length)
      assert_equal(4, items[0].items.length)
      assert_equal(3, items[1].items.length)
      assert_equal([:link, {uri: 'URI'}], items[0].style.overlays.instance_variable_get(:@layers)[0])
    end
  end

  describe "image" do
    it "creates an image box and draws it on the canvas" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }
      image_path = File.join(TEST_DATA_DIR, 'images', 'gray.jpg')

      @composer.image(image_path, width: 10, height: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_same(@composer.document.images.add(image_path), box.image)
    end
  end

  describe "draw_box" do
    def create_box(**kwargs)
      HexaPDF::Layout::Box.new(**kwargs) {}
    end

    it "draws the box if it completely fits" do
      @composer.draw_box(create_box(height: 100))
      @composer.draw_box(create_box)
      assert_operators(@composer.canvas.contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 706]],
                        [:restore_graphics_state],
                        [:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 36]],
                        [:restore_graphics_state]])
    end

    it "draws the box on a new page if the frame is already full" do
      first_page_canvas = @composer.canvas
      @composer.draw_box(create_box)
      @composer.draw_box(create_box)
      refute_same(first_page_canvas, @composer.canvas)
      assert_operators(@composer.canvas.contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 36]],
                        [:restore_graphics_state]])
    end

    it "splits the box across two pages" do
      first_page_contents = @composer.canvas.contents
      @composer.draw_box(create_box(height: 400))

      box = create_box(height: 400)
      box.define_singleton_method(:split) do |*|
        [box, HexaPDF::Layout::Box.new(height: 100) {}]
      end
      @composer.draw_box(box)
      assert_operators(first_page_contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 406]],
                        [:restore_graphics_state],
                        [:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 6]],
                        [:restore_graphics_state]])
      assert_operators(@composer.canvas.contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 706]],
                        [:restore_graphics_state]])
    end

    it "finds a new region if splitting didn't work" do
      first_page_contents = @composer.canvas.contents
      @composer.draw_box(create_box(height: 400))
      @composer.draw_box(create_box(height: 100, width: 300, style: {position: :float}))

      box = create_box(width: 400, height: 400)
      @composer.draw_box(box)
      assert_operators(first_page_contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 406]],
                        [:restore_graphics_state],
                        [:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 306]],
                        [:restore_graphics_state]])
      assert_operators(@composer.canvas.contents,
                       [[:save_graphics_state],
                        [:concatenate_matrix, [1, 0, 0, 1, 36, 406]],
                        [:restore_graphics_state]])
    end

    it "raises an error if a box doesn't fit onto an empty page" do
      assert_raises(HexaPDF::Error) do
        @composer.draw_box(create_box(height: 800))
      end
    end
  end
end
