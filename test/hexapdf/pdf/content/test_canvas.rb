# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/content/canvas'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/content/processor'
require 'hexapdf/pdf/content/parser'

describe HexaPDF::PDF::Content::Canvas do
  before do
    @recorder = TestHelper::OperatorRecorder.new
    @processor = HexaPDF::PDF::Content::Processor.new({}, renderer: @recorder)
    @processor.operators.clear
    @parser = HexaPDF::PDF::Content::Parser.new

    @doc = HexaPDF::PDF::Document.new
    @page = @doc.pages.add_page
    @canvas = HexaPDF::PDF::Content::Canvas.new(@page, content: :replace)
  end

  # Asserts that the content string contains the operators.
  def assert_operators(content, operators)
    @recorder.operations.clear
    @parser.parse(content, @processor)
    assert_equal(operators, @recorder.operators)
  end

  # Asserts that a specific operator is invoked when the block is executed.
  def assert_operator_invoked(op)
    mock = Minitest::Mock.new
    mock.expect(:invoke, nil) { true }
    mock.expect(:serialize, '') { true }
    op_before = @canvas.instance_variable_get(:@operators)[op]
    @canvas.instance_variable_get(:@operators)[op] = mock
    yield
    mock.verify
  ensure
    @canvas.instance_variable_get(:@operators)[op] = op_before
  end

  describe "initialize" do
    module ContentStrategyTests
      extend Minitest::Spec::DSL

      it "content strategy replace: new content replaces existing content" do
        @context.contents = 'Some content here'
        canvas = HexaPDF::PDF::Content::Canvas.new(@context, content: :replace)
        canvas.save_graphics_state
        assert_operators(@context.contents, [[:save_graphics_state]])
      end

      it "content strategy append: new content is appended" do
        assert_raises(HexaPDF::Error) do
          HexaPDF::PDF::Content::Canvas.new(@context, content: :append)
        end
        skip
      end

      it "content strategy prepend: new content is prepended" do
        assert_raises(HexaPDF::Error) do
          HexaPDF::PDF::Content::Canvas.new(@context, content: :prepend)
        end
        skip
      end
    end

    describe "with Page as context" do
      include ContentStrategyTests

      before do
        @context = @doc.pages.page(0)
      end
    end

    describe "with Form as context" do
      include ContentStrategyTests

      before do
        @context = @doc.add(Subtype: :Form)
      end
    end
  end

  describe "resources" do
    it "returns the resources of the context object" do
      assert_equal(@page.resources, @canvas.resources)
    end
  end

  describe "save_graphics_state" do
    it "invokes the operator implementation" do
      assert_operator_invoked(:q) { @canvas.save_graphics_state }
    end

    it "is serialized correctly when no block is used" do
      @canvas.save_graphics_state
      assert_operators(@page.contents, [[:save_graphics_state]])
    end

    it "is serialized correctly when a block is used" do
      @canvas.save_graphics_state { }
      assert_operators(@page.contents, [[:save_graphics_state], [:restore_graphics_state]])
    end
  end

  describe "restore_graphics_state" do
    it "invokes the operator implementation" do
      assert_operator_invoked(:Q) { @canvas.restore_graphics_state }
    end

    it "is serialized correctly" do
      @canvas.graphics_state.save
      @canvas.restore_graphics_state
      assert_operators(@page.contents, [[:restore_graphics_state]])
    end
  end

  describe "transform" do
    it "invokes the operator implementation" do
      assert_operator_invoked(:cm) { @canvas.transform(1, 2, 3, 4, 5, 6) }
    end

    it "is serialized correctly when no block is used" do
      @canvas.transform(1, 2, 3, 4, 5, 6)
      assert_operators(@page.contents, [[:concatenate_matrix, [1, 2, 3, 4, 5, 6]]])
    end

    it "is serialized correctly when a block is used" do
      @canvas.transform(1, 2, 3, 4, 5, 6) {}
      assert_operators(@page.contents, [[:save_graphics_state],
                                        [:concatenate_matrix, [1, 2, 3, 4, 5, 6]],
                                        [:restore_graphics_state]])
    end
  end

  describe "rotate" do
    it "can rotate around the origin" do
      @canvas.rotate(90)
      assert_operators(@page.contents, [[:concatenate_matrix, [0, 1, -1, 0, 0, 0]]])
    end

    it "can rotate about an arbitrary point" do
      @canvas.rotate(90, origin: [100, 200])
      assert_operators(@page.contents, [[:concatenate_matrix, [0.0, 1.0, -1.0, 0.0, 300.0, 100.0]]])
    end
  end

  describe "scale" do
    it "can scale from the origin" do
      @canvas.scale(5, 10)
      assert_operators(@page.contents, [[:concatenate_matrix, [5, 0, 0, 10, 0, 0]]])
    end

    it "can scale from an arbitrary point" do
      @canvas.scale(5, 10, origin: [100, 200])
      assert_operators(@page.contents, [[:concatenate_matrix, [5, 0, 0, 10, -400, -1800]]])
    end

    it "works with a single scale factor" do
      @canvas.scale(5)
      assert_operators(@page.contents, [[:concatenate_matrix, [5, 0, 0, 5, 0, 0]]])
    end
  end

  describe "translate" do
    it "translates the origin" do
      @canvas.translate(100, 200)
      assert_operators(@page.contents, [[:concatenate_matrix, [1, 0, 0, 1, 100, 200]]])
    end
  end

  describe "skew" do
    it "can skew from the origin" do
      @canvas.skew(45, 0)
      assert_operators(@page.contents, [[:concatenate_matrix, [1, 1, 0, 1, 0, 0]]])
    end

    it "can skew from an arbitrary point" do
      @canvas.skew(45, 0, origin: [100, 200])
      assert_operators(@page.contents, [[:concatenate_matrix, [1, 1, 0, 1, 0, -100]]])
    end
  end
end
