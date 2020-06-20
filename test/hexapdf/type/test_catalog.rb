# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/catalog'

describe HexaPDF::Type::Catalog do
  before do
    @doc = HexaPDF::Document.new
    @catalog = @doc.add({Type: :Catalog})
  end

  it "must always be indirect" do
    @catalog.must_be_indirect = false
    assert(@catalog.must_be_indirect?)
  end

  it "creates the page tree on access" do
    assert_nil(@catalog[:Pages])
    pages = @catalog.pages
    assert_equal(:Pages, pages.type)
  end

  describe "acro_form" do
    it "returns an existing form object" do
      @catalog[:AcroForm] = :test
      assert_equal(:test, @catalog.acro_form)
    end

    it "returns an existing form object even if create: true" do
      @catalog[:AcroForm] = :test
      assert_equal(:test, @catalog.acro_form(create: true))
    end

    it "creates a new AcroForm object with defaults if create: true" do
      form = @catalog.acro_form(create: true)
      assert_kind_of(HexaPDF::Type::AcroForm::Form, form)
      assert(form[:DA])
    end
  end

  describe "validation" do
    it "creates the page tree if necessary" do
      refute(@catalog.validate(auto_correct: false))
      assert(@catalog.validate)
    end
  end
end
