# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/color_space'

module CommonColorSpaceTests
  extend Minitest::Spec::DSL

  it "the color object returns the correct color space" do
    assert_equal(@color_space, @color.color_space)
  end

  it "the color space responds to :default_color" do
    assert(@color_space.respond_to?(:default_color))
    assert_equal(0, @color_space.method(:default_color).arity)
  end

  it "the color space responds to :color" do
    assert(@color_space.respond_to?(:color))
  end

  it "the color responds to :components" do
    assert(@color.respond_to?(:components))
  end

  it "the color responds to :color_space" do
    assert(@color.respond_to?(:color_space))
  end

  it "the colors are comparable" do
    refute_equal(@color, @other_color)
  end

  it "the components are returned in the correct order" do
    assert_equal(@components, @color_space.color(*@components).components)
  end

end

describe HexaPDF::PDF::Content::ColorSpace::Universal do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::ColorSpace::Universal.new
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 5, 6, 7, 8)
    @components = [5, 6, 7, 8]
  end
end

describe HexaPDF::PDF::Content::ColorSpace::DeviceRGB do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::ColorSpace::DeviceRGB.new
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0)
    @components = [0.5, 0.2, 0.3]
  end
end

describe HexaPDF::PDF::Content::ColorSpace::DeviceCMYK do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::ColorSpace::DeviceCMYK.new
    @color = @color_space.default_color
    @other_color = @color_space.color(128, 0, 0, 128)
    @components = [0.1, 0.2, 0.3, 0.4]
  end
end

describe HexaPDF::PDF::Content::ColorSpace::DeviceGray do
  include CommonColorSpaceTests

  before do
    @color_space = HexaPDF::PDF::Content::ColorSpace::DeviceGray.new
    @color = @color_space.default_color
    @other_color = @color_space.color(128)
    @components = [0.1]
  end
end
