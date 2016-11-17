# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../content/common'
require 'stringio'
require 'hexapdf/document'
require 'hexapdf/type/page'

describe HexaPDF::Type::Page do
  before do
    @doc = HexaPDF::Document.new
  end

  # Asserts that the page's contents contains the operators.
  def assert_operators(page, operators)
    processor = TestHelper::OperatorRecorder.new
    page.process_contents(processor)
    assert_equal(operators, processor.recorded_ops)
  end

  it "must always be indirect" do
    page = @doc.add(Type: :Page)
    page.must_be_indirect = false
    assert(page.must_be_indirect?)
  end

  describe "[]" do
    before do
      @root = @doc.add(Type: :Pages)
      @kid = @doc.add(Type: :Pages, Parent: @root)
      @page = @doc.add(Type: :Page, Parent: @kid)
    end

    it "works normal for non-inheritable fields" do
      assert_equal(:Page, @page[:Type])
      assert_nil(@page[:Dur])
    end

    it "automatically retrieves inherited values" do
      @root[:MediaBox] = :media
      assert_equal(:media, @page[:MediaBox])

      @root[:Resources] = :root_res
      @kid[:Resources] = :res
      assert_equal(:res, @page[:Resources])

      @page[:CropBox] = :cropbox
      assert_equal(:cropbox, @page[:CropBox])

      @kid[:Rotate] = :kid_rotate
      assert_equal(:kid_rotate, @page[:Rotate])
    end

    it "returns nil or the default value if no value is set anywhere" do
      assert_nil(@page[:MediaBox])
      assert_equal(0, @page[:Rotate])
    end
  end

  describe "validation" do
    it "fails if a required inheritable field is not set" do
      root = @doc.add(Type: :Pages)
      page = @doc.add(Type: :Page, Parent: root)
      message = ''
      refute(page.validate {|m, _| message = m})
      assert_match(/inheritable.*MediaBox/i, message)
    end
  end

  describe "box" do
    before do
      @page = @doc.pages.add
    end

    it "returns the correct media box" do
      @page[:MediaBox] = :media
      assert_equal(:media, @page.box(:media))
    end

    it "returns the correct crop box" do
      @page[:MediaBox] = :media
      assert_equal(:media, @page.box(:crop))
      @page[:CropBox] = :crop
      assert_equal(:crop, @page.box(:crop))
    end

    it "returns the correct bleed, trim and art boxes" do
      @page[:CropBox] = :crop
      assert_equal(:crop, @page.box(:bleed))
      assert_equal(:crop, @page.box(:trim))
      assert_equal(:crop, @page.box(:art))
      @page[:BleedBox] = :bleed
      @page[:TrimBox] = :trim
      @page[:ArtBox] = :art
      assert_equal(:bleed, @page.box(:bleed))
      assert_equal(:trim, @page.box(:trim))
      assert_equal(:art, @page.box(:art))
    end

    it "fails if an unknown box type is supplied" do
      assert_raises(ArgumentError) { @page.box(:undefined) }
    end
  end

  describe "contents" do
    it "returns the contents of a single content stream" do
      page = @doc.pages.add
      page[:Contents] = @doc.wrap({}, stream: 'q 10 w Q')
      assert_equal('q 10 w Q', page.contents)
    end

    it "returns the concatenated contents of multiple content stream" do
      page = @doc.pages.add
      page[:Contents] = [@doc.wrap({}, stream: 'q 10'), @doc.wrap({}, stream: 'w Q')]
      assert_equal('q 10 w Q', page.contents)
    end
  end

  describe "contents=" do
    it "creates a content stream if none already exist" do
      page = @doc.pages.add
      page.contents = 'test'
      assert_equal('test', page[:Contents].stream)
    end

    it "reuses an existing content stream" do
      page = @doc.pages.add
      page[:Contents] = content = @doc.wrap({}, stream: 'q 10 w Q')
      page.contents = 'test'
      assert_equal(content, page[:Contents])
      assert_equal('test', content.stream)
    end

    it "reuses the first content stream and deletes the rest if more than one exist" do
      page = @doc.pages.add
      page[:Contents] = [content = @doc.add({}, stream: 'q 10 w Q'), @doc.add({}, stream: 'q Q')]
      page.contents = 'test'
      assert_equal(content, page[:Contents])
      assert_equal('test', content.stream)
    end
  end

  describe "resources" do
    it "creates the resource dictionary if it is not found" do
      page = @doc.add(Type: :Page, Parent: @doc.pages.root)
      resources = page.resources
      assert_equal(:XXResources, resources.type)
      assert_equal({}, resources.value)
    end

    it "returns the already used resource dictionary" do
      @doc.pages.root[:Resources] = {Font: {F1: nil}}
      page = @doc.pages.add(@doc.add(Type: :Page))
      resources = page.resources
      assert_equal(:XXResources, resources.type)
      assert_equal(@doc.pages.root[:Resources], resources)
    end
  end

  describe "process_contents" do
    it "parses the contents and processes it" do
      page = @doc.pages.add
      page[:Contents] = @doc.wrap({}, stream: 'q 10 w Q')
      assert_operators(page, [[:save_graphics_state], [:set_line_width, [10]],
                              [:restore_graphics_state]])
    end
  end

  describe "index" do
    it "returns the index of the page in the page tree" do
      kid1 = @doc.add(Type: :Pages, Parent: @doc.pages.root, Count: 4)
      @doc.pages.root[:Kids] << kid1

      kid11 = @doc.add(Type: :Pages, Parent: kid1)
      page1 = kid11.add_page
      kid1[:Kids] << kid11
      page2 = kid1.add_page
      kid12 = @doc.add(Type: :Pages, Parent: kid1)
      page3 = kid12.add_page
      page4 = kid12.add_page
      kid1[:Kids] << kid12

      assert_equal(0, page1.index)
      assert_equal(1, page2.index)
      assert_equal(2, page3.index)
      assert_equal(3, page4.index)
    end
  end

  describe "canvas" do
    before do
      @page = @doc.pages.add
    end

    it "works correctly if invoked on an empty page, using type :page in first invocation" do
      @page.canvas.line_width = 10
      assert_operators(@page, [[:set_line_width, [10]]])

      @page.canvas(type: :overlay).line_width = 5
      assert_operators(@page, [[:save_graphics_state], [:restore_graphics_state],
                               [:save_graphics_state], [:set_line_width, [10]],
                               [:restore_graphics_state], [:set_line_width, [5]]])

      @page.canvas(type: :underlay).line_width = 2
      assert_operators(@page, [[:save_graphics_state], [:set_line_width, [2]],
                               [:restore_graphics_state], [:save_graphics_state],
                               [:set_line_width, [10]],
                               [:restore_graphics_state], [:set_line_width, [5]]])
    end

    it "works correctly if invoked on an empty page, using type :underlay in first invocation" do
      @page.canvas(type: :underlay).line_width = 2
      assert_operators(@page, [[:save_graphics_state], [:set_line_width, [2]],
                               [:restore_graphics_state], [:save_graphics_state],
                               [:restore_graphics_state]])

      @page.canvas.line_width = 10
      assert_operators(@page, [[:save_graphics_state], [:set_line_width, [2]],
                               [:restore_graphics_state], [:save_graphics_state],
                               [:set_line_width, [10]], [:restore_graphics_state]])

      @page.canvas(type: :overlay).line_width = 5
      assert_operators(@page, [[:save_graphics_state], [:set_line_width, [2]],
                               [:restore_graphics_state], [:save_graphics_state],
                               [:set_line_width, [10]],
                               [:restore_graphics_state], [:set_line_width, [5]]])
    end

    it "works correctly if invoked on a page with existing contents" do
      @page.contents = "10 w"

      @page.canvas(type: :overlay).line_width = 5
      assert_operators(@page, [[:save_graphics_state], [:restore_graphics_state],
                               [:save_graphics_state], [:set_line_width, [10]],
                               [:restore_graphics_state], [:set_line_width, [5]]])

      @page.canvas(type: :underlay).line_width = 2
      assert_operators(@page, [[:save_graphics_state], [:set_line_width, [2]],
                               [:restore_graphics_state], [:save_graphics_state],
                               [:set_line_width, [10]],
                               [:restore_graphics_state], [:set_line_width, [5]]])
    end

    it "fails if the page canvas is requested for a page with existing contents" do
      @page.contents = "q Q"
      assert_raises(HexaPDF::Error) { @page.canvas }
    end

    it "fails if called with an incorrect type argument" do
      assert_raises(ArgumentError) { @page.canvas(type: :something) }
    end
  end

  describe "to_form_xobject" do
    it "creates an independent form xobject" do
      page = @doc.pages.add
      page.contents = "test"
      form = page.to_form_xobject
      refute(form.indirect?)
      assert_equal(form.box.value, page.box.value)
    end

    it "works for pages without content" do
      page = @doc.pages.add
      form = page.to_form_xobject
      assert_equal('', form.stream)
    end

    it "uses the raw stream data if possible to avoid unnecessary work" do
      page = @doc.pages.add
      page.contents = HexaPDF::StreamData.new(StringIO.new("test"))
      form = page.to_form_xobject
      assert_same(form.raw_stream, page[:Contents].raw_stream)

      form = page.to_form_xobject(reference: false)
      refute_same(form.raw_stream, page[:Contents].raw_stream)
    end
  end
end
