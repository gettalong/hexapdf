# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/document'
require 'hexapdf/type/page'

describe HexaPDF::Type::Page do
  before do
    @doc = HexaPDF::Document.new
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
      @kid.delete(:Rotate)
      assert_equal(0, @page[:Rotate])
    end

    it "fails if no parent node is associated" do
      page = @doc.add(Type: :Page)
      assert_raises(HexaPDF::Error) { page[:Resources] }
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
      @page = @doc.pages.add_page
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
      page = @doc.pages.add_page
      page[:Contents] = @doc.wrap({}, stream: 'q 10 w Q')
      assert_equal('q 10 w Q', page.contents)
    end

    it "returns the concatenated contents of multiple content stream" do
      page = @doc.pages.add_page
      page[:Contents] = [@doc.wrap({}, stream: 'q 10'), @doc.wrap({}, stream: 'w Q')]
      assert_equal('q 10 w Q', page.contents)
    end
  end

  describe "contents=" do
    it "creates a content stream if none already exist" do
      page = @doc.pages.add_page
      page.contents = 'test'
      assert_equal('test', page[:Contents].stream)
    end

    it "reuses an existing content stream" do
      page = @doc.pages.add_page
      page[:Contents] = content = @doc.wrap({}, stream: 'q 10 w Q')
      page.contents = 'test'
      assert_equal(content, page[:Contents])
      assert_equal('test', content.stream)
    end

    it "reuses the first content stream and deletes the rest if more than one exist" do
      page = @doc.pages.add_page
      page[:Contents] = [content = @doc.add({}, stream: 'q 10 w Q'), @doc.add({}, stream: 'q Q')]
      page.contents = 'test'
      assert_equal(content, page[:Contents])
      assert_equal('test', content.stream)
    end
  end

  describe "resources" do
    it "creates the resource dictionary if it is not found" do
      page = @doc.add(Type: :Page, Parent: @doc.pages)
      resources = page.resources
      assert_kind_of(HexaPDF::Type::Resources, resources)
      assert_equal({}, resources.value)
    end

    it "returns the already used resource dictionary" do
      @doc.pages[:Resources] = {Font: {F1: nil}}
      page = @doc.pages.add_page(@doc.add(Type: :Page))
      resources = page.resources
      assert_kind_of(HexaPDF::Type::Resources, resources)
      assert_equal(@doc.pages[:Resources], resources)
    end
  end

  describe "process_contents" do
    it "parses the contents and processes it" do
      page = @doc.pages.add_page
      page[:Contents] = @doc.wrap({}, stream: 'q 10 w Q')
      renderer = TestHelper::OperatorRecorder.new
      page.process_contents(renderer) {|processor| processor.operators.clear}
      assert_equal([[:save_graphics_state], [:set_line_width, [10]], [:restore_graphics_state]],
                   renderer.operators)
    end
  end

  describe "to_form_xobject" do
    it "creates an independent form xobject" do
      page = @doc.pages.add_page
      page.contents = "test"
      form = page.to_form_xobject
      refute(form.indirect?)
      assert_equal(form.box.value, page.box.value)
    end

    it "works for pages without content" do
      page = @doc.pages.add_page
      form = page.to_form_xobject
      assert_equal('', form.stream)
    end

    it "uses the raw stream data if possible to avoid unnecessary work" do
      page = @doc.pages.add_page
      page.contents = HexaPDF::StreamData.new(StringIO.new("test"))
      form = page.to_form_xobject
      assert_same(form.raw_stream, page[:Contents].raw_stream)
    end
  end
end
