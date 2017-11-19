# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout'
require 'hexapdf/document'
require_relative "../content/common"

module TestTextLayouterHelpers
  def boxes(*dims)
    dims.map do |width, height|
      box = HexaPDF::Layout::InlineBox.create(width: width, height: height || 0) {}
      HexaPDF::Layout::TextLayouter::Box.new(box)
    end
  end

  def glue(width)
    HexaPDF::Layout::TextLayouter::Glue.new(HexaPDF::Layout::InlineBox.create(width: width) {})
  end

  def penalty(penalty, item = nil)
    if item
      HexaPDF::Layout::TextLayouter::Penalty.new(penalty, item.width, item: item)
    else
      HexaPDF::Layout::TextLayouter::Penalty.new(penalty)
    end
  end

  def assert_box(obj, item)
    assert_kind_of(HexaPDF::Layout::TextLayouter::Box, obj)
    if obj.item.kind_of?(HexaPDF::Layout::InlineBox)
      assert_same(item, obj.item)
    else
      assert_same(item.style, obj.item.style)
      assert_equal(item.items, obj.item.items)
    end
  end

  def assert_glue(obj, fragment)
    assert_kind_of(HexaPDF::Layout::TextLayouter::Glue, obj)
    assert_same(fragment.style, obj.item.style)
  end

  def assert_penalty(obj, penalty, item = nil)
    assert_kind_of(HexaPDF::Layout::TextLayouter::Penalty, obj)
    assert_equal(penalty, obj.penalty)
    if item
      assert_same(item.style, obj.item.style)
      assert_equal(item.items, obj.item.items)
    end
  end

  def assert_line_wrapping(result, widths)
    rest, lines = *result
    assert(rest.empty?)
    assert_equal(widths.length, lines.count)
    widths.each_with_index {|width, index| assert_equal(width, lines[index].width)}
  end
end

describe HexaPDF::Layout::TextLayouter::SimpleTextSegmentation do
  include TestTextLayouterHelpers

  before do
    @doc = HexaPDF::Document.new
    @font = @doc.fonts.add("Times")
    @obj = HexaPDF::Layout::TextLayouter::SimpleTextSegmentation
  end

  def setup_fragment(text, style = nil)
    if style
      HexaPDF::Layout::TextFragment.create(text, style)
    else
      HexaPDF::Layout::TextFragment.create(text, font: @font)
    end
  end

  it "handles InlineBox objects" do
    input = HexaPDF::Layout::InlineBox.create(width: 10, height: 10) { }
    result = @obj.call([input, input])
    assert_equal(2, result.size)
    assert_box(result[0], input)
    assert_box(result[1], input)
  end

  it "handles plain text" do
    frag = setup_fragment("Testtext")
    result = @obj.call([frag])
    assert_equal(1, result.size)
    assert_box(result[0], frag)
  end

  it "inserts a glue in places where spaces are" do
    frag = setup_fragment("This is a test")
    space = setup_fragment(" ", frag.style)

    result = @obj.call([frag])
    assert_equal(7, result.size)
    assert_glue(result[1], space)
    assert_glue(result[3], space)
    assert_glue(result[5], space)
  end

  it "inserts a glue representing 8 spaces when a tab is encountered" do
    frag = setup_fragment("This\ttest")
    tab = setup_fragment(" " * 8, frag.style)

    result = @obj.call([frag])
    assert_equal(3, result.size)
    assert_glue(result[1], tab)
  end

  it "insert a mandatory break when an Unicode line boundary characters is encountered" do
    frag = setup_fragment("A\rB\r\nC\nD\vE\fF\u{85}G\u{2029}H\u{2028}I")

    result = @obj.call([frag])
    assert_equal(17, result.size)
    [1, 3, 5, 7, 9, 11, 13].each do |index|
      assert_penalty(result[index],
                     HexaPDF::Layout::TextLayouter::Penalty::MandatoryParagraphBreak.penalty)
    end
    assert_penalty(result[15],
                   HexaPDF::Layout::TextLayouter::Penalty::MandatoryLineBreak.penalty)
  end

  it "insert a standard penalty after a hyphen" do
    frag = setup_fragment("hy-phen-a-tion - cool!")

    result = @obj.call([frag])
    assert_equal(12, result.size)
    [1, 3, 5, 9].each do |index|
      assert_penalty(result[index], HexaPDF::Layout::TextLayouter::Penalty::Standard.penalty)
    end
  end

  it "insert a neutral penalty in places where zero-width-spaces are" do
    frag = setup_fragment("zero\u{200B}width\u{200B}space")

    result = @obj.call([frag])
    assert_equal(5, result.size)
    assert_penalty(result[1], 0)
    assert_penalty(result[3], 0)
  end

  it "insert a special penalty for soft-hyphens" do
    frag = setup_fragment("soft\u{00AD}hyphened")
    hyphen = setup_fragment("-", frag.style)

    result = @obj.call([frag])
    assert_equal(3, result.size)
    assert_penalty(result[1], HexaPDF::Layout::TextLayouter::Penalty::Standard.penalty, hyphen)
  end

  it "insert a prohibited break penalty for non-breaking spaces" do
    frag = setup_fragment("soft\u{00A0}hyphened")
    space = setup_fragment(" ", frag.style)

    result = @obj.call([frag])
    assert_equal(3, result.size)
    assert_penalty(result[1], HexaPDF::Layout::TextLayouter::Penalty::ProhibitedBreak.penalty, space)
  end
