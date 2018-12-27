# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative '../content/common'
require 'hexapdf/document'
require 'hexapdf/type/form'

describe HexaPDF::Type::Form do
  before do
    @doc = HexaPDF::Document.new
    @form = @doc.wrap({}, subtype: :Form)
  end

  describe "box" do
    before do
      @form[:BBox] = [10, 10, 110, 60]
    end

    it "returns the /BBox entry" do
      assert_equal([10, 10, 110, 60], @form.box.value)
    end

    it "returns the box's width" do
      assert_equal(100, @form.width)
    end

    it "returns the box's height" do
      assert_equal(50, @form.height)
    end
  end

  describe "contents" do
    it "returns a duplicate of the stream" do
      @form.stream = 'test'
      assert_equal(@form.stream, @form.contents)
      @form.contents.gsub!(/test/, 'other')
      assert_equal(@form.stream, @form.contents)
    end
  end

  describe "contents=" do
    it "set the stream contents" do
      @form.contents = 'test'
      assert_equal('test', @form.stream)
    end
  end

  describe "resources" do
    it "creates the resource dictionary if it is not found" do
      resources = @form.resources
      assert_equal(:XXResources, resources.type)
      assert_equal({}, resources.value)
    end

    it "returns the already used resource dictionary" do
      @form[:Resources] = {Font: nil}
      resources = @form.resources
      assert_equal(:XXResources, resources.type)
      assert_equal(@form[:Resources], resources)
    end
  end

  describe "process_contents" do
    it "parses the contents and processes it" do
      @form.stream = '10 w'
      processor = TestHelper::OperatorRecorder.new
      @form.process_contents(processor)
      assert_equal([[:set_line_width, [10]]], processor.recorded_ops)
      assert_nil(@form[:Resources])

      resources = @form.resources
      @form.process_contents(processor)
      assert_same(resources, processor.resources)
    end

    it "uses the provided resources if it has no resources itself" do
      resources = @doc.wrap({}, type: :XXResources)
      processor = TestHelper::OperatorRecorder.new
      @form.process_contents(processor, original_resources: resources)
      assert_same(resources, processor.resources)
    end
  end

  describe "canvas" do
    it "always returns the same Canvas instance" do
      canvas = @form.canvas
      assert_same(canvas, @form.canvas)
    end

    it "fails if the form XObject already has data" do
      @form.stream = '10 w'
      assert_raises(HexaPDF::Error) { @form.canvas }
    end
  end
end
