# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/image_loader/png'

describe HexaPDF::PDF::ImageLoader::PNG do
  before do
    @doc = HexaPDF::PDF::Document.new
    @loader = HexaPDF::PDF::ImageLoader::PDF
    @pdf = File.join(TEST_DATA_DIR, 'minimal.pdf')
  end

  describe "handles?" do
    it "works for PDF files" do
      assert(@loader.handles?(@pdf))
      File.open(@pdf, 'rb') {|file| assert(@loader.handles?(file))}
    end
  end

  def assert_matrix(form)
    assert_equal([1.0 / form.box[2], 0, 0, 1.0 / form.box[3], 0, 0], form[:Matrix])
  end

  describe "load" do
    it "works for PDF files using a File object" do
      File.open(@pdf, 'rb') do |file|
        form = @loader.load(@doc, file)
        assert_matrix(form)
      end
    end

    it "works for PDF files using a string object and use_stringio=true" do
      @doc.config['image_loader.pdf.use_stringio'] = true
      form = @loader.load(@doc, @pdf)
      assert_matrix(form)
    end

    it "works for PDF files using a string object and use_stringio=false" do
      begin
        @doc.config['image_loader.pdf.use_stringio'] = false
        form = @loader.load(@doc, @pdf)
        assert_matrix(form)
      ensure
        ObjectSpace.each_object(File) do |file|
          file.close if file.path == @pdf && !file.closed?
        end
      end
    end
  end
end
