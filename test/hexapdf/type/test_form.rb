# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/form'

describe HexaPDF::Type::Form do
  before do
    @doc = HexaPDF::Document.new
    @form = @doc.wrap({}, subtype: :Form)
  end

  describe "box" do
    it "returns the /BBox entry" do
      @form[:BBox] = :media
      assert_equal(:media, @form.box)
    end
  end

  describe "contents" do
    it "just returns the stream" do
      @form.stream = 'test'
      assert_equal(@form.stream, @form.contents)
    end
  end

  describe "contents" do
    it "set the stream contents" do
      @form.contents = 'test'
      assert_equal('test', @form.stream)
    end
  end

  describe "resources" do
    it "creates the resource dictionary if it is not found" do
      resources = @form.resources
      assert_kind_of(HexaPDF::Type::Resources, resources)
      assert_equal({}, resources.value)
    end

    it "returns the already used resource dictionary" do
      @form[:Resources] = {Font: nil}
      resources = @form.resources
      assert_kind_of(HexaPDF::Type::Resources, resources)
      assert_equal(@form[:Resources], resources)
    end
  end
end
