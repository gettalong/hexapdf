# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'tempfile'
require 'hexapdf/document'

describe HexaPDF::DocumentUtils::Images do
  before do
    @doc = HexaPDF::Document.new
  end

  describe "add_image" do
    describe "using a custom image loader" do
      before do
        @loader = Object.new
        @loader.define_singleton_method(:handles?) {|*| true}
        @loader.define_singleton_method(:load) do |doc, s|
          s = HexaPDF::StreamData.new(s) if s.kind_of?(IO)
          doc.add({Subtype: :Image}, stream: s)
        end
        HexaPDF::GlobalConfiguration['image_loader'].unshift(@loader)
      end

      after do
        HexaPDF::GlobalConfiguration['image_loader'].delete(@loader)
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
        HexaPDF::GlobalConfiguration['image_loader'].unshift('SomeUnknownConstantHere')
        exp = assert_raises(HexaPDF::Error) { @doc.utils.add_image(StringIO.new('test')) }
        assert_match(/image loader from configuration/, exp.message)
      ensure
        HexaPDF::GlobalConfiguration['image_loader'].shift
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


describe HexaPDF::DocumentUtils::Files do
  before do
    @doc = HexaPDF::Document.new
    @data = "embed-test"
    @file = Tempfile.new('file-embed-test')
    @file.write(@data)
    @file.close
  end

  after do
    @file.unlink
  end

  describe "add_file" do
    it "adds a file using a filename and embeds it" do
      spec = @doc.utils.add_file(@file.path)
      assert_equal(File.basename(@file.path), spec.path)
      assert_equal(@data, spec.embedded_file_stream.stream)
    end

    it "adds a reference to a file" do
      spec = @doc.utils.add_file(@file.path, embed: false)
      assert_equal(File.basename(@file.path), spec.path)
      refute(spec.embedded_file?)
    end

    it "adds a file using an IO" do
      @file.open
      spec = @doc.utils.add_file(@file, name: 'test', embed: false)
      assert_equal('test', spec.path)
      assert_equal(@data, spec.embedded_file_stream.stream)
    end

    it "optionally sets the description of the file" do
      spec = @doc.utils.add_file(@file.path, description: 'Some file')
      assert_equal('Some file', spec[:Desc])
    end

    it "requires the name argument when given an IO object" do
      assert_raises(ArgumentError) { @doc.utils.add_file(StringIO.new) }
    end
  end

  describe "each_file" do
    it "iterates only over named embedded files and file annotations if search=false" do
      @doc.add(Type: :Filespec)
      spec1 = @doc.utils.add_file(__FILE__)
      spec2 = @doc.add(Type: :Filespec)
      @doc.pages.add_page[:Annots] = [
        {Subtype: :FileAttachment, FS: HexaPDF::Reference.new(spec1.oid, spec1.gen)},
        {Subtype: :FileAttachment, FS: spec2},
        {},
      ]
      assert_equal([spec1, spec2], @doc.utils.each_file.to_a)
    end

    it "iterates over all file specifications of the document if search=true" do
      specs = []
      specs << @doc.add(Type: :Filespec)
      specs << @doc.add(Type: :Filespec)
      assert_equal(specs, @doc.utils.each_file(search: true).to_a)
    end
  end
end
