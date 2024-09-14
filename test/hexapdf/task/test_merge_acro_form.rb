# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/task/merge_acro_form'

describe HexaPDF::Task::MergeAcroForm do
  before do
    @doc = HexaPDF::Document.new
    @doc.pages.add
    @doc.pages.add
    form = @doc.acro_form(create: true)
    field = form.create_text_field("Text")
    field.create_widget(@doc.pages[0], Rect: [0, 0, 0, 0])
    field.create_widget(@doc.pages[1], Rect: [0, 0, 0, 0])

    form.create_text_field("Calc.Field a")
    form.create_text_field("Calc.Field b")
    field = form.create_text_field('Other.Calculation 1')
    field.set_calculate_action(:sum, fields: ["Calc.Field a", "Calc.Field b"])
    field.create_widget(@doc.pages[1])
    field = form.create_text_field('Other.Calculation 2')
    field.set_calculate_action(:sfn, fields: "Calc.Field\\ a + Calc.Field\\ b")
    field.create_widget(@doc.pages[1])

    @root_fields = @doc.acro_form.root_fields

    @doc.dispatch_message(:complete_objects)
    @doc.validate
    @doc1 = @doc.duplicate
    @pages = []
    @pages << @doc.pages.add(@doc.import(@doc1.pages[0]))
    @pages << @doc.pages.add(@doc.import(@doc1.pages[1]))
  end

  it "selects a unique name for the root field" do
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    assert_equal('merged_1', @root_fields[3][:T])

    @root_fields << @doc.wrap({T: 'merged_23'})
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    assert_equal('merged_24', @root_fields[5][:T])
  end

  it "merges the /DR entry of the main AcroForm dictionary" do
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    assert(@doc.acro_form.default_resources[:Font].key?(:F2))
  end

  it "merges only the fields references in the given pages" do
    @doc.task(:merge_acro_form, source: @doc1, pages: [@pages[0]])
    assert_equal('merged_1', @root_fields[3][:T])
    assert_equal(1, @root_fields[3][:Kids].size)
  end

  it "only merges fields that have at least one widget" do
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    assert_equal(2, @root_fields[3][:Kids].size)
    assert_nil(@doc.acro_form.field_by_name('merged_1.Calc'))
  end

  it "updates the /DA entries of widgets and fields" do
    @pages[0][:Annots][0][:DA] = '/F1 10 Tf'
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    field = @doc.acro_form.field_by_name('merged_1.Text')
    assert_equal('0.0 g /F2 0 Tf', field[:DA])
    assert_equal('/F2 10 Tf', field.each_widget.to_a[0][:DA])
  end

  it "doesn't update the calculation actions if no field with one is merged" do
    @doc.task(:merge_acro_form, source: @doc1, pages: [@pages[0]])
    assert_equal(2, @doc.acro_form[:CO].size)
  end

  it "updates the field names in known calculation actions" do
    @doc.task(:merge_acro_form, source: @doc1, pages: @pages)
    assert_equal(4, @doc.acro_form[:CO].size)
    js = @doc.acro_form.field_by_name('merged_1.Other.Calculation 1')[:AA][:C][:JS]
    assert_match(/merged_1.Calc.Field a/, js)
    js = @doc.acro_form.field_by_name('merged_1.Other.Calculation 2')[:AA][:C][:JS]
    assert_match(/merged_1.Calc.Field a/, js)
  end
end
