# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/resources'
require 'hexapdf/document'

describe HexaPDF::PDF::Type::Resources do
  before do
    @doc = HexaPDF::Document.new
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
                                    HexaPDF::Reference.new(data.oid, data.gen)]}
      color_space = @res.color_space(:CSName)
      assert_kind_of(HexaPDF::PDF::Content::ColorSpace::Universal, color_space)
      assert_equal([:SomeUnknownColorSpace, data], color_space.definition)
    end

    it "fails if the specified name is neither a device color space nor in the dictionary" do
      assert_raises(HexaPDF::Error) { @res.color_space(:UnknownColorSpace) }
    end
  end

  describe "add_color_space" do
    it "returns device color spaces without adding an entry" do
      [HexaPDF::PDF::Content::ColorSpace::DeviceRGB::DEFAULT,
       HexaPDF::PDF::Content::ColorSpace::DeviceCMYK::DEFAULT,
       HexaPDF::PDF::Content::ColorSpace::DeviceGray::DEFAULT].each do |space|
        name = @res.add_color_space(space)
        assert_equal(space.family, name)
        refute(@res.key?(:ColorSpace))
      end
    end

    it "adds a color space that is not a device color space" do
      space = HexaPDF::PDF::Content::ColorSpace::Universal.new([:DeviceN, :data])
      name = @res.add_color_space(space)
      assert(@res[:ColorSpace].key?(name))
      assert_equal(space.definition, @res[:ColorSpace][name])
      assert_equal(space, @res.color_space(name))
    end

    it "doesn't add the same color space twice" do
      object = @doc.add(some: :data)
      @res[:ColorSpace] = {space: [:DeviceN, HexaPDF::Reference.new(object.oid, object.gen)]}
      space = HexaPDF::PDF::Content::ColorSpace::Universal.new([:DeviceN, object])
      name = @res.add_color_space(space)
      assert_equal(:space, name)
      assert_equal(1, @res[:ColorSpace].value.size)
      assert_equal(space, @res.color_space(name))
    end

    it "uses a unique color space name" do
      @res[:ColorSpace] = {CS2: [:DeviceN, :test]}
      space = HexaPDF::PDF::Content::ColorSpace::Universal.new([:DeviceN, :data])
      name = @res.add_color_space(space)
      refute_equal(:CS2, name)
      assert_equal(2, @res[:ColorSpace].value.size)
    end
  end

  describe "private object_getter" do
    it "returns the named entry under the dictionary" do
      @res[:XObject] = {name: :value}
      assert_equal(:value, @res.xobject(:name))
    end

    it "fails if the specified name is not in the dictionary" do
      assert_raises(HexaPDF::Error) { @res.xobject(:UnknownXObject) }
    end
  end

  describe "private object_setter" do
    it "adds the object to the specified subdictionary" do
      obj = @doc.add(some: :xobject)
      name = @res.add_xobject(obj)
      assert(@res[:XObject].key?(name))
      assert_equal(obj, @res[:XObject][name])
    end

    it "doesn't add the same object twice" do
      obj = @doc.add(some: :xobject)
      name = @res.add_xobject(obj)
      name2 = @res.add_xobject(obj)
      assert_equal(name, name2)
    end
  end

  describe "xobject" do
    it "invokes the object_getter method" do
      assert_method_invoked(@res, :object_getter, [:XObject, :test]) do
        @res.xobject(:test)
      end
    end
  end

  describe "add_xobject" do
    it "invokes the object_setter method" do
      assert_method_invoked(@res, :object_setter, [:XObject, 'XO', :test]) do
        @res.add_xobject(:test)
      end
    end
  end

  describe "ext_gstate" do
    it "invokes the object_getter method" do
      assert_method_invoked(@res, :object_getter, [:ExtGState, :test]) do
        @res.ext_gstate(:test)
      end
    end
  end

  describe "add_ext_gstate" do
    it "invokes the object_setter method" do
      assert_method_invoked(@res, :object_setter, [:ExtGState, 'GS', :test]) do
        @res.add_ext_gstate(:test)
      end
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
