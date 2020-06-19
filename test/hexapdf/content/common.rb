# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/processor'

module TestHelper

  # Can be used to to record operators parsed from content streams.
  class OperatorRecorder < HexaPDF::Content::Processor

    undef :paint_xobject

    attr_reader :recorded_ops

    def initialize
      super
      operators.clear
      @recorded_ops = []
    end

    def respond_to_missing?(*)
      true
    end

    def method_missing(msg, *params)
      @recorded_ops << (params.empty? ? [msg] : [msg, params])
    end

  end

  # Asserts that the content string contains the operators.
  def assert_operators(content, operators, only_names: false, range: 0..-1)
    processor = TestHelper::OperatorRecorder.new
    HexaPDF::Content::Parser.new.parse(content, processor)
    result = processor.recorded_ops[range]
    result.map!(&:first) if only_names
    assert_equal(operators, result)
  end
end
