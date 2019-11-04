# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotations/widget'

describe HexaPDF::Type::Annotations::Widget::AppearanceCharacteristics do
  before do
    @doc = HexaPDF::Document.new
    @annot = @doc.wrap({}, type: :XXAppearanceCharacteristics)
  end

  describe "validation" do
    it "needs /R to be a multiple of 90" do
      assert(@annot.validate)

      @annot[:R] = 45
      refute(@annot.validate)

      @annot[:R] = 90
      assert(@annot.validate)
    end
  end
end
