# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/annotation'

describe HexaPDF::Type::Annotation do
  before do
    @doc = HexaPDF::Document.new
    @annot = @doc.add({Type: :Annot, F: 0b100011})
  end

  describe "flags" do
    it "returns all flags" do
      assert_equal([:invisible, :hidden, :no_view], @annot.flags)
    end
  end

  describe "flagged?" do
    it "returns true if the given flag is set" do
      assert(@annot.flagged?(:hidden))
      refute(@annot.flagged?(:locked))
    end

    it "raises an error if an unknown flag name is provided" do
      assert_raises(ArgumentError) { @annot.flagged?(:unknown) }
    end
  end

  describe "flag" do
    it "sets the given flag bits" do
      @annot.flag(:locked)
      assert_equal([:invisible, :hidden, :no_view, :locked], @annot.flags)
      @annot.flag(:locked, clear_existing: true)
      assert_equal([:locked], @annot.flags)
    end
  end
end
