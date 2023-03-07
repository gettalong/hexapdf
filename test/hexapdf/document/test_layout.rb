# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Layout::ChildrenCollector do
  before do
    @doc = HexaPDF::Document.new
    @collector = HexaPDF::Document::Layout::ChildrenCollector.new(@doc.layout)
  end

  it "provides a convenient ::collect method which just returns the collected children" do
    children = HexaPDF::Document::Layout::ChildrenCollector.collect(@doc.layout) do |collector|
      collector.lorem_ipsum_box
      collector.lorem_ipsum_box
    end
    assert_equal(2, children.size)
    assert_kind_of(HexaPDF::Layout::TextBox, children[0])
    assert_kind_of(HexaPDF::Layout::TextBox, children[1])
  end

  it "allows appending existing boxes" do
    box = @doc.layout.lorem_ipsum_box
    @collector << box
    assert_equal([box], @collector.children)
  end

  it "allows appending an array of boxes created through another children collector" do
    @collector.multiple do |collector|
      collector.lorem_ipsum_box
      collector.lorem_ipsum_box
    end
    assert_equal(1, @collector.children.size)
    assert_equal(2, @collector.children[0].size)
  end

  it "allows appending boxes created by the Layout class" do
    @collector.lorem_ipsum
    @collector.lorem_ipsum_box
    @collector.column
    @collector.column_box
    assert_equal(4, @collector.children.size)
    assert_kind_of(HexaPDF::Layout::TextBox, @collector.children[0])
    assert_kind_of(HexaPDF::Layout::TextBox, @collector.children[1])
    assert_kind_of(HexaPDF::Layout::ColumnBox, @collector.children[2])
    assert_kind_of(HexaPDF::Layout::ColumnBox, @collector.children[3])
  end

  it "can be asked which methods it supports" do
    assert(@collector.respond_to?(:lorem_ipsum))
  end

  it "only allows using box creation methods from the Layout class" do
    assert_raises(NameError) { @collector.style }
  end

  it "raises an error on an unknown method name" do
    assert_raises(NameError) { @collector.unknown_box }
  end
end

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

  describe "inline_box" do
    it "takes a box as argument" do
      box = HexaPDF::Layout::Box.create(width: 10, height: 10)
      ibox = @layout.inline_box(box)
      assert_same(box, ibox.box)
    end

    it "correctly passes on the valign argument" do
      box = HexaPDF::Layout::Box.create(width: 10, height: 10)
      ibox = @layout.inline_box(box, valign: :top)
      assert_equal(:top, ibox.valign)
    end

    it "can create a box using any box creation method of the Layout class" do
      ibox = @layout.inline_box(:text, "Some text", valign: :bottom, width: 10, background_color: "red")
      assert_equal(:bottom, ibox.valign)
      assert_equal(10, ibox.width)
      assert_equal("red", ibox.box.style.background_color)
    end
  end

  describe "box" do
    it "creates the request box" do
      box = @layout.box(:column, columns: 3, gaps: 20, width: 15, height: 30, style: {font_size: 10},
                        properties: {key: :value})
      assert_equal(15, box.width)
      assert_equal(30, box.height)
      assert_equal([-1, -1, -1], box.columns)
      assert_equal([20], box.gaps)
      assert_equal(10, box.style.font_size)
      assert_equal({key: :value}, box.properties)
    end

    it "allows specifying the box's children via a provided block" do
      box = @layout.box(:column) do |column|
        column.lorem_ipsum
        column.lorem_ipsum
      end
      assert_equal(2, box.children.size)
    end

    it "fails if the name is not registered" do
      assert_raises(HexaPDF::Error) { @layout.box(:unknown) }
    end
  end

  describe "text_box" do
    it "creates a text box" do
      box = @layout.text_box("Test", width: 10, height: 15, properties: {key: :value})
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_same(@doc.fonts.add("Times"), box.style.font)
      items = box.instance_variable_get(:@items)
      assert_equal(1, items.length)
      assert_same(box.style, items.first.style)
      assert_equal({key: :value}, box.properties)
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

    it "allows setting custom properties on the whole box" do
      box = @layout.formatted_text_box(["Test"], properties: {key: :value})
      assert_equal({key: :value}, box.properties)
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

    it "allows setting custom properties" do
      box = @layout.formatted_text_box([{text: 'test', properties: {named_dest: 'test'}}])
      items = box.instance_variable_get(:@items)
      assert_equal({named_dest: 'test'}, items[0].properties)
    end
  end

  describe "image_box" do
    it "creates an image box" do
      image_path = File.join(TEST_DATA_DIR, 'images', 'gray.jpg')

      box = @layout.image_box(image_path, width: 10, height: 15, style: {font_size: 20},
                              properties: {key: :value}, subscript: true)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal(20, box.style.font_size)
      assert(box.style.subscript)
      assert_same(@doc.images.add(image_path), box.image)
      assert_equal({key: :value}, box.properties)
    end

    it "allows using a form XObject" do
      form = @doc.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, 10, 10]})
      box = @layout.image_box(form, width: 10)
      assert_equal(10, box.width)
      assert_same(form, box.image)
    end
  end

  describe "lorem_ipsum_box" do
    it "creates a standard lorem ipsum box" do
      box = @layout.lorem_ipsum_box(width: 10, height: 15, font_size: 15)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      items = box.instance_variable_get(:@items)
      assert_equal(HexaPDF::Document::Layout::LOREM_IPSUM.join(" ").size, items[0].items.length)
    end

    it "can use just some sentences from the lorem ipsum text" do
      box = @layout.lorem_ipsum_box(sentences: 1)
      items = box.instance_variable_get(:@items)
      assert_equal(HexaPDF::Document::Layout::LOREM_IPSUM[0].size, items[0].items.length)
    end

    it "can use multiple of the selected sentences" do
      box = @layout.lorem_ipsum_box(sentences: 2, count: 2)
      items = box.instance_variable_get(:@items)
      assert_equal(HexaPDF::Document::Layout::LOREM_IPSUM[0, 2].join(" ").size * 2 + 2, items[0].items.length)
    end
  end

  describe "method_missing" do
    it "resolves to internal methods with the _box suffix, e.g. text_box" do
      box = @layout.text("Test", width: 10, height: 15, properties: {key: :value})
      assert_kind_of(HexaPDF::Layout::TextBox, box)
      assert_equal(10, box.width)
      assert_equal(15, box.height)
      assert_equal({key: :value}, box.properties)
    end

    it "resolves to the box method when a configured name is used" do
      box = @layout.column
      assert_kind_of(HexaPDF::Layout::ColumnBox, box)
      box = @layout.column_box
      assert_kind_of(HexaPDF::Layout::ColumnBox, box)
    end

    it "fails if nothing could be resolved" do
      assert_raises(NameError) { @layout.unknown }
    end
  end

  describe "respond_to_missing?" do
    it "can be asked which methods it supports" do
      assert(@layout.respond_to?(:text))
      assert(@layout.respond_to?(:column))
      refute(@layout.respond_to?(:unknown))
    end
  end
end
