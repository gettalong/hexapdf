# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Layout do
  before do
    @doc = HexaPDF::Document.new
    @layout = @doc.layout
  end

  describe "style" do
    it "creates a new style if it does not exist based on the base argument" do
      @layout.style(:base, font_size: 20)
      assert_equal(20, @layout.style(:newstyle, subscript: true).font_size)
      refute(@layout.style(:base).subscript)
      assert_equal(10, @layout.style(:another_new, base: nil).font_size)
      assert(@layout.style(:yet_another_new, base: :newstyle).subscript)
    end

    it "returns the named style" do
      assert_kind_of(HexaPDF::Layout::Style, @layout.style(:base))
    end

    it "updates the style with the given properties" do
      assert_equal(20, @layout.style(:base, font_size: 20).font_size)
    end
  end

  describe "text_box" do
    it "creates a text box" do
      box = @layout.text_box("Test", width: 10, height: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_same(@doc.fonts.add("Times"), box.style.font)
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.length)
      assert_same(box.style, items.first.style)
    end

    it "allows setting of a custom style" do
      style = HexaPDF::Layout::Style.new(font_size: 20, font: ['Times', {variant: :bold}])
      box = @layout.text_box("Test", style: style)
      assert_same(box.style, style)
      assert_same(@doc.fonts.add("Times", variant: :bold), box.style.font)
      assert_equal(20, box.style.font_size)

      box = @layout.text_box("Test", style: {font_size: 20})
      assert_equal(20, box.style.font_size)

      @layout.style(:named, font_size: 20)
      box = @layout.text_box("Test", style: :named)
      assert_equal(20, box.style.font_size)
    end

    it "updates the used style with the provided options" do
      box = @layout.text_box("Test", style: {subscript: true}, font_size: 20)
      assert_equal(20, box.style.font_size)
    end

    it "allows using a box style different from the text style" do
      style = HexaPDF::Layout::Style.new(font_size: 20)
      box = @layout.text_box("Test", box_style: style)
      refute_same(box.instance_variable_get(:@items).first.style, style)
      assert_same(box.style, style)

      @layout.style(:named, font_size: 20)
      box = @layout.text_box("Test", box_style: :named)
      assert_equal(20, box.style.font_size)
    end
  end

  describe "formatted_text" do
    it "creates a text box with the given text" do
      box = @layout.formatted_text_box(["Test"], width: 10, height: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal(1, box.instance_variable_get(:@items).length)
    end

    it "allows using a hash with :text key instead of a simple string" do
      box = @layout.formatted_text_box([{text: "Test"}])
      items = box.instance_variable_get(:@items)
      assert_equal(4, items[0].items.length)
    end

    it "uses an empty string if the :text key for a hash is not specified" do
      box = @layout.formatted_text_box([{font_size: "Test"}])
      items = box.instance_variable_get(:@items)
      assert_equal(0, items[0].items.length)
    end

    it "allows setting a custom base style for all parts" do
      box = @layout.formatted_text_box(["Test", "other"], font_size: 20)
      items = box.instance_variable_get(:@items)
      assert_equal(20, box.style.font_size)
      assert_equal(20, items[0].style.font_size)
      assert_equal(20, items[1].style.font_size)
    end

    it "allows using custom style properties for a single part" do
      box = @layout.formatted_text_box([{text: "Test", font_size: 20}, "test"], align: :center)
      items = box.instance_variable_get(:@items)
      assert_equal(10, box.style.font_size)

      assert_equal(20, items[0].style.font_size)
      assert_equal(:center, items[0].style.align)

      assert_equal(10, items[1].style.font_size)
      assert_equal(:center, items[1].style.align)
    end

    it "allows using a custom style as basis for a single part" do
      box = @layout.formatted_text_box([{text: "Test", style: {font_size: 20}, subscript: true},
                                        "test"], align: :center)
      items = box.instance_variable_get(:@items)
      assert_equal(10, box.style.font_size)

      assert_equal(20, items[0].style.font_size)
      assert_equal(:left, items[0].style.align)
      assert(items[0].style.subscript)

      assert_equal(10, items[1].style.font_size)
      assert_equal(:center, items[1].style.align)
      refute(items[1].style.subscript)
    end

    it "allows specifying a link to an URL via the :link key" do
      box = @layout.formatted_text_box([{text: "Test", link: "URI"}, {link: "URI"}, "test"])
      items = box.instance_variable_get(:@items)
      assert_equal(3, items.length)
      assert_equal(4, items[0].items.length, "text should be Test")
      assert_equal(3, items[1].items.length, "text should be URI")
      assert_equal([:link, {uri: 'URI'}], items[0].style.overlays.instance_variable_get(:@layers)[0])
      refute(items[2].style.overlays?)
    end
  end

  describe "image_box" do
    it "creates an image box" do
      image_path = File.join(TEST_DATA_DIR, 'images', 'gray.jpg')

      box = @layout.image_box(image_path, width: 10, height: 15, style: {font_size: 20}, subscript: true)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal(20, box.style.font_size)
      assert(box.style.subscript)
      assert_same(@doc.images.add(image_path), box.image)
    end

    it "allows using a form XObject" do
      form = @doc.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, 10, 10]})
      box = @layout.image_box(form, width: 10)
      assert_equal(10, box.width)
      assert_same(form, box.image)
    end
  end
end
