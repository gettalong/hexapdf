# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/color'

module CommonColorSpaceTests

  def test_color_object_returns_correct_color_space
    assert_equal(@color_space, @color.color_space)
  end

  def test_color_space_responds_to_default_color
    assert(@color_space.respond_to?(:default_color))
    assert_equal(0, @color_space.method(:default_color).arity)
  end

  def test_color_space_responds_to_color
    assert(@color_space.respond_to?(:color))
  end

  def test_color_responds_to_components
    assert(@color.respond_to?(:components))
  end

  def test_color_responds_to_color_space
    assert(@color.respond_to?(:color_space))
  end

  def test_colors_are_comparable
    refute_equal(@color, @other_color)
  end

end

describe HexaPDF::PDF::Content::UniversalColorSpace do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::UniversalColorSpace
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 5, 6, 7, 8)
  end
end

describe HexaPDF::PDF::Content::DeviceRGBColorSpace do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::DeviceRGBColorSpace
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0)
  end
end

describe HexaPDF::PDF::Content::DeviceCMYKColorSpace do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::DeviceCMYKColorSpace
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0, 128)
  end
end

describe HexaPDF::PDF::Content::DeviceGrayColorSpace do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::DeviceGrayColorSpace
    @color = @color_space.default_color
    @other_color = @color_space.color(128)
  end
end
