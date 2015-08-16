# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/type/form'

describe HexaPDF::PDF::Type::Form do
  before do
    @doc = HexaPDF::PDF::Document.new
    @form = @doc.wrap({}, subtype: :Form)
  end

  describe "box" do
    it "returns the /BBox entry" do
      @form[:BBox] = :media
      assert_equal(:media, @form.box)
    end
  end

  describe "resources" do
    it "creates the resource dictionary if it is not found" do
      resources = @form.resources
      assert_kind_of(HexaPDF::PDF::Type::Resources, resources)
      assert_equal({}, resources.value)
    end

    it "returns the already used resource dictionary" do
      @form[:Resources] = {Font: nil}
      resources = @form.resources
      assert_kind_of(HexaPDF::PDF::Type::Resources, resources)
      assert_equal(@form[:Resources], resources)
    end
  end
end
