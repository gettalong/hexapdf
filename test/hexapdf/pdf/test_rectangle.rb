# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/rectangle'

describe HexaPDF::PDF::Rectangle do
  describe "after_data_change" do
    it "fails if the value is not a array" do
      assert_raises(HexaPDF::Error) { HexaPDF::PDF::Rectangle.new(:Name) }
    end

    it "normalizes the array values" do
      rect = HexaPDF::PDF::Rectangle.new([0, 1, 2, 3])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::PDF::Rectangle.new([2, 3, 0, 1])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::PDF::Rectangle.new([0, 3, 2, 1])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::PDF::Rectangle.new([2, 1, 0, 3])
      assert_equal([0, 1, 2, 3], rect.value)
    end
  end

  it "returns individual fields of the rectangle" do
    rect = HexaPDF::PDF::Rectangle.new([2, 1, 0, 5])
    assert_equal(0, rect.left)
    assert_equal(2, rect.right)
    assert_equal(1, rect.bottom)
    assert_equal(5, rect.top)
    assert_equal(2, rect.width)
    assert_equal(4, rect.height)
  end

  it "returns the height of the rectangle" do
  end
end
