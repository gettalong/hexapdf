# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/parser'
require 'hexapdf/content/processor'
require_relative '../common_tokenizer_tests'

describe HexaPDF::Content::Tokenizer do
  include CommonTokenizerTests

  def create_tokenizer(str)
    @tokenizer = HexaPDF::Content::Tokenizer.new(str.b)
  end
end

describe HexaPDF::Content::Parser do
  before do
    @recorder = TestHelper::OperatorRecorder.new
    @processor = HexaPDF::Content::Processor.new({}, renderer: @recorder)
    @processor.operators.clear
    @parser = HexaPDF::Content::Parser.new
  end

  describe "parse" do
    it "parses a simple content stream without inline images" do
      @parser.parse("0 0.500 m q Q /Name SCN", @processor)
      assert_equal([[:move_to, [0, 0.5]], [:save_graphics_state],
                    [:restore_graphics_state],
                    [:set_stroking_color, [:Name]]], @recorder.operators)
    end

    it "parses a content stream with inline images" do
      @parser.parse("q BI /Name 0.5/Other 1 ID some dataEI Q", @processor)
      assert_equal([[:save_graphics_state],
                    [:inline_image, [{Name: 0.5, Other: 1}, "some data"]],
                    [:restore_graphics_state]], @recorder.operators)
    end

    it "fails parsing inline images if the dictionary keys are not PDF names" do
      exp = assert_raises(HexaPDF::Error) do
        @parser.parse("q BI /Name 0.5 Other 1 ID some dataEI Q", @processor)
      end
      assert_match(/keys.*PDF name/, exp.message)
    end

    it "fails parsing inline images when trying to read a dict key and EOS is encountered" do
      exp = assert_raises(HexaPDF::Error) do
        @parser.parse("q BI /Name 0.5", @processor)
      end
      assert_match(/EOS.*dictionary key/, exp.message)
    end

    it "fails parsing inline images when trying to read a dict value and EOS is encountered" do
      exp = assert_raises(HexaPDF::Error) do
        @parser.parse("q BI /Name 0.5 /Other", @processor)
      end
      assert_match(/EOS.*dictionary value/, exp.message)
    end

    it "fails parsing inline images if the EI is not found" do
      exp = assert_raises(HexaPDF::Error) do
        @parser.parse("q BI /Name 0.5 /Other 1 ID test", @processor)
      end
      assert_match(/EI not found/, exp.message)
    end
  end
end
