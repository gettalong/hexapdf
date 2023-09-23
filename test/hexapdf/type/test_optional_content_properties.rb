# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/type/optional_content_properties'
require 'hexapdf/document'

describe HexaPDF::Type::OptionalContentProperties do
  before do
    @doc = HexaPDF::Document.new
    @oc = @doc.optional_content
  end

  describe "add_ocg" do
    it "adds a given OCG object" do
      ocg = @doc.add({Type: :OCG, Name: 'test'})
      assert_same(ocg, @oc.add_ocg(ocg))
      assert_equal([ocg], @oc[:OCGs])
    end

    it "creates a new OCG object with the given name and adds it" do
      ocg = @oc.add_ocg('Test')
      assert_equal([ocg], @oc[:OCGs])
    end
  end

  describe "ocg" do
    it "returns the first OCG with the given name, regardless of the create argument" do
      ocg1  = @oc.add_ocg('Test')
      _ocg2 = @oc.add_ocg('Test')
      assert_same(ocg1, @oc.ocg('Test', create: false))
      assert_same(ocg1, @oc.ocg('Test', create: true))
    end

    it "returns nil if no OCG with the given name exists and create is false" do
      assert_nil(@oc.ocg('Other', create: false))
      @oc.add_ocg('Test')
      assert_nil(@oc.ocg('Other', create: false))
    end

    it "creates an OCG with the given name if none is found and create is true" do
      ocg = @oc.ocg('Test')
      assert_same(ocg, @oc.ocg('Test'))
      assert_equal([ocg], @oc[:OCGs])
    end
  end

  describe "ocgs" do
    it "returns the list of the known optional content groups, with duplicates removed" do
      ocg1 = @oc.add_ocg(@oc.add_ocg('Test'))
      @oc[:OCGs] << nil
      ocg2 = @oc.add_ocg('Test')
      ocg3 = @oc.add_ocg('Other')
      assert_equal([ocg1, ocg2, ocg3], @oc.ocgs)
    end
  end

  describe "perform_validation" do
    it "creates the /D entry if it is not set" do
      @oc.delete(:D)
      refute(@oc.validate(auto_correct: false))
      refute(@oc.key?(:D))
      assert(@oc.validate(auto_correct: true))
      assert_equal({Creator: 'HexaPDF'}, @oc[:D].value)
    end
  end
end
