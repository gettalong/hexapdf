# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/processor'

describe HexaPDF::PDF::Content::Processor do
  before do
    @processor = HexaPDF::PDF::Content::Processor.new({})
  end

  describe "initialization" do
    it "has a prepopulated operators mapping" do
      assert_kind_of(HexaPDF::PDF::Content::Operator::BaseOperator, @processor.operators[:q])
    end
  end

  describe "graphics_object" do
    it "default to :none on initialization" do
      assert_equal(:none, @processor.graphics_object)
    end

    it "can be checked if we are in a text object" do
      refute(@processor.in_text?)
      @processor.graphics_object = :text
      assert(@processor.in_text?)
    end

    it "can be checked if we are in a path object" do
      refute(@processor.in_path?)
      @processor.graphics_object = :path
      assert(@processor.in_path?)
      @processor.graphics_object = :clipping_path
      assert(@processor.in_path?)
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

    it "invokes the renderer with the mapped message name" do
      val = nil
      renderer = Object.new
      renderer.define_singleton_method(:save_graphics_state) { val = :arg }
      @processor = HexaPDF::PDF::Content::Processor.new({}, renderer: renderer)
      @processor.process(:q)
      assert_equal(:arg, val)
    end
  end
end
