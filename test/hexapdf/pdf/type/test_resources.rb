# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/resources'
require 'hexapdf/pdf/document'

describe HexaPDF::PDF::Type::Resources do
  before do
    doc = HexaPDF::PDF::Document.new
    @res = HexaPDF::PDF::Type::Resources.new({}, document: doc)
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

    it "returns the universal color space for unknown color space names" do
      @res[:ColorSpace] = {CSName: [:SomeUnknownColorSpace, :some, :data, :here]}
      assert_kind_of(HexaPDF::PDF::Content::ColorSpace::Universal,
                     @res.color_space(:CSName))
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
