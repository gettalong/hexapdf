# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/rectangle'
require 'hexapdf/document'

describe HexaPDF::Rectangle do
  describe "after_data_change" do
    it "fails if the rectangle doesn't contain four numbers" do
      assert_raises(ArgumentError) { HexaPDF::Rectangle.new([1, 2, 3]) }
      assert_raises(ArgumentError) { HexaPDF::Rectangle.new([1, 2, 3, :a]) }
    end

    it "normalizes the array values" do
      rect = HexaPDF::Rectangle.new([0, 1, 2, 3])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::Rectangle.new([2, 3, 0, 1])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::Rectangle.new([0, 3, 2, 1])
      assert_equal([0, 1, 2, 3], rect.value)

      rect = HexaPDF::Rectangle.new([2, 1, 0, 3])
      assert_equal([0, 1, 2, 3], rect.value)
    end
  end

  it "returns individual fields of the rectangle" do
    rect = HexaPDF::Rectangle.new([2, 1, 0, 5])
    assert_equal(0, rect.left)
    assert_equal(2, rect.right)
    assert_equal(1, rect.bottom)
    assert_equal(5, rect.top)
    assert_equal(2, rect.width)
    assert_equal(4, rect.height)
  end

  it "allows setting all fields of the rectangle" do
    rect = HexaPDF::Rectangle.new([2, 1, 0, 5])
    rect.left = 5
    rect.right = 1
    rect.bottom = 2
    rect.top = 3
    assert_equal([5, 2, 1, 3], rect.value)

    rect.width = 10
    assert_equal(15, rect.right)
    rect.height = 10
    assert_equal(12, rect.top)
  end

  it "allows comparison to arrays" do
    rect = HexaPDF::Rectangle.new([0, 1, 2, 5])
    assert(rect == [0, 1, 2, 5])
    rect.oid = 5
    refute(rect == [0, 1, 2, 5])
  end

  describe "validation" do
    it "ensures that it is a correct PDF rectangle" do
      doc = HexaPDF::Document.new
      rect = HexaPDF::Rectangle.new([0, 1, 2, 3], document: doc)
      assert(rect.validate)

      rect.value.shift
      refute(rect.validate)

      rect.value.unshift(:A)
      refute(rect.validate)
    end
  end
end
