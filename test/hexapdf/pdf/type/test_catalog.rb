# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/type/catalog'

describe HexaPDF::PDF::Type::Catalog do

  describe "validation" do
    it "creates the page tree if necessary" do
      doc = HexaPDF::PDF::Document.new
      catalog = doc.add(Type: :Catalog)
      refute(catalog.validate(auto_correct: false))
      assert(catalog.validate)
    end
  end

end
