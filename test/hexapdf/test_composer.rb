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
      assert_kind_of(HexaPDF::Layout::Style, @composer.style(:base))
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

  describe "style" do
    it "creates a new style if it does not exist based on the base argument" do
      @composer.style(:base, font_size: 20)
      assert_equal(20, @composer.style(:newstyle, subscript: true).font_size)
      refute(@composer.style(:base).subscript)
      assert_equal(10, @composer.style(:another_new, base: nil).font_size)
      assert(@composer.style(:yet_another_new, base: :newstyle).subscript)
    end

    it "returns the named style" do
      assert_kind_of(HexaPDF::Layout::Style, @composer.style(:base))
    end

    it "updates the style with the given properties" do
      assert_equal(20, @composer.style(:base, font_size: 20).font_size)
    end
  end

  describe "text" do
    before do
      test_self = self
      @composer.define_singleton_method(:draw_box) do |arg|
        test_self.instance_variable_set(:@box, arg)
      end
    end

    it "creates a text box and draws it on the canvas" do
      @composer.text("Test", width: 10, height: 15)
      assert_equal(10, @box.width)
      assert_equal(15, @box.height)
      assert_same(@composer.document.fonts.add("Times"), @box.style.font)
      items = @box.instance_variable_get(:@items)
      assert_equal(1, items.length)
      assert_same(@box.style, items.first.style)
    end

    it "allows setting of a custom style" do
      style = HexaPDF::Layout::Style.new(font_size: 20, font: ['Times', {variant: :bold}])
      @composer.text("Test", style: style)
      assert_same(@box.style, style)
      assert_same(@composer.document.fonts.add("Times", variant: :bold), @box.style.font)
      assert_equal(20, @box.style.font_size)

      @composer.text("Test", style: {font_size: 20})
      assert_equal(20, @box.style.font_size)

      @composer.style(:named, font_size: 20)
      @composer.text("Test", style: :named)
      assert_equal(20, @box.style.font_size)
    end

    it "updates the used style with the provided options" do
      @composer.text("Test", style: {subscript: true}, font_size: 20)
      assert_equal(20, @box.style.font_size)
    end

    it "allows using a box style different from the text style" do
      style = HexaPDF::Layout::Style.new(font_size: 20)
      @composer.text("Test", box_style: style)
      refute_same(@box.instance_variable_get(:@items).first.style, style)
      assert_same(@box.style, style)

      @composer.style(:named, font_size: 20)
      @composer.text("Test", box_style: :named)
      assert_equal(20, @box.style.font_size)
    end
  end

  describe "formatted_text" do
    before do
      test_self = self
      @composer.define_singleton_method(:draw_box) do |arg|
        test_self.instance_variable_set(:@box, arg)
      end
    end

    it "creates a text box with the given text and draws it on the canvas" do
      @composer.formatted_text(["Test"], width: 10, height: 15)
      assert_equal(10, @box.width)
      assert_equal(15, @box.height)
      assert_equal(1, @box.instance_variable_get(:@items).length)
    end

    it "allows using a hash with :text key instead of a simple string" do
      @composer.formatted_text([{text: "Test"}])
      items = @box.instance_variable_get(:@items)
      assert_equal(4, items[0].items.length)
    end

    it "uses an empty string if the :text key for a hash is not specified" do
      @composer.formatted_text([{font_size: "Test"}])
      items = @box.instance_variable_get(:@items)
      assert_equal(0, items[0].items.length)
    end

    it "allows setting a custom base style for all parts" do
      @composer.formatted_text(["Test", "other"], font_size: 20)
      items = @box.instance_variable_get(:@items)
      assert_equal(20, @box.style.font_size)
      assert_equal(20, items[0].style.font_size)
      assert_equal(20, items[1].style.font_size)
    end

    it "allows using custom style properties for a single part" do
      @composer.formatted_text([{text: "Test", font_size: 20}, "test"], align: :center)
      items = @box.instance_variable_get(:@items)
      assert_equal(10, @box.style.font_size)

      assert_equal(20, items[0].style.font_size)
      assert_equal(:center, items[0].style.align)

      assert_equal(10, items[1].style.font_size)
      assert_equal(:center, items[1].style.align)
    end

    it "allows using a custom style as basis for a single part" do
      @composer.formatted_text([{text: "Test", style: {font_size: 20}, subscript: true}, "test"],
                               align: :center)
      items = @box.instance_variable_get(:@items)
      assert_equal(10, @box.style.font_size)

      assert_equal(20, items[0].style.font_size)
      assert_equal(:left, items[0].style.align)
      assert(items[0].style.subscript)

      assert_equal(10, items[1].style.font_size)
      assert_equal(:center, items[1].style.align)
      refute(items[1].style.subscript)
    end

    it "allows specifying a link to an URL via the :link key" do
      @composer.formatted_text([{text: "Test", link: "URI"}, {link: "URI"}, "test"])
      items = @box.instance_variable_get(:@items)
      assert_equal(3, items.length)
      assert_equal(4, items[0].items.length, "text should be Test")
      assert_equal(3, items[1].items.length, "text should be URI")
      assert_equal([:link, {uri: 'URI'}], items[0].style.overlays.instance_variable_get(:@layers)[0])
      refute(items[2].style.overlays?)
    end
  end

  describe "image" do
    it "creates an image box and draws it on the canvas" do
      box = nil
      @composer.define_singleton_method(:draw_box) {|arg| box = arg }
      image_path = File.join(TEST_DATA_DIR, 'images', 'gray.jpg')

      @composer.image(image_path, width: 10, height: 15, style: {font_size: 20}, subscript: true)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal(20, box.style.font_size)
      assert(box.style.subscript)
      assert_same(@composer.document.images.add(image_path), box.image)
    end

    it "allows using a form XObject" do
      form = @composer.document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, 10, 10]})
      @composer.image(form, width: 10)
      assert_equal(796, @composer.y)
      assert_equal(36, @composer.x)
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
