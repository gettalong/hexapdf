# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Document::Annotations do
  before do
    @doc = HexaPDF::Document.new
    @page = @doc.pages.add
    @annots = @doc.annotations
  end

  describe "create" do
    it "fails if the type argument doesn't refer to an implemented method" do
      assert_raises(ArgumentError) { @annots.create(:unknown, @page) }
    end

    it "delegates to the actual create_TYPE implementation" do
      annot = @annots.create(:line, @page, start_point: [0, 0], end_point: [10, 10])
      assert_equal(:Line, annot[:Subtype])
    end
  end

  describe "create_line" do
    it "creates an appropriate line annotation object" do
      annot = @annots.create(:line, @page, start_point: [0, 5], end_point: [10, 15])
      assert_equal(:Annot, annot[:Type])
      assert_equal(:Line, annot[:Subtype])
      assert_equal([0, 5, 10, 15], annot.line)
      assert_equal(annot, @page[:Annots].first)
    end
  end
end