end

# Common tests for fixed and variable width line wrapping. The including class needs to define a
# #call(items, width = 100) method with a default with of 100. The optional block is called after a
# line has been yielded by the line wrapping algorithm.
module CommonLineWrappingTests
  extend Minitest::Spec::DSL

  include TestTextLayouterHelpers

  it "breaks before a box if it doesn't fit onto the line anymore" do
    rest, lines = call(boxes(25, 50, 25, 10))
    assert_line_wrapping([rest, lines], [100, 10])
    lines.each {|line| line.items.each {|item| assert_kind_of(HexaPDF::Layout::InlineBox, item)}}
  end

  it "breaks at a glue and ignores it if it doesn't fit onto the line anymore" do
    result = call(boxes(90) + [glue(20)] + boxes(20))
    assert_line_wrapping(result, [90, 20])
  end

  it "handles spaces at the start of a line" do
    rest, lines = call([glue(15)] + boxes(25, 50))
    assert_line_wrapping([rest, lines], [75])
    assert_equal(25, lines[0].items[0].width)
  end

  it "handles spaces at the end of a line" do
    rest, lines = call(boxes(20, 50) + [glue(10), glue(10)] + boxes(20))
    assert_line_wrapping([rest, lines], [70, 20])
    assert_equal(50, lines[0].items[-1].width)
  end

  it "handles spaces at the end of a line before a mandatory break" do
    rest, lines = call(boxes(20, 50) + [glue(10), penalty(-5000)] + boxes(20))
    assert_line_wrapping([rest, lines], [70, 20])
    assert_equal(50, lines[0].items[-1].width)
  end

  it "handles multiple glue items after another" do
    result = call(boxes(20) + [glue(20), glue(20)] + boxes(20, 50, 20))
    assert_line_wrapping(result, [80, 70])
  end

  it "handles mandatory line breaks" do
    rest, lines = call(boxes(20) + [penalty(-5000)] + boxes(20))
    assert_line_wrapping([rest, lines], [20, 20])
    assert(lines[0].ignore_justification?)
  end

  it "handles breaking at penalties with zero width" do
    result = call(boxes(80) + [penalty(0)] + boxes(10) + [penalty(0)] + boxes(20))
    assert_line_wrapping(result, [90, 20])
  end

  it "handles breaking at penalties with non-zero width if they fit on the line" do
    pitem = penalty(0, boxes(20).first)
    rest, lines = call(boxes(20) + [pitem] + boxes(50) + [glue(10), pitem] + boxes(30))
    assert_line_wrapping([rest, lines], [100, 30])
    assert_same(pitem.item, lines[0].items[-1])
  end

  it "handles penalties with non-zero width if they don't fit on the line" do
    item = boxes(20).first
    result = call(boxes(70) + [glue(10)] + boxes(10) + [penalty(0, item)] + boxes(30))
    assert_line_wrapping(result, [70, 40])
  end

  it "handles prohibited breakpoint penalties with zero width" do
    result = call(boxes(70) + [glue(10)] + boxes(10) + [penalty(5000)] + boxes(30))
    assert_line_wrapping(result, [70, 40])
  end

  it "handles prohibited breakpoint penalties with non-zero width" do
    item = boxes(20).first
    result = call(boxes(70) + [glue(10)] + boxes(10) + [penalty(5000, item)] + boxes(30))
    assert_line_wrapping(result, [70, 60])
  end

  it "stops when nil is returned by the block: last item is a box" do
    done = false
    rest, lines = call(boxes(20, 20, 20), 20) { done ? nil : done = true }
    assert_equal(2, rest.count)
    assert_equal(2, lines.count)
  end

  it "stops when nil is returned by the block: last item is a glue" do
    done = false
    items = boxes(20, 15, 20).insert(-2, glue(10))
    rest, = call(items, 20) { done ? nil : done = true }
    assert_equal(3, rest.count)
    assert_equal(15, rest[0].width)
  end

  it "stops when nil is returned by the block: last item is a mandatory break penalty" do
    items = boxes(20, 20).insert(-2, penalty(-5000))
    rest, = call(items, 20) { nil }
    assert_equal(3, rest.count)
  end

  it "stops when nil is returned by the block: works for the last line" do
    done = false
    rest, lines = call(boxes(20, 20), 20) { done ? nil : done = true }
    assert_equal(1, rest.count)
    assert_equal(2, lines.count)
  end

