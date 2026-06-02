# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotations/ink'

describe HexaPDF::Type::Annotations::Ink do
  before do
    @doc = HexaPDF::Document.new
    @annot = @doc.add({Type: :Annot, Subtype: :Ink, Rect: [0, 0, 0, 0]})
  end

  it "returns the paths" do
    assert_equal([], @annot.paths)
    @annot[:InkList] = [[10, 20, 30, 40], [50, 60, 70, 80]]
    assert_equal([[10, 20, 30, 40], [50, 60, 70, 80]], @annot.paths)
  end

  describe "add_paths" do
    it "adds the given path" do
      assert_same(@annot, @annot.add_path(1, 2, 3, 4, 5, 6))
      assert_equal([[1, 2, 3, 4, 5, 6]], @annot[:InkList])
      @annot.add_path(7, 8, 9, 10)
      assert_equal([[1, 2, 3, 4, 5, 6], [7, 8, 9, 10]], @annot[:InkList])
    end

    it "raises an ArgumentError if an uneven number of arguments is provided" do
      assert_raises(ArgumentError) { @annot.add_path(1, 2, 3) }
    end
  end
end
