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

  describe "::media_box" do
    it "returns the media box for a given paper size" do
      assert_equal([0, 0, 595, 842], HexaPDF::Type::Page.media_box(:A4))
    end

    it "respects the orientation key" do
      assert_equal([0, 0, 842, 595], HexaPDF::Type::Page.media_box(:A4, orientation: :landscape))
    end

    it "fails if the paper size is unknown" do
      assert_raises(HexaPDF::Error) { HexaPDF::Type::Page.media_box(:Unknown) }
    end
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
      refute(page.validate {|m, _| message = m })
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
      @page[:MediaBox] = :media
      assert_equal(:media, @page.box(:bleed))
      assert_equal(:media, @page.box(:trim))
      assert_equal(:media, @page.box(:art))
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

    it "sets the correct box" do
      @page.box(:media, :media)
      assert_equal(:media, @page.box(:media))
      @page.box(:crop, :crop)
      assert_equal(:crop, @page.box(:crop))
      @page.box(:bleed, :bleed)
      assert_equal(:bleed, @page.box(:bleed))
      @page.box(:trim, :trim)
      assert_equal(:trim, @page.box(:trim))
      @page.box(:art, :art)
      assert_equal(:art, @page.box(:art))
    end

    it "fails if an unknown box type is supplied when setting a box" do
      assert_raises(ArgumentError) { @page.box(:undefined, [1, 2, 3, 4]) }
    end
  end

  describe "orientation" do
    before do
      @page = @doc.pages.add
    end

    it "returns :portrait for appropriate media boxes and rotation values" do
      @page.box(:media, [0, 0, 100, 300])
      assert_equal(:portrait, @page.orientation)
      @page[:Rotate] = 0
      assert_equal(:portrait, @page.orientation)
      @page[:Rotate] = 180
      assert_equal(:portrait, @page.orientation)

      @page.box(:media, [0, 0, 300, 100])
      @page[:Rotate] = 90
      assert_equal(:portrait, @page.orientation)
      @page[:Rotate] = 270
      assert_equal(:portrait, @page.orientation)
    end

    it "returns :landscape for appropriate media boxes and rotation values" do
      @page.box(:media, [0, 0, 300, 100])
      assert_equal(:landscape, @page.orientation)
      @page[:Rotate] = 0
      assert_equal(:landscape, @page.orientation)
      @page[:Rotate] = 180
      assert_equal(:landscape, @page.orientation)

      @page.box(:media, [0, 0, 100, 300])
      @page[:Rotate] = 90
      assert_equal(:landscape, @page.orientation)
      @page[:Rotate] = 270
      assert_equal(:landscape, @page.orientation)
    end
  end

  describe "rotate" do
    before do
      @page = @doc.pages.add
      reset_media_box
    end

    def reset_media_box
      @page.box(:media, [50, 100, 200, 300])
    end

    it "works directly on the :Rotate key" do
      @page.rotate(90)
      assert_equal(270, @page[:Rotate])

      @page.rotate(180)
      assert_equal(90, @page[:Rotate])

      @page.rotate(-90)
      assert_equal(180, @page[:Rotate])
    end

    describe "flatten" do
      it "adjust all page boxes" do
        @page.box(:crop, @page.box)
        @page.box(:bleed, @page.box)
        @page.box(:trim, @page.box)
        @page.box(:art, @page.box)

        @page.rotate(90, flatten: true)
        box = [-300, 50, -100, 200]
        assert_equal(box, @page.box(:media).value)
        assert_equal(box, @page.box(:crop).value)
        assert_equal(box, @page.box(:bleed).value)
        assert_equal(box, @page.box(:trim).value)
        assert_equal(box, @page.box(:art).value)
      end

      it "works correctly for 90 degrees" do
        @page.rotate(90, flatten: true)
        assert_equal([-300, 50, -100, 200], @page.box(:media).value)
        assert_equal(" q 0 1 -1 0 0 0 cm   Q ", @page.contents)
      end

      it "works correctly for 180 degrees" do
        @page.rotate(180, flatten: true)
        assert_equal([-200, -300, -50, -100], @page.box(:media).value)
        assert_equal(" q -1 0 0 -1 0 0 cm   Q ", @page.contents)
      end

      it "works correctly for 270 degrees" do
        @page.rotate(270, flatten: true)
        assert_equal([100, -200, 300, -50], @page.box(:media).value)
        assert_equal(" q 0 -1 1 0 0 0 cm   Q ", @page.contents)
      end
    end

    it "fails if the angle is not a multiple of 90" do
      assert_raises(ArgumentError) { @page.rotate(27) }
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
