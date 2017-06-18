# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout'
require 'hexapdf/document'
require_relative "../content/common"

module TestTextBox
  def boxes(*dims)
    dims.map do |width, height|
      box = HexaPDF::Layout::InlineBox.new(width, height || 0) {}
      HexaPDF::Layout::TextBox::Box.new(box)
    end
  end

  def glue(width)
    HexaPDF::Layout::TextBox::Glue.new(HexaPDF::Layout::InlineBox.new(width, 0) {})
  end

  def penalty(penalty, item = nil)
    if item
      HexaPDF::Layout::TextBox::Penalty.new(penalty, item.width, item: item)
    else
      HexaPDF::Layout::TextBox::Penalty.new(penalty)
    end
  end

  def assert_box(obj, item)
    assert_kind_of(HexaPDF::Layout::TextBox::Box, obj)
    if obj.item.kind_of?(HexaPDF::Layout::InlineBox)
      assert_same(item, obj.item)
    else
      assert_same(item.style, obj.item.style)
      assert_equal(item.items, obj.item.items)
    end
  end

  def assert_glue(obj, fragment)
    assert_kind_of(HexaPDF::Layout::TextBox::Glue, obj)
    assert_same(fragment.style, obj.item.style)
  end

  def assert_penalty(obj, penalty, item = nil)
    assert_kind_of(HexaPDF::Layout::TextBox::Penalty, obj)
    assert_equal(penalty, obj.penalty)
    if item
      assert_same(item.style, obj.item.style)
      assert_equal(item.items, obj.item.items)
    end
  end
end

describe HexaPDF::Layout::TextBox::SimpleTextSegmentation do
  include TestTextBox

  before do
    @doc = HexaPDF::Document.new
    @font = @doc.fonts.load("Times")
    @obj = HexaPDF::Layout::TextBox::SimpleTextSegmentation
  end

  def setup_fragment(text, style = nil)
    if style
      HexaPDF::Layout::TextFragment.new(items: style.font.decode_utf8(text), style: style)
    else
      HexaPDF::Layout::TextFragment.create(text, font: @font)
    end
  end

  it "handles InlineBox objects" do
    input = HexaPDF::Layout::InlineBox.new(10, 10) { }
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
    frag = setup_fragment("A\rB\r\nC\nD\vE\fF\u{85}G\u{2028}H\u{2029}I")

    result = @obj.call([frag])
    assert_equal(17, result.size)
    [1, 3, 5, 7, 9, 11, 13, 15].each do |index|
      assert_penalty(result[index], HexaPDF::Layout::TextBox::Penalty::MandatoryBreak.penalty)
    end
  end

  it "insert a standard penalty after a hyphen" do
    frag = setup_fragment("hy-phen-a-tion - cool!")

    result = @obj.call([frag])
    assert_equal(12, result.size)
    [1, 3, 5, 9].each do |index|
      assert_penalty(result[index], HexaPDF::Layout::TextBox::Penalty::Standard.penalty)
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
    assert_penalty(result[1], 50, hyphen)
  end
end

