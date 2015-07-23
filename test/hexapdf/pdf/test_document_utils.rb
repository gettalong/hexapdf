# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/pdf/document'

describe HexaPDF::PDF::DocumentUtils::Images do
  before do
    @doc = HexaPDF::PDF::Document.new
  end

  describe "add_image" do
    it "adds an image" do
      begin
        @loader = Object.new
        @loader.define_singleton_method(:handles?) {|*| true}
        @loader.define_singleton_method(:load) {|doc, s| doc.add({Subtype: :Image}, stream: s)}
        HexaPDF::PDF::GlobalConfiguration['image_loader'].unshift(@loader)
        data = 'test'
        image = @doc.utils.add_image(data)
        assert_equal(data, image.stream)
      ensure
        HexaPDF::PDF::GlobalConfiguration['image_loader'].delete(@loader)
      end
    end

    it "fails if the needed image loader can't be resolved" do
      begin
        HexaPDF::PDF::GlobalConfiguration['image_loader'].unshift('SomeUnknownConstantHere')
        assert_raises(HexaPDF::Error) { @doc.utils.add_image(StringIO.new('test')) }
      ensure
        HexaPDF::PDF::GlobalConfiguration['image_loader'].shift
      end
    end

    it "fails if no image loader is found" do
      assert_raises(HexaPDF::Error) { @doc.utils.add_image(StringIO.new('test')) }
    end
  end

  describe "each" do
    it "iterates over all non-mask images" do
      images = []
      images << @doc.add(Subtype: :Image)
      images << @doc.add(Subtype: :Image, Mask: [5, 6])
      images << @doc.add(Subtype: :Image, Mask: @doc.add(Subtype: :Image))
      images << @doc.add(Subtype: :Image, SMask: @doc.add(Subtype: :Image))
      assert_equal(images.sort, @doc.utils.each_image.to_a.sort)
    end
  end
end
