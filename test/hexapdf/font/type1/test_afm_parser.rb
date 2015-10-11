# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/font/type1'
require 'hexapdf/data_dir'
require 'tempfile'
require 'stringio'

describe HexaPDF::Font::Type1::AFMParser do
  describe "::parse" do
    before do
      @file = Tempfile.new('hexapdf-afm')
      @file.write("StartFontMetrics 4.1\nFontName Test\nEndFontMetrics\n")
      @file.close
    end

    after do
      @file.unlink
    end

    it "can work with file names" do
      assert_equal('Test', HexaPDF::Font::Type1::AFMParser.parse(@file.path).font_name)
    end

    it "can work with IO streams" do
      @file.open
      assert_equal('Test', HexaPDF::Font::Type1::AFMParser.parse(@file).font_name)
    end
  end

  it "can parse the 14 core PDF font files" do
    Dir[File.join(HexaPDF.data_dir, 'afm', '*.afm')].each do |file|
      metrics = HexaPDF::Font::Type1::AFMParser.parse(file)
      basename = File.basename(file, '.*')
      assert_equal(basename, metrics.font_name, basename)
      assert_equal(basename.sub(/-.*/, ''), metrics.family_name, basename)
      assert(metrics.character_metrics.size > 0, basename)
    end
  end

  it "fails if the file doesn't start with the correct line" do
    file = StringIO.new("some\nthing")
    assert_raises(HexaPDF::Error) { HexaPDF::Font::Type1::AFMParser.parse(file) }
  end
end
