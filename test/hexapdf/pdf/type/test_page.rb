# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/type/page'

describe HexaPDF::PDF::Type::Page do
  before do
    @doc = HexaPDF::PDF::Document.new
  end

  describe "[]" do
    before do
      @root = @doc.add(Type: :Pages)
      @kid = @doc.add(Type: :Pages, Parent: @root)
      @page = @doc.add(Type: :Page, Parent: @kid)
    end

    it "works normal for non-inheritable fields" do
      assert_equal(:Page, @page[:Type])
      assert_nil(@page[:Dur])
    end

    it "automatically retrieves inherited values" do
      @root[:MediaBox] = :media
      assert_equal(:media, @page[:MediaBox])

      @root[:Resources] = :root_res
      @kid[:Resources] = :res
      assert_equal(:res, @page[:Resources])

      @page[:CropBox] = :cropbox
      assert_equal(:cropbox, @page[:CropBox])

      @kid[:Rotate] = :kid_rotate
      assert_equal(:kid_rotate, @page[:Rotate])
      @kid.delete(:Rotate)
      assert_equal(0, @page[:Rotate])
    end
  end

  describe "validation" do
    it "fails if a required inheritable field is not set" do
      root = @doc.add(Type: :Pages)
      page = @doc.add(Type: :Page, Parent: root)
      message = ''
      refute(page.validate {|m, _| message = m})
      assert_match(/inheritable.*MediaBox/i, message)
    end
  end
end
