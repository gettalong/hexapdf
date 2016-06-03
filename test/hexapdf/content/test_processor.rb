# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/content/processor'

describe HexaPDF::Content::Processor do
  before do
    @processor = HexaPDF::Content::Processor.new
  end

  describe "initialization" do
    it "has a prepopulated operators mapping" do
      assert_kind_of(HexaPDF::Content::Operator::BaseOperator, @processor.operators[:q])
    end
  end

  describe "graphics_object" do
    it "default to :none on initialization" do
      assert_equal(:none, @processor.graphics_object)
    end
  end

  describe "process" do
    it "invokes the specified operator implementation" do
      op = Minitest::Mock.new
      op.expect(:invoke, nil, [@processor, :arg])
      @processor.operators[:test] = op
      @processor.process(:test, [:arg])
      op.verify
    end

    it "invokes the mapped message name" do
      val = nil
      @processor = HexaPDF::Content::Processor.new
      @processor.define_singleton_method(:save_graphics_state) { val = :arg }
      @processor.process(:q)
      assert_equal(:arg, val)
    end
  end
end
