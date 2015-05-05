# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/type/page'

describe HexaPDF::PDF::Type::Page do

  describe "[]" do
    before do
      @doc = HexaPDF::PDF::Document.new
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
      @root[:Resources] = :root_res
      @kid[:Resources] = :res
      @kid[:Rotate] = :kid_rotate
      @page[:Rotate] = :rotate
      assert_equal(:media, @page[:MediaBox])
      assert_equal(:res, @page[:Resources])
      assert_equal(:rotate, @page[:Rotate])
      assert_nil(@page[:CropBox])
    end
  end

end
