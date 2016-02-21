# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/tokenizer'
require 'stringio'
require_relative 'common_tokenizer_tests'

describe HexaPDF::Tokenizer do
  include CommonTokenizerTests

  def create_tokenizer(str)
    @tokenizer = HexaPDF::Tokenizer.new(StringIO.new(str.b))
  end

  it "handles object references" do
    create_tokenizer("1 0 R 2 15 R ")
    assert_equal(HexaPDF::Reference.new(1, 0), @tokenizer.next_token)
    assert_equal(HexaPDF::Reference.new(2, 15), @tokenizer.next_token)
    @tokenizer.pos = 0
    assert_equal(HexaPDF::Reference.new(1, 0), @tokenizer.next_object)
    assert_equal(HexaPDF::Reference.new(2, 15), @tokenizer.next_object)
  end

  it "next_token: should not fail when resetting the position (due to the use of the internal StringScanner buffer)" do
    create_tokenizer("0 1 2 3 4 " * 4000)
    4000.times do
      5.times {|i| assert_equal(i, @tokenizer.next_token)}
    end
  end
end