end

describe HexaPDF::Layout::TextLayouter::SimpleLineWrapping do
  before do
    @obj = HexaPDF::Layout::TextLayouter::SimpleLineWrapping
  end

  describe "fixed width wrapping" do
    include CommonLineWrappingTests

    def call(items, width = 100, &block)
      lines = []
      block ||= proc { true }
      rest = @obj.call(items, proc { width }) {|line, item| lines << line; block.call(line, item) }
      [rest, lines]
    end
  end

  describe "variable width wrapping" do
    include CommonLineWrappingTests

    def call(items, width = 100, &block)
      lines = []
      block ||= proc { true }
      rest = @obj.call(items, proc {|_| width }) {|line, i| lines << line; block.call(line, i) }
      [rest, lines]
    end

    it "handles changing widths" do
      height = 0
      width_block = lambda do |line_height|
        case height + line_height
        when 0..10 then 60
        when 11..20 then 40
        when 21..30 then 20
        else 60
        end
      end
      lines = []
      rest = @obj.call(boxes([20, 10], [10, 10], [20, 15], [40, 10]), width_block) do |line|
        height += line.height
        lines << line
        true
      end
      assert(rest.empty?)
      assert_equal(3, lines.size)
      assert_equal(30, lines[0].width)
      assert_equal(20, lines[1].width)
      assert_equal(40, lines[2].width)
    end

    it "handles changing widths when breaking on a penalty" do
      height = 0
      width_block = lambda do |line_height|
        case height + line_height
        when 0..10 then 80
        else 50
        end
      end
      lines = []
      item = HexaPDF::Layout::InlineBox.create(width: 20, height: 10) {}
      items = boxes([20, 10]) + [penalty(0, item)] + boxes([40, 15])
      rest = @obj.call(items, width_block) do |line|
        height += line.height
        lines << line
        true
      end
      assert(rest.empty?)
      assert_equal(2, lines.size)
      assert_equal(40, lines[0].width)
      assert_equal(40, lines[1].width)
      assert_equal(25, height)
    end
  end
end

