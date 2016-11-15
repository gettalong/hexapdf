# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Fonts do
  before do
    @doc = HexaPDF::Document.new
    @doc.config['font_loader'] = []
  end

  describe "load" do
    before do
      @doc.config['font_loader'] << lambda do |doc, name, **options|
        assert_equal(@doc, doc)
        if name == :TestFont
          x = Object.new
          x.define_singleton_method(:name) do
            options[:variant] == :bold ? :BoldFont : :NormalFont
          end
          x
        else
          nil
        end
      end
    end

    it "loads the specified font" do
      assert_equal(:NormalFont, @doc.fonts.load(:TestFont).name)
      assert_equal(:BoldFont, @doc.fonts.load(:TestFont, variant: :bold).name)
    end

    it "caches loaded fonts" do
      assert_same(@doc.fonts.load(:TestFont), @doc.fonts.load(:TestFont))
    end

    it "fails if the requested font is not found"  do
      assert_raises(HexaPDF::Error) { @doc.fonts.load("Unknown") }
    end

    it "raises an error if a font loader cannot be correctly retrieved" do
      @doc.config['font_loader'][0] = 'UnknownFontLoader'
      assert_raises(HexaPDF::Error) { @doc.fonts.load(:Other) }
    end
  end
end
