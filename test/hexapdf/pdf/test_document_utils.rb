# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/pdf/document'

describe HexaPDF::PDF::DocumentUtils::Images do
  before do
    @doc = HexaPDF::PDF::Document.new
  end

  describe "add_image" do
    describe "using a custom image loader" do
      before do
        @loader = Object.new
        @loader.define_singleton_method(:handles?) {|*| true}
        @loader.define_singleton_method(:load) do |doc, s|
          s = HexaPDF::PDF::StreamData.new(s) if s.kind_of?(IO)
          doc.add({Subtype: :Image}, stream: s)
        end
        HexaPDF::PDF::GlobalConfiguration['image_loader'].unshift(@loader)
      end

      after do
        HexaPDF::PDF::GlobalConfiguration['image_loader'].delete(@loader)
      end

      it "adds an image using a filename" do
        data = 'test'
        image = @doc.utils.add_image(data)
        assert_equal(data, image.stream)
        assert_equal(File.absolute_path(data), image.source_path)
      end

      it "adds an image using an IO" do
        File.open(__FILE__, 'rb') do |file|
          image = @doc.utils.add_image(file)
          assert_equal(File.read(__FILE__), image.stream)
          assert_equal(File.absolute_path(__FILE__), image.source_path)
        end
      end

      it "doesn't add an image twice" do
        data = 'test'
        image = @doc.utils.add_image(data)
        image1 = @doc.utils.add_image(data)
        assert_same(image, image1)
      end
    end

    it "fails if the needed image loader can't be resolved" do
      begin
        HexaPDF::PDF::GlobalConfiguration['image_loader'].unshift('SomeUnknownConstantHere')
        exp = assert_raises(HexaPDF::Error) { @doc.utils.add_image(StringIO.new('test')) }
        assert_match(/image loader from configuration/, exp.message)
      ensure
        HexaPDF::PDF::GlobalConfiguration['image_loader'].shift
      end
    end

    it "fails if no image loader is found" do
      exp = assert_raises(HexaPDF::Error) { @doc.utils.add_image(StringIO.new('test')) }
      assert_match(/suitable image loader/, exp.message)
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
