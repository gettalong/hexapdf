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
  def assert_operator_invoked(op, *args)
    mock = Minitest::Mock.new
    if args.empty?
      mock.expect(:invoke, nil) { true }
      mock.expect(:serialize, '') { true }
    else
      mock.expect(:invoke, nil, [@canvas] + args)
      mock.expect(:serialize, '', [@canvas.instance_variable_get(:@serializer)] + args)
    end
    op_before = @canvas.instance_variable_get(:@operators)[op]
    @canvas.instance_variable_get(:@operators)[op] = mock
    yield
    assert(mock.verify)
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
      assert_operator_invoked(:cm, 1, 2, 3, 4, 5, 6) { @canvas.transform(1, 2, 3, 4, 5, 6) }
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

  describe "private gs_getter_setter" do
    it "returns the current value when used with a nil argument or a block" do
      @canvas.graphics_state.line_width = 5
      assert_equal(5, @canvas.send(:gs_getter_setter, :line_width, :w, nil))
      assert_equal(5, @canvas.send(:gs_getter_setter, :line_width, :w, 15) {})
    end

    it "returns the new value when used with a non-nil argument and no block" do
      @canvas.graphics_state.line_width = 5
      assert_equal(15, @canvas.send(:gs_getter_setter, :line_width, :w, 15))
    end

    it "invokes the operator implementation when a non-nil argument is used" do
      assert_operator_invoked(:w, 5) { @canvas.send(:gs_getter_setter, :line_width, :w, 5) }
      assert_operator_invoked(:w, 15) { @canvas.send(:gs_getter_setter, :line_width, :w, 15) {} }
    end

    it "doesn't add an operator if the value is equal to the current one" do
      @canvas.send(:gs_getter_setter, :line_width, :w,
                   @canvas.send(:gs_getter_setter, :line_width, :w, nil))
      assert_operators(@page.contents, [])
    end

    it "is serialized correctly when no block is used" do
      @canvas.send(:gs_getter_setter, :line_width, :w, 5)
      assert_operators(@page.contents, [[:set_line_width, [5]]])
    end

    it "is serialized correctly when a block is used" do
      @canvas.send(:gs_getter_setter, :line_width, :w, 5) do
        @canvas.send(:gs_getter_setter, :line_width, :w, 15)
      end
      assert_operators(@page.contents, [[:save_graphics_state],
                                        [:set_line_width, [5]],
                                        [:set_line_width, [15]],
                                        [:restore_graphics_state]])
    end

    it "fails if a block is given without an argument" do
      assert_raises(HexaPDF::Error) { @canvas.send(:gs_getter_setter, :line_width, :w, nil) {} }
    end
  end

  # Asserts that the method +name+ invoked with +values+ invokes the #gs_getter_setter helper method
  # with the +name+, +operator+ and +expected_value+ as arguments.
  def assert_gs_getter_setter(name, operator, expected_value, *values)
    args = nil
    @canvas.define_singleton_method(:gs_getter_setter) {|*largs, &block| args = largs + [block]}
    @canvas.send(name, *values) {}
    @canvas.singleton_class.send(:remove_method, :gs_getter_setter)
    assert_equal(name, args[0])
    assert_equal(operator, args[1])
    assert_equal(expected_value, args[2])
    assert_kind_of(Proc, args[3])
    assert_respond_to(@canvas, name)
  end

  describe "line_width" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:line_width, :w, 5, 5)
      assert_gs_getter_setter(:line_width, :w, nil, nil)
    end
  end

  describe "line_cap_style" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:line_cap_style, :J, 1, :round)
      assert_gs_getter_setter(:line_cap_style, :J, nil, nil)
    end
  end

  describe "line_join_style" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:line_join_style, :j, 1, :round)
      assert_gs_getter_setter(:line_join_style, :j, nil, nil)
    end
  end

  describe "miter_limit" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:miter_limit, :M, 15, 15)
      assert_gs_getter_setter(:miter_limit, :M, nil, nil)
    end
  end

  describe "line_dash_pattern" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:line_dash_pattern, :d, nil, nil)
      assert_gs_getter_setter(:line_dash_pattern, :d,
                              HexaPDF::PDF::Content::LineDashPattern.new, 0)
      assert_gs_getter_setter(:line_dash_pattern, :d,
                              HexaPDF::PDF::Content::LineDashPattern.new([5]), 5)
      assert_gs_getter_setter(:line_dash_pattern, :d,
                              HexaPDF::PDF::Content::LineDashPattern.new([5], 2), 5, 2)
      assert_gs_getter_setter(:line_dash_pattern, :d,
                              HexaPDF::PDF::Content::LineDashPattern.new([5, 3], 2), [5, 3], 2)
      assert_gs_getter_setter(:line_dash_pattern, :d,
                              HexaPDF::PDF::Content::LineDashPattern.new([5, 3], 2),
                              HexaPDF::PDF::Content::LineDashPattern.new([5, 3], 2))
    end
  end

  describe "rendering_intent" do
    it "uses the gs_getter_setter implementation" do
      assert_gs_getter_setter(:rendering_intent, :ri, :Perceptual, :Perceptual)
      assert_gs_getter_setter(:rendering_intent, :ri, nil, nil)
    end
  end


  describe "private color_getter_setter" do
    def invoke(*params, &block)
      @canvas.send(:color_getter_setter, :stroke_color, params, :RG, :G, :K, :CS, :SCN, &block)
    end

    it "returns the current value when used with no argument or a block" do
      color = @canvas.graphics_state.stroke_color
      assert_equal(color, invoke)
      assert_equal(color, invoke(255) {})
    end

    it "returns the new value when used with a non-nil argument and no block" do
      assert_equal(HexaPDF::PDF::Content::ColorSpace::DeviceGray::DEFAULT.color(255), invoke(255))
    end

    it "doesn't add an operator if the value is equal to the current one" do
      @canvas.send(:gs_getter_setter, :line_width, :w,
                   @canvas.send(:gs_getter_setter, :line_width, :w, nil))
      assert_operators(@page.contents, [])
    end

    it "adds an unknown color space to the resource dictionary" do
      invoke(HexaPDF::PDF::Content::ColorSpace::Universal.new([:Pattern, :DeviceRGB]).color(:Name))
      assert_equal([:Pattern, :DeviceRGB], @page.resources.color_space(:CS1).definition)
    end

    it "is serialized correctly when no block is used" do
      invoke(102)
      invoke([102])
      invoke("6600FF")
      invoke(102, 0, 255)
      invoke(0, 20, 40, 80)
      invoke(HexaPDF::PDF::Content::ColorSpace::Universal.new([:Pattern]).color(:Name))
      assert_operators(@page.contents, [[:set_device_gray_stroking_color, [0.4]],
                                        [:set_device_rgb_stroking_color, [0.4, 0, 1]],
                                        [:set_device_cmyk_stroking_color, [0, 0.2, 0.4, 0.8]],
                                        [:set_stroking_color_space, [:CS1]],
                                        [:set_stroking_color, [:Name]]])
    end

    it "is serialized correctly when a block is used" do
      invoke(102) { invoke(255) }
      assert_operators(@page.contents, [[:save_graphics_state],
                                        [:set_device_gray_stroking_color, [0.4]],
                                        [:set_device_gray_stroking_color, [1.0]],
                                        [:restore_graphics_state]])
    end

    it "fails if a block is given without an argument" do
      assert_raises(HexaPDF::Error) { invoke {} }
    end

    it "fails if an unsupported number of component values is provided" do
      assert_raises(HexaPDF::Error) { invoke(5, 5) }
    end
  end

  # Asserts that the method +name+ invoked with +values+ invokes the #color_getter_setter helper
  # method with the +expected_values+ as arguments.
  def assert_color_getter_setter(name, expected_values, *values)
    args = nil
    block = nil
    @canvas.define_singleton_method(:color_getter_setter) {|*la, &lb| args = la; block = lb}
    @canvas.send(name, *values) {}
    @canvas.singleton_class.send(:remove_method, :color_getter_setter)
    assert_equal(expected_values, args)
    assert_kind_of(Proc, block)
  end

  describe "stroke_color" do
    it "uses the color_getter_setter implementation" do
      assert_color_getter_setter(:stroke_color, [:stroke_color, [255], :RG, :G, :K, :CS, :SCN], 255)
      assert_color_getter_setter(:stroke_color, [:stroke_color, [], :RG, :G, :K, :CS, :SCN])
    end
  end

  describe "fill_color" do
    it "uses the color_getter_setter implementation" do
      assert_color_getter_setter(:fill_color, [:fill_color, [255], :rg, :g, :k, :cs, :scn], 255)
      assert_color_getter_setter(:fill_color, [:fill_color, [], :rg, :g, :k, :cs, :scn])
    end
  end
end