describe HexaPDF::Layout::TextLayouter do
  include TestTextLayouterHelpers

  before do
    @doc = HexaPDF::Document.new
    @font = @doc.fonts.add("Times")
    @style = HexaPDF::Layout::Style.new(font: @font)
  end

  it "creates an instance from text and options" do
    layouter = HexaPDF::Layout::TextLayouter.create("T", font: @font, width: 100, height: 100)
    assert_equal(1, layouter.items.length)
    assert_equal(@font.decode_utf8("T"), layouter.items[0].item.items)
  end

  describe "initialize" do
    it "can use a Style object" do
      style = HexaPDF::Layout::Style.new(font: @font, font_size: 20)
      layouter = HexaPDF::Layout::TextLayouter.new(items: [], width: 10, style: style)
      assert_equal(20, layouter.style.font_size)
    end

    it "can use a style options" do
      layouter = HexaPDF::Layout::TextLayouter.new(items: [], width: 10, style:
                                                   {font: @font, font_size: 20})
      assert_equal(20, layouter.style.font_size)
    end
  end

  it "doesn't run the text segmentation algorithm on already segmented items" do
    item = HexaPDF::Layout::InlineBox.create(width: 20) {}
    layouter = HexaPDF::Layout::TextLayouter.new(items: [item], width: 100, height: 100)
    items = layouter.items
    assert_equal(1, items.length)
    assert_box(items[0], item)

    layouter.items = items
    assert_same(items, layouter.items)
  end

  describe "fit" do
    it "handles text indentation" do
      items = boxes([20, 20], [20, 20], [20, 20]) +
        [HexaPDF::Layout::TextLayouter::Penalty::MandatoryParagraphBreak] +
        boxes([40, 20]) + [glue(20)] +
        boxes(*([[20, 20]] * 4)) + [HexaPDF::Layout::TextLayouter::Penalty::MandatoryLineBreak] +
        boxes(*([[20, 20]] * 4))
      @style.text_indent = 20

      [60, proc { 60 }].each do |width|
        layouter = HexaPDF::Layout::TextLayouter.new(items: items, width: width, style: @style)
        rest, reason = layouter.fit
        assert_equal([40, 20, 40, 60, 20, 60, 20], layouter.lines.map(&:width))
        assert_equal([20, 0, 20, 0, 0, 0, 0], layouter.lines.map(&:x_offset))
        assert(rest.empty?)
        assert_equal(:success, reason)
      end
    end

    it "fits using unlimited height" do
      layouter = HexaPDF::Layout::TextLayouter.new(items: boxes(*([[20, 20]] * 100)), width: 20,
                                                   style: @style)
      rest, reason = layouter.fit
      assert(rest.empty?)
      assert_equal(:success, reason)
      assert_equal(20 * 100, layouter.actual_height)
    end

    it "fits using a limited height" do
      layouter = HexaPDF::Layout::TextLayouter.new(items: boxes(*([[20, 20]] * 100)), width: 20,
                                                   height: 100, style: @style)
      rest, reason = layouter.fit
      assert_equal(95, rest.count)
      assert_equal(:height, reason)
      assert_equal(100, layouter.actual_height)
    end

    it "takes line spacing into account when calculating the height" do
      layouter = HexaPDF::Layout::TextLayouter.new(items: boxes(*([[20, 20]] * 5)), width: 20,
                                                   style: @style)
      layouter.style.line_spacing = :double
      rest, reason = layouter.fit
      assert(rest.empty?)
      assert_equal(:success, reason)
      assert_equal(20 * (5 + 4), layouter.actual_height)
    end

    it "handles empty lines" do
      items = boxes([20, 20]) + [penalty(-5000)] + boxes([30, 20]) + [penalty(-5000)] * 2 +
        boxes([20, 20]) + [penalty(-5000)] * 2
      layouter = HexaPDF::Layout::TextLayouter.new(items: items, width: 30, style: @style)
      rest, reason = layouter.fit
      assert(rest.empty?)
      assert_equal(:success, reason)
      assert_equal(5, layouter.lines.count)
      assert_equal(20 + 20 + 9 + 20 + 9, layouter.actual_height)
    end

    describe "fixed width" do
      it "stops if an item is wider than the available width, with unlimited height" do
        layouter = HexaPDF::Layout::TextLayouter.new(items: boxes([20, 20], [50, 20]), width: 30,
                                                     style: @style)
        rest, reason = layouter.fit
        assert_equal(1, rest.count)
        assert_equal(:box, reason)
        assert_equal(20, layouter.actual_height)
      end

      it "stops if a box item is wider than the available width, with limited height" do
        layouter = HexaPDF::Layout::TextLayouter.new(items: boxes([20, 20], [50, 20]), width: 30,
                                                     height: 100, style: @style)
        rest, reason = layouter.fit
        assert_equal(1, rest.count)
        assert_equal(:box, reason)
        assert_equal(20, layouter.actual_height)
      end
    end

    describe "variable width with limited height" do
      it "searches for a vertical offset if the first item is wider than the available width" do
        width_block = lambda do |height, _|
          case height
          when 0..20 then 10
          else 40
          end
        end
        layouter = HexaPDF::Layout::TextLayouter.new(items: boxes([20, 18]), width: width_block,
                                                     height: 100, style: @style)
        rest, reason = layouter.fit
        assert(rest.empty?)
        assert_equal(:success, reason)
        assert_equal(1, layouter.lines.count)
        assert_equal(24, layouter.lines[0].y_offset)
        assert_equal(42, layouter.actual_height)
      end

      it "searches for a vertical offset if an item is wider than the available width" do
        width_block = lambda do |height, line_height|
          if (40..60).cover?(height) || (40..60).cover?(height + line_height)
            10
          else
            40
          end
        end
        layouter = HexaPDF::Layout::TextLayouter.new(items: boxes(*([[20, 18]] * 7)),
                                                     width: width_block, height: 100, style: @style)
        rest, reason = layouter.fit
        assert_equal(1, rest.count)
        assert_equal(:height, reason)
        assert_equal(3, layouter.lines.count)
        assert_equal(0, layouter.lines[0].y_offset)
        assert_equal(18, layouter.lines[1].y_offset)
        assert_equal(48, layouter.lines[2].y_offset)
        assert_equal(84, layouter.actual_height)
      end
    end

    it "breaks a text fragment into parts if it is wider than the available width" do
      [100, nil].each do |height|
        str = " Thisisaverylongstring"
        frag = HexaPDF::Layout::TextFragment.create(str, font: @font)
        layouter = HexaPDF::Layout::TextLayouter.new(items: [frag], width: 20, height: height,
                                                     style: @style)
        rest, reason = layouter.fit
        assert(rest.empty?)
        assert_equal(:success, reason)
        assert_equal(str.strip.length, layouter.lines.sum {|l| l.items.sum {|i| i.items.count}})
        assert_equal(45, layouter.actual_height)

        layouter = HexaPDF::Layout::TextLayouter.new(items: [frag], width: 1, height: height,
                                                     style: @style)
        rest, reason = layouter.fit
        assert_equal(str.strip.length, rest.count)
        assert_equal(:box, reason)
      end
    end

    it "post-processes lines for justification if needed" do
      frag10 = HexaPDF::Layout::TextFragment.create(" ", font: @font)
      frag10.items.freeze
      frag10b = HexaPDF::Layout::TextLayouter::Box.new(frag10)
      frag20 = HexaPDF::Layout::TextFragment.create(" ", font: @font, font_size: 20)
      frag20b = HexaPDF::Layout::TextLayouter::Box.new(frag20)
      items = boxes(20, 20, 20, 20, 30).insert(1, frag10b).insert(3, frag20b).insert(5, frag10b)
      # Width of spaces: 2.5 * 2 + 5 = 10  (from AFM file, adjusted for font size)
      # Line width: 20 * 4 + width_of_spaces = 90
      # Missing width: 100 - 90 = 10
      # -> Each space must be doubled!

      layouter = HexaPDF::Layout::TextLayouter.new(items: items, width: 100)
      layouter.style.align = :justify
      rest, reason = layouter.fit
      assert(rest.empty?)
      assert_equal(:success, reason)
      assert_equal(9, layouter.lines[0].items.count)
      assert_in_delta(100, layouter.lines[0].width)
      assert_equal(-250, layouter.lines[0].items[1].items[0])
      assert_equal(-250, layouter.lines[0].items[4].items[0])
      assert_equal(-250, layouter.lines[0].items[6].items[0])
      assert_equal(30, layouter.lines[1].width)
    end

    it "applies the optional horizontal offsets if set" do
      x_offsets = lambda {|height, line_height| height + line_height}
      layouter = HexaPDF::Layout::TextLayouter.new(items: boxes(*([[20, 10]] * 7)), width: 60,
                                                   x_offsets: x_offsets, height: 100, style: @style)
      rest, reason = layouter.fit
      assert(rest.empty?)
      assert_equal(:success, reason)
      assert_equal(30, layouter.actual_height)
      assert_equal(10, layouter.lines[0].x_offset)
      assert_equal(20, layouter.lines[1].x_offset)
      assert_equal(30, layouter.lines[2].x_offset)
    end
  end

  describe "draw" do
    def assert_positions(content, positions)
      processor = TestHelper::OperatorRecorder.new
      HexaPDF::Content::Parser.new.parse(content, processor)
      result = processor.recorded_ops
      result.select! {|name, _| name == :set_text_matrix}.map! {|_, ops| ops[-2, 2]}
      positions.each_with_index do |(x, y), index|
        assert_in_delta(x, result[index][0], 0.00001)
        assert_in_delta(y, result[index][1], 0.00001)
      end
    end

    before do
      @frag = HexaPDF::Layout::TextFragment.create("This is some more text.\n" \
                                                   "This is some more text.", font: @font)
      @width = HexaPDF::Layout::TextFragment.create("This is some   ", font: @font).width
      @layouter = HexaPDF::Layout::TextLayouter.new(items: [@frag], width: @width)
      @canvas = @doc.pages.add.canvas

      @line1w = HexaPDF::Layout::TextFragment.create("This is some", font: @font).width
      @line2w = HexaPDF::Layout::TextFragment.create("more text.", font: @font).width
    end

    it "can horizontally align the contents to the left" do
      top = 100
      @layouter.style.align = :left
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, top - @frag.y_max],
                        [5, top - @frag.y_max - @frag.height],
                        [5, top - @frag.y_max - @frag.height * 2],
                        [5, top - @frag.y_max - @frag.height * 3]])
    end

    it "can horizontally align the contents to the center" do
      top = 100
      @layouter.style.align = :center
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5 + (@width - @line1w) / 2, top - @frag.y_max],
                        [5 + (@width - @line2w) / 2, top - @frag.y_max - @frag.height],
                        [5 + (@width - @line1w) / 2, top - @frag.y_max - @frag.height * 2],
                        [5 + (@width - @line2w) / 2, top - @frag.y_max - @frag.height * 3]])
    end

    it "can horizontally align the contents to the right" do
      top = 100
      @layouter.style.align = :right
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5 + @width - @line1w, top - @frag.y_max],
                        [5 + @width - @line2w, top - @frag.y_max - @frag.height],
                        [5 + @width - @line1w, top - @frag.y_max - @frag.height * 2],
                        [5 + @width - @line2w, top - @frag.y_max - @frag.height * 3]])
    end

    it "can justify the contents" do
      top = 100
      @layouter.style.align = :justify
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, top - @frag.y_max],
                        [5, top - @frag.y_max - @frag.height],
                        [5, top - @frag.y_max - @frag.height * 2],
                        [5, top - @frag.y_max - @frag.height * 3]])
      assert_in_delta(@width, @layouter.lines[0].width, 0.0001)
      assert_in_delta(@width, @layouter.lines[2].width, 0.0001)
    end

    it "doesn't justify lines ending in a mandatory break or the last line" do
      @layouter.style.align = :justify
      @layouter.draw(@canvas, 5, 100)
      assert_equal(@line2w, @layouter.lines[1].width, 0.0001)
      assert_equal(@line2w, @layouter.lines[3].width, 0.0001)
    end

    it "can vertically align the contents in the center" do
      top = 100
      @layouter = HexaPDF::Layout::TextLayouter.new(items: [@frag], width: @width, height: top)
      @layouter.style.valign = :center

      @layouter.fit
      initial_baseline = top - ((top - @layouter.actual_height) / 2) - @frag.y_max
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, initial_baseline],
                        [5, initial_baseline - @frag.height],
                        [5, initial_baseline - @frag.height * 2],
                        [5, initial_baseline - @frag.height * 3]])
    end

    it "can vertically align the contents to the bottom" do
      top = 100
      @layouter = HexaPDF::Layout::TextLayouter.new(items: [@frag], width: @width, height: top)
      @layouter.style.valign = :bottom

      @layouter.fit
      initial_baseline = @layouter.actual_height - @frag.y_max
      @layouter.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, initial_baseline],
                        [5, initial_baseline - @frag.height],
                        [5, initial_baseline - @frag.height * 2],
                        [5, initial_baseline - @frag.height * 3]])
    end

    it "raises an error if vertical alignment is :center/:bottom and an unlimited height is used" do
      @layouter = HexaPDF::Layout::TextLayouter.new(items: [@frag], width: @width)
      assert_raises(HexaPDF::Error) do
        @layouter.style.valign = :center
        @layouter.draw(@canvas, 0, 0)
      end
      assert_raises(HexaPDF::Error) do
        @layouter.style.valign = :bottom
        @layouter.draw(@canvas, 0, 0)
      end
    end

    it "makes sure that text fragments don't pollute the graphics state for inline boxes" do
      frag = HexaPDF::Layout::TextFragment.create("Demo", font: @font)
      inline_box = HexaPDF::Layout::InlineBox.create(width: 10, height: 10) {|c, _| c.text("A")}
      layouter = HexaPDF::Layout::TextLayouter.new(items: [frag, inline_box], width: 200)
      assert_raises(HexaPDF::Error) { layouter.draw(@canvas, 0, 0) }
    end

    it "doesn't do unnecessary work for placeholder boxes" do
      box1 = HexaPDF::Layout::InlineBox.create(width: 10, height: 20)
      box2 = HexaPDF::Layout::InlineBox.create(width: 30, height: 40) { @canvas.line_width(2) }
      layouter = HexaPDF::Layout::TextLayouter.new(items: [box1, box2], width: 200)
      layouter.draw(@canvas, 0, 0)
      assert_operators(@canvas.contents, [[:save_graphics_state],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:concatenate_matrix, [1, 0, 0, 1, 10, -40]],
                                          [:set_line_width, [2]],
                                          [:restore_graphics_state],
                                          [:save_graphics_state],
                                          [:restore_graphics_state]])
    end
  end
end
