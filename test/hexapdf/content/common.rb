# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/processor'

module TestHelper

  # Can be used to to record operators parsed from content streams.
  class OperatorRecorder < HexaPDF::Content::Processor

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

end
