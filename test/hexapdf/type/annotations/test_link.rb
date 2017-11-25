# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotations/link'

describe HexaPDF::Type::Annotations::Link do
  before do
    @doc = HexaPDF::Document.new
    @annot = HexaPDF::Type::Annotations::Link.new({Rect: [0, 0, 1, 1]}, document: @doc)
  end

  describe "validation" do
    it "checks for valid /H value" do
      @annot[:H] = :invalid
      refute(@annot.validate {|msg| assert_match(/contains invalid value/, msg) })
    end
  end
end
