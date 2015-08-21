# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/resources'
require 'hexapdf/pdf/document'

describe HexaPDF::PDF::Type::Resources do
  before do
    @doc = HexaPDF::PDF::Document.new
    @res = HexaPDF::PDF::Type::Resources.new({}, document: @doc)
  end

  describe "color_space" do
    it "works for device color spaces" do
      assert_equal(HexaPDF::PDF::Content::ColorSpace::DeviceRGB::DEFAULT,
                   @res.color_space(:DeviceRGB))
      assert_equal(HexaPDF::PDF::Content::ColorSpace::DeviceCMYK::DEFAULT,
                   @res.color_space(:DeviceCMYK))
      assert_equal(HexaPDF::PDF::Content::ColorSpace::DeviceGray::DEFAULT,
                   @res.color_space(:DeviceGray))
    end

    it "works for color spaces defined only with a name" do
      @res[:ColorSpace] = {CSName: :Pattern}
      assert_kind_of(HexaPDF::PDF::Content::ColorSpace::Universal, @res.color_space(:CSName))
    end

    it "returns the universal color space for unknown color spaces, with resolved references" do
      data = @doc.add({Some: :data})
      @res[:ColorSpace] = {CSName: [:SomeUnknownColorSpace,
                                    HexaPDF::PDF::Reference.new(data.oid, data.gen)]}
      color_space = @res.color_space(:CSName)
      assert_kind_of(HexaPDF::PDF::Content::ColorSpace::Universal, color_space)
      assert_equal([:SomeUnknownColorSpace, data], color_space.definition)
    end

    it "fails if the specified name is neither a device color space nor in the dictionary" do
      assert_raises(HexaPDF::Error) { @res.color_space(:UnknownColorSpace) }
    end
  end

  describe "validation" do
    it "assigns the default value if ProcSet is not set" do
      @res.validate
      assert_equal([:PDF, :Text, :ImageB, :ImageC, :ImageI], @res[:ProcSet])
    end

    it "removes invalid procedure set names from ProcSet" do
      @res[:ProcSet] = [:PDF, :Unknown]
      @res.validate
      assert_equal([:PDF], @res[:ProcSet])
    end
  end
end
