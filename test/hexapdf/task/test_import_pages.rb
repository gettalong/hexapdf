# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/task/import_pages'

describe HexaPDF::Task::ImportPages do
  before do
    @doc = HexaPDF::Document.new
    @pages = [@doc.pages.add, @doc.pages.add]
    @pages[0][:Page1] = true
    @pages[1][:Page2] = true

    @target = HexaPDF::Document.new
  end

  describe "pages argument" do
    it "imports all pages by default" do
      @target.task(:import_pages, source: @doc)
      assert_equal(2, @target.pages.count)
      assert(@target.pages[0][:Page1])
      assert(@target.pages[1][:Page2])
    end

    it "imports the provided page objects" do
      @target.task(:import_pages, source: @doc, pages: @pages.reverse)
      assert_equal(2, @target.pages.count)
      assert(@target.pages[0][:Page2])
      assert(@target.pages[1][:Page1])
    end

    it "imports a single page" do
      @target.task(:import_pages, source: @doc, pages: 1)
      assert_equal(1, @target.pages.count)
      assert(@target.pages[0][:Page2])
    end

    it "imports a page range" do
      @target.task(:import_pages, source: @doc, pages: 0..-1)
      assert_equal(2, @target.pages.count)
      assert(@target.pages[0][:Page1])
      assert(@target.pages[1][:Page2])
    end

    it "imports multiple pages" do
      @target.task(:import_pages, source: @doc, pages: [1, 0..-1],
                   ocgs: :ignore, acro_form: :ignore)
      assert_equal(2, @target.pages.count)
      assert(@target.pages[0][:Page2])
      assert(@target.pages[1][:Page1])
    end
  end

  it "doesn't append the pages if specified so" do
    result = @target.task(:import_pages, source: @doc, append: false)
    assert_equal(0, @target.pages.count)
    assert_equal(2, result.size)
    assert(result[0][:Page1])
    assert(result[1][:Page2])
  end

  it "merges the AcroForm fields" do
    form = @doc.acro_form(create: true)
    field = form.create_text_field("Text")
    field.create_widget(@doc.pages[0], Rect: [0, 0, 0, 0])
    @doc.dispatch_message(:complete_objects)
    @doc.validate

    @target.task(:import_pages, source: @doc)
    assert_equal(1, @target.acro_form.root_fields.size)
  end

  describe "ocgs argument" do
    before do
      @ocg1 = @doc.optional_content.ocg('OCG')
      @ocg1.add_to_ui(path: @ocg1)
      @ocg2 = @doc.optional_content.ocg('OCMD')
      @ocg2.add_to_ui(path: @ocg2)
      @ocg2.off!
      @ocmd = @doc.optional_content.create_ocmd(@ocg2)
    end

    it "doesn't preserve unused ocgs" do
      @target.task(:import_pages, source: @doc)
      assert(@target.optional_content.ocgs.empty?)
    end

    it "preserves OCGs and OCMDs in content streams" do
      canvas = @doc.pages[0].canvas
      canvas.optional_content(@ocg1)
      canvas.optional_content(@ocmd)
      @target.task(:import_pages, source: @doc)
      assert_equal(['OCG', 'OCMD'], @target.optional_content.ocgs.map(&:name))
      assert(@target.optional_content.ocg('OCG').on?)
      refute(@target.optional_content.ocg('OCMD').on?)
    end

    it "preserves OCGs/OCMDs associated with XObjects" do
      canvas = @doc.pages[0].canvas
      form = canvas.form
      form[:OC] = @ocg1
      canvas.xobject(form, at: [0, 0])
      @target.task(:import_pages, source: @doc)
      assert_equal(['OCG'], @target.optional_content.ocgs.map(&:name))
    end

    it "preserves OCGs/OCMDs associated with annotations" do
      annot = @doc.annotations.create_line(@doc.pages[0], start_point: [0, 0], end_point: [50, 50])
      annot[:OC] = @ocmd
      annot.regenerate_appearance
      @target.task(:import_pages, source: @doc)
      assert_equal(['OCMD'], @target.optional_content.ocgs.map(&:name))
      refute(@target.optional_content.ocg('OCMD').on?)
    end

    it "preserves the radio button group state of imported OCGs" do
      @doc.pages[0].canvas.optional_content(@ocg1)
      @doc.optional_content.default_configuration[:RBGroups] = [[@ocg1, @ocg2]]
      @target.task(:import_pages, source: @doc)
      assert_equal(['OCG'], @target.optional_content.ocgs.map {|ocg| ocg.name })
      rb_groups = @target.optional_content.default_configuration[:RBGroups]
      assert_equal(1, rb_groups.size)
      assert_equal(['OCG'], rb_groups[0].map(&:name))
    end
  end
end