describe HexaPDF::Layout::TextBox::SimpleLineWrapping do
  include TestTextBox

  before do
    @obj = HexaPDF::Layout::TextBox::SimpleLineWrapping
  end

  def call(items, width = 100)
    lines = []
    rest = @obj.call(items, width) {|line, _| lines << line; true }
    [rest, lines]
  end

  it "breaks before a box if it doesn't fit onto the line anymore" do
    rest, lines = call(boxes(25, 50, 25, 10))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    lines.each {|line| line.items.each {|item| assert_kind_of(HexaPDF::Layout::InlineBox, item)}}
    assert_equal(100, lines[0].width)
    assert_equal(10, lines[1].width)
  end

  it "breaks at a glue and ignores it if it doesn't fit onto the line anymore" do
    rest, lines = call(boxes(90, 20).insert(-2, glue(20)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(90, lines[0].width)
    assert_equal(20, lines[1].width)
  end

  it "handles spaces at the start of a line" do
    rest, lines = call(boxes(25, 50).unshift(glue(15)))
    assert(rest.empty?)
    assert_equal(1, lines.count)
    assert_equal(75, lines[0].width)
    assert_equal(25, lines[0].items[0].width)
  end

  it "handles spaces at the end of a line" do
    rest, lines = call(boxes(20, 50, 20).insert(-2, glue(10)).insert(-2, glue(10)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(70, lines[0].width)
    assert_equal(20, lines[1].width)
    assert_equal(50, lines[0].items[-1].width)
  end

  it "handles spaces at the end of a line before a mandatory break" do
    rest, lines = call(boxes(20, 50, 20).insert(-2, glue(10)).insert(-2, penalty(-5000)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(70, lines[0].width)
    assert_equal(20, lines[1].width)
    assert_equal(50, lines[0].items[-1].width)
  end

  it "handles multiple glue items after another" do
    rest, lines = call(boxes(20, 20, 50, 20).insert(1, glue(20)).insert(1, glue(20)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(80, lines[0].width)
    assert_equal(70, lines[1].width)
  end

  it "handles mandatory line breaks" do
    rest, lines = call(boxes(20, 20).insert(-2, penalty(-5000)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(20, lines[0].width)
    assert_equal(20, lines[1].width)
    assert(lines[0].ignore_justification?)
  end

  it "handles breaking at penalties with zero width" do
    rest, lines = call(boxes(80, 10, 20).insert(1, penalty(0)).insert(-2, penalty(0)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(90, lines[0].width)
    assert_equal(20, lines[1].width)
  end

  it "handles breaking at penalties with non-zero width" do
    item = HexaPDF::Layout::InlineBox.new(20, 0) {}
    rest, lines = call(boxes(20, 60, 30).insert(1, penalty(0, item)).insert(-2, penalty(0, item)))
    assert(rest.empty?)
    assert_equal(2, lines.count)
    assert_equal(100, lines[0].width)
    assert_equal(30, lines[1].width)
    assert_same(item, lines[0].items[-1])
  end

  describe "halts processing if nil/false is returned by the block" do
    it "works when the last item on a line is a box" do
      lines = []
      rest = @obj.call(boxes(20, 20, 20), 20) {|line| lines.count > 0 ? nil : (lines << line; 20)}
      assert_equal(2, rest.count)
      assert_equal(1, lines.count)
    end

    it "works when the last item on a line is a glue" do
      done = false
      items = boxes(20, 15, 20).insert(-2, glue(10))
      rest = @obj.call(items, 20) { done ? nil : (done = true; 20) }
      assert_equal(3, rest.count)
      assert_equal(15, rest[0].width)
    end

    it "works when the last item on a line is a mandatory break penalty" do
      items = boxes(20, 20).insert(-2, penalty(-5000))
      rest = @obj.call(items, 20) { nil }
      assert_equal(3, rest.count)
    end

    it "works for the last line" do
      lines = []
      rest = @obj.call(boxes(20, 20), 20) {|line| lines.count > 0 ? nil : (lines << line; 20)}
      assert_equal(1, rest.count)
      assert_equal(1, lines.count)
    end
  end
end

describe HexaPDF::Layout::TextBox do
  include TestTextBox

  before do
    @doc = HexaPDF::Document.new
    @font = @doc.fonts.load("Times")
    @style = HexaPDF::Layout::Style.new(font: @font)
  end

  it "creates an instance from text and options" do
    box = HexaPDF::Layout::TextBox.create("T", font: @font, width: 100, height: 100)
    assert_equal(1, box.items.length)
    assert_equal(@font.decode_utf8("T"), box.items[0].item.items)
  end

  it "doesn't run the text segmentation algorithm on already segmented items" do
    item = HexaPDF::Layout::InlineBox.new(20, 0) {}
    box = HexaPDF::Layout::TextBox.new(items: [item], width: 100, height: 100)
    items = box.items
    assert_equal(1, items.length)
    assert_box(items[0], item)

    box.items = items
    assert_same(items, box.items)
  end

  describe "fit" do
    it "handles text indentation" do
      box = HexaPDF::Layout::TextBox.new(items: boxes([20, 20], [20, 20], [20, 20]), width: 60,
                                         style: @style)
      box.style.text_indent = 20
      rest, height = box.fit
      assert_equal(60, box.lines[0].width)
      assert_equal(20, box.lines[1].width)
      assert(rest.empty?)
      assert_equal(40, height)
    end

    it "fits using unlimited height" do
      box = HexaPDF::Layout::TextBox.new(items: boxes(*([[20, 20]] * 100)), width: 20,
                                         style: @style)
      rest, height = box.fit
      assert(rest.empty?)
      assert_equal(20 * 100, height)
    end

    it "fits using a limited height" do
      box = HexaPDF::Layout::TextBox.new(items: boxes(*([[20, 20]] * 100)), width: 20, height: 100,
                                         style: @style)
      rest, height = box.fit
      assert_equal(95, rest.count)
      assert_equal(100, height)
    end

    it "takes line spacing into account when calculating the height" do
      box = HexaPDF::Layout::TextBox.new(items: boxes(*([[20, 20]] * 5)), width: 20, style: @style)
      box.style.line_spacing = :double
      rest, height = box.fit
      assert(rest.empty?)
      assert_equal(20 * (5 + 4), height)
    end

    it "handles empty lines" do
      items = boxes([20, 20]) + [penalty(-5000)] + boxes([30, 20]) + [penalty(-5000)] * 2 +
        boxes([20, 20]) + [penalty(-5000)] * 2
      box = HexaPDF::Layout::TextBox.new(items: items, width: 30, style: @style)
      rest, height = box.fit
      assert(rest.empty?)
      assert_equal(5, box.lines.count)
      assert_equal(20 + 20 + 9 + 20 + 9, height)
    end

    it "stops if an item is wider than the available width, with unlimited height" do
      box = HexaPDF::Layout::TextBox.new(items: boxes([20, 20], [50, 20]), width: 30, style: @style)
      rest, height = box.fit
      assert_equal(1, rest.count)
      assert_equal(20, height)
    end

    it "stops if an item is wider than the available width, with limited height" do
      box = HexaPDF::Layout::TextBox.new(items: boxes([20, 20], [50, 20]), width: 30, height: 100,
                                         style: @style)
      rest, height = box.fit
      assert_equal(1, rest.count)
      assert_equal(20, height)
    end

    it "post-processes lines for justification if needed" do
      frag10 = HexaPDF::Layout::TextFragment.create(" ", font: @font)
      frag10.items.freeze
      frag10b = HexaPDF::Layout::TextBox::Box.new(frag10)
      frag20 = HexaPDF::Layout::TextFragment.create(" ", font: @font, font_size: 20)
      frag20b = HexaPDF::Layout::TextBox::Box.new(frag20)
      items = boxes(20, 20, 20, 20, 30).insert(1, frag10b).insert(3, frag20b).insert(5, frag10b)
      # Width of spaces: 2.5 * 2 + 5 = 10  (from AFM file, adjusted for font size)
      # Line width: 20 * 4 + width_of_spaces = 90
      # Missing width: 100 - 90 = 10
      # -> Each space must be doubled!

      box = HexaPDF::Layout::TextBox.new(items: items, width: 100)
      box.style.align = :justify
      rest, _height = box.fit
      assert(rest.empty?)
      assert_equal(9, box.lines[0].items.count)
      assert_in_delta(100, box.lines[0].width)
      assert_equal(-250, box.lines[0].items[1].items[0])
      assert_equal(-250, box.lines[0].items[4].items[0])
      assert_equal(-250, box.lines[0].items[6].items[0])
      assert_equal(30, box.lines[1].width)
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
      @box =  HexaPDF::Layout::TextBox.new(items: [@frag], width: @width)
      @canvas = @doc.pages.add.canvas

      @line1w = HexaPDF::Layout::TextFragment.create("This is some", font: @font).width
      @line2w = HexaPDF::Layout::TextFragment.create("more text.", font: @font).width
    end

    it "can horizontally align the contents to the left" do
      top = 100
      @box.style.align = :left
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, top - @frag.y_max],
                        [5, top - @frag.y_max - @frag.height],
                        [5, top - @frag.y_max - @frag.height * 2],
                        [5, top - @frag.y_max - @frag.height * 3]])
    end

    it "can horizontally align the contents to the center" do
      top = 100
      @box.style.align = :center
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5 + (@width - @line1w) / 2, top - @frag.y_max],
                        [5 + (@width - @line2w) / 2, top - @frag.y_max - @frag.height],
                        [5 + (@width - @line1w) / 2, top - @frag.y_max - @frag.height * 2],
                        [5 + (@width - @line2w) / 2, top - @frag.y_max - @frag.height * 3]])
    end

    it "can horizontally align the contents to the right" do
      top = 100
      @box.style.align = :right
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5 + @width - @line1w, top - @frag.y_max],
                        [5 + @width - @line2w, top - @frag.y_max - @frag.height],
                        [5 + @width - @line1w, top - @frag.y_max - @frag.height * 2],
                        [5 + @width - @line2w, top - @frag.y_max - @frag.height * 3]])
    end

    it "can justify the contents" do
      top = 100
      @box.style.align = :justify
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, top - @frag.y_max],
                        [5, top - @frag.y_max - @frag.height],
                        [5, top - @frag.y_max - @frag.height * 2],
                        [5, top - @frag.y_max - @frag.height * 3]])
      assert_in_delta(@width, @box.lines[0].width, 0.0001)
      assert_in_delta(@width, @box.lines[2].width, 0.0001)
    end

    it "doesn't justify lines ending in a mandatory break or the last line" do
      @box.style.align = :justify
      @box.draw(@canvas, 5, 100)
      assert_equal(@line2w, @box.lines[1].width, 0.0001)
      assert_equal(@line2w, @box.lines[3].width, 0.0001)
    end

    it "can vertically align the contents in the center" do
      top = 100
      @box = HexaPDF::Layout::TextBox.new(items: [@frag], width: @width, height: top)
      @box.style.valign = :center

      _, height = @box.fit
      initial_baseline = top - ((top - height) / 2) - @frag.y_max
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, initial_baseline],
                        [5, initial_baseline - @frag.height],
                        [5, initial_baseline - @frag.height * 2],
                        [5, initial_baseline - @frag.height * 3]])
    end

    it "can vertically align the contents to the bottom" do
      top = 100
      @box = HexaPDF::Layout::TextBox.new(items: [@frag], width: @width, height: top)
      @box.style.valign = :bottom

      _, height = @box.fit
      initial_baseline = height - @frag.y_max
      @box.draw(@canvas, 5, top)
      assert_positions(@canvas.contents,
                       [[5, initial_baseline],
                        [5, initial_baseline - @frag.height],
                        [5, initial_baseline - @frag.height * 2],
                        [5, initial_baseline - @frag.height * 3]])
    end

    it "raises an error if vertical alignment is :center/:bottom and an unlimited height is used" do
      @box = HexaPDF::Layout::TextBox.new(items: [@frag], width: @width)
      assert_raises(HexaPDF::Error) do
        @box.style.valign = :center
        @box.draw(@canvas, 0, 0)
      end
      assert_raises(HexaPDF::Error) do
        @box.style.valign = :bottom
        @box.draw(@canvas, 0, 0)
      end
    end
  end
end
