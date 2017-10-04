# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#++

require 'hexapdf/error'
require 'hexapdf/layout/text_fragment'
require 'hexapdf/layout/inline_box'
require 'hexapdf/layout/line'
require 'hexapdf/layout/numeric_refinements'

module HexaPDF
  module Layout

    # Arranges text and inline objects into lines according to a specified width and height as well
    # as other options.
    #
    # == Features
    #
    # * Existing line breaking characters inside of TextFragment objects are respected when fitting
    #   text. If this is not wanted, they have to be removed beforehand.
    #
    # * The first line may be indented by setting Style#text_indent which may also be negative.
    #
    # == Layouting Algorithm
    #
    # Laying out text consists of two phases:
    #
    # 1. The items are broken into pieces which are wrapped into Box, Glue or Penalty objects.
    #    Additional Penalty objects marking line breaking opportunities are inserted where needed.
    #    This step is done by the SimpleTextSegmentation module.
    #
    # 2. The pieces are arranged into lines using a very simple algorithm that just puts the maximum
    #    number of consecutive pieces into each line. This step is done by the SimpleLineWrapping
    #    module.
    class TextLayouter

      using NumericRefinements

      # Used for layouting. Describes an item with a fixed width, like an InlineBox or TextFragment.
      class Box

        # The wrapped item.
        attr_reader :item

        # Creates a new Box for the item.
        def initialize(item)
          @item = item
        end

        # The width of the item.
        def width
          @item.width
        end

        # The height of the item.
        def height
          @item.height
        end

        # Returns :box.
        def type
          :box
        end

      end

      # Used for layouting. Describes a glue item, i.e. an item describing white space that could
      # potentially be shrunk or stretched.
      class Glue

        # The wrapped item.
        attr_reader :item

        # The amount by which the glue could be stretched.
        attr_reader :stretchability

        # The amount by which the glue could be shrunk.
        attr_reader :shrinkability

        # Creates a new Glue for the item.
        def initialize(item, stretchability = item.width / 2, shrinkability = item.width / 3)
          @item = item
          @stretchability = stretchability
          @shrinkability = shrinkability
        end

        # Returns :glue.
        def type
          :glue
        end

      end

      # Used for layouting. Describes a penalty item, i.e. a point where a break is allowed.
      #
      # If the penalty is greater than or equal to INFINITY, a break is forbidden. If it is smaller
      # than or equal to -INFINITY, a break is mandatory.
      #
      # If a penalty contains an item and a break occurs at the penalty (taking the width of the
      # penalty/item into account), then the penality item must be the last item of the line.
      class Penalty

        # All numbers greater than this one are deemed infinite.
        INFINITY = 1000

        # The penalty value for a mandatory paragraph break.
        PARAGRAPH_BREAK = -INFINITY - 1_000_000

        # The penalty value for a mandatory line break.
        LINE_BREAK = -INFINITY - 1_000_001

        # The penalty for breaking at this point.
        attr_reader :penalty

        # The width assigned to this item.
        attr_reader :width

        # The wrapped item.
        attr_reader :item

        # Creates a new Penalty with the given penality.
        def initialize(penalty, width = 0, item: nil)
          @penalty = penalty
          @width = width
          @item = item
        end

        # Returns :penalty.
        def type
          :penalty
        end

        # Singleton object describing a Penalty for a mandatory paragraph break.
        MandatoryParagraphBreak = new(PARAGRAPH_BREAK)

        # Singleton object describing a Penalty for a mandatory line break.
        MandatoryLineBreak = new(LINE_BREAK)

        # Singleton object describing a Penalty for a prohibited break.
        ProhibitedBreak = new(Penalty::INFINITY)

        # Singleton object describing a standard Penalty, e.g. for hyphens.
        Standard = new(50)

      end

      # Implementation of a simple text segmentation algorithm.
      #
      # The algorithm breaks TextFragment objects into objects wrapped by Box, Glue or Penalty
      # items, and inserts additional Penalty items when needed:
      #
      # * Any valid Unicode newline separator inserts a Penalty object describing a mandatory break.
      #
      #   See http://www.unicode.org/reports/tr18/#Line_Boundaries
      #
      # * Spaces and tabulators are wrapped by Glue objects, allowing breaks.
      #
      # * Non-breaking spaces are wrapped into Penalty objects that prohibit line breaking.
      #
      # * Hyphens are attached to the preceeding text fragment (or are a standalone text fragment)
      #   and followed by a Penalty object to allow a break.
      #
      # * If a soft-hyphens is encountered, a hyphen wrapped by a Penalty object is inserted to
      #   allow a break.
      #
      # * If a zero-width-space is encountered, a Penalty object is inserted to allow a break.
      module SimpleTextSegmentation

        # Breaks are detected at: space, tab, zero-width-space, non-breaking space, hyphen,
        # soft-hypen and any valid Unicode newline separator
        BREAK_RE = /[ \u{A}-\u{D}\u{85}\u{2028}\u{2029}\t\u{200B}\u{00AD}\u{00A0}-]/

        # Breaks the items (an array of InlineBox and TextFragment objects) into atomic pieces
        # wrapped by Box, Glue or Penalty items, and returns those as an array.
        def self.call(items)
          result = []
          glues = {}
          items.each do |item|
            if item.kind_of?(InlineBox)
              result << Box.new(item)
            else
              i = 0
              while i < item.items.size
                # Collect characters and kerning values until break character is encountered
                box_items = []
                while (glyph = item.items[i]) &&
                    (glyph.kind_of?(Numeric) || !BREAK_RE.match?(glyph.str))
                  box_items << glyph
                  i += 1
                end

                # A hyphen belongs to the text fragment
                box_items << glyph if glyph && !glyph.kind_of?(Numeric) && glyph.str == '-'.freeze

                unless box_items.empty?
                  result << Box.new(TextFragment.new(items: box_items.freeze, style: item.style))
                end

                if glyph
                  case glyph.str
                  when ' '
                    glues[item.style] ||=
                      Glue.new(TextFragment.new(items: [glyph].freeze, style: item.style))
                    result << glues[item.style]
                  when "\n", "\v", "\f", "\u{85}", "\u{2029}"
                    result << Penalty::MandatoryParagraphBreak
                  when "\u{2028}"
                    result << Penalty::MandatoryLineBreak
                  when "\r"
                    if item.items[i + 1]&.kind_of?(Numeric) || item.items[i + 1].str != "\n"
                      result << Penalty::MandatoryParagraphBreak
                    end
                  when '-'
                    result << Penalty::Standard
                  when "\t"
                    spaces = [item.style.font.decode_utf8(" ").first] * 8
                    result << Glue.new(TextFragment.new(items: spaces.freeze, style: item.style))
                  when "\u{00AD}"
                    hyphen = item.style.font.decode_utf8("-").first
                    frag = TextFragment.new(items: [hyphen].freeze, style: item.style)
                    result << Penalty.new(Penalty::Standard.penalty, frag.width, item: frag)
                  when "\u{00A0}"
                    space = item.style.font.decode_utf8(" ").first
                    frag = TextFragment.new(items: [space].freeze, style: item.style)
                    result << Penalty.new(Penalty::ProhibitedBreak.penalty, frag.width, item: frag)
                  when "\u{200B}"
                    result << Penalty.new(0)
                  end
                end
                i += 1
              end
            end
          end
          result
        end
      end

      # Implementation of a simple line wrapping algorithm.
      #
      # The algorithm arranges the given items so that the maximum number is put onto each line,
      # taking the differences of Box, Glue and Penalty items into account.
      class SimpleLineWrapping

        # :call-seq:
        #   SimpleLineWrapping.call(items, width_block) {|line, item| block }   -> rest
        #
        # Arranges the items into lines.
        #
        # The +width_block+ argument has to be a callable object that returns the width of the line:
        #
        # * If the line width doesn't depend on the height or the vertical position of the line
        #   (i.e. fixed line width), the +width_block+ should have an arity of zero. However, this
        #   doesn't mean that the block is called only once; it is actually called before each new
        #   line (e.g. for varying line widths that don't depend on the line height; one common case
        #   is the indentation of the first line). This is the general case.
        #
        # * However, if lines should have varying widths (e.g. for flowing text around shapes), the
        #   +width_block+ argument should be an object responding to #call(line_height) where
        #   +line_height+ is the height of the currently layed out line. The caller is responsible
        #   for tracking the height of the already layed out lines. This method involves more work
        #   and is therefore slower.
        #
        # Regardless of whether varying line widths are used or not, each time a line is finished,
        # it is yielded to the caller. The second argument +item+ is the item that caused the line
        # break (e.g. a Box, Glue or Penalty). The return value should be truthy if line wrapping
        # should continue, or falsy if it should stop. If the yielded line is empty and the yielded
        # item is a box item, this single item didn't fit into the available width; the caller has
        # to handle this situation, e.g. by stopping.
        #
        # After the algorithm is finished, it returns the unused items.
        def self.call(items, width_block, &block)
          obj = new(items, width_block)
          if width_block.arity == 1
            obj.variable_width_wrapping(&block)
          else
            obj.fixed_width_wrapping(&block)
          end
        end

        private_class_method :new

        # Creates a new line wrapping object that arranges the +items+ on lines with the given
        # width.
        def initialize(items, width_block)
          @items = items
          @width_block = width_block
          @available_width = @width_block.call(0)
          @line_items = []
          @width = 0
          @glue_items = []
          @beginning_of_line_index = 0
          @last_breakpoint_index = 0
          @last_breakpoint_line_items_index = 0
          @break_prohibited_state = false

          @height_calc = Line::HeightCalculator.new
          @line_height = 0
        end

        # Peforms line wrapping with a fixed width per line, with line height playing no role.
        def fixed_width_wrapping
          index = 0

          while (item = @items[index])
            case item.type
            when :box
              unless add_box_item(item.item)
                if @break_prohibited_state
                  index = reset_line_to_last_breakpoint_state
                  item = @items[index]
                end
                break unless yield(create_line, item)
                reset_after_line_break(index)
                redo
              end
            when :glue
              unless add_glue_item(item.item, index)
                break unless yield(create_line, item)
                reset_after_line_break(index + 1)
              end
            when :penalty
              if item.penalty <= -Penalty::INFINITY
                break unless yield(create_unjustified_line, item)
                reset_after_line_break(index + 1)
              elsif item.penalty >= Penalty::INFINITY
                @break_prohibited_state = true
                add_box_item(item.item) if item.width > 0
              elsif item.width > 0
                if item_fits_on_line?(item)
                  next_index = index + 1
                  next_item = @items[next_index]
                  next_item = @items[next_index += 1] while next_item && next_item.type == :penalty
                  if next_item && !item_fits_on_line?(next_item)
                    @line_items.concat(@glue_items).push(item.item)
                    @width += item.width
                  end
                  update_last_breakpoint(index)
                else
                  @break_prohibited_state = true
                end
              else
                update_last_breakpoint(index)
              end
            end

            index += 1
          end

          line = create_unjustified_line
          last_line_used = true
          last_line_used = yield(line, nil) if item.nil? && !line.items.empty?

          item.nil? && last_line_used ? [] : @items[@beginning_of_line_index..-1]
        end

        # Performs the line wrapping with variable widths.
        def variable_width_wrapping
          index = 0

          while (item = @items[index])
            case item.type
            when :box
              new_height = @height_calc.simulate_height(item.item)
              if new_height > @line_height
                @line_height = new_height
                @available_width = @width_block.call(@line_height)
              end
              if add_box_item(item.item)
                @height_calc << item.item
              else
                if @break_prohibited_state
                  index = reset_line_to_last_breakpoint_state
                  item = @items[index]
                end
                break unless yield(create_line, item)
                reset_after_line_break(index)
                redo
              end
            when :glue
              unless add_glue_item(item.item, index)
                break unless yield(create_line, item)
                reset_after_line_break(index + 1)
              end
            when :penalty
              if item.penalty <= -Penalty::INFINITY
                break unless yield(create_unjustified_line, item)
                reset_after_line_break(index + 1)
              elsif item.penalty >= Penalty::INFINITY
                @break_prohibited_state = true
                add_box_item(item.item) if item.width > 0
              elsif item.width > 0
                if item_fits_on_line?(item)
                  next_index = index + 1
                  next_item = @items[next_index]
                  next_item = @items[n_index += 1] while next_item && next_item.type == :penalty
                  new_height = @height_calc.simulate_height(next_item.item)
                  if next_item && @width + next_item.width > @width_block.call(new_height)
                    @line_items.concat(@glue_items).push(item.item)
                    @width += item.width
                    # No need to clean up, since in the next iteration a line break occurs
                  end
                  update_last_breakpoint(index)
                else
                  @break_prohibited_state = true
                end
              else
                update_last_breakpoint(index)
              end
            end

            index += 1
          end

          line = create_unjustified_line
          last_line_used = true
          last_line_used = yield(line, nil) if item.nil? && !line.items.empty?

          item.nil? && last_line_used ? [] : @items[@beginning_of_line_index..-1]
        end

        private

        # Adds the box item to the line items if it fits on the line.
        #
        # Returns +true+ if the item could be added and +false+ otherwise.
        def add_box_item(item)
          return false unless @width + item.width <= @available_width
          @line_items.concat(@glue_items).push(item)
          @width += item.width
          @glue_items.clear
          true
        end

        # Adds the glue item to the line items if it fits on the line.
        #
        # Returns +true+ if the item could be added and +false+ otherwise.
        def add_glue_item(item, index)
          return false unless @width + item.width <= @available_width
          unless @line_items.empty? # ignore glue at beginning of line
            @glue_items << item
            @width += item.width
            update_last_breakpoint(index)
          end
          true
        end

        # Updates the information on the last possible breakpoint of the current line.
        def update_last_breakpoint(index)
          @break_prohibited_state = false
          @last_breakpoint_index = index
          @last_breakpoint_line_items_index = @line_items.size
        end

        # Resets the line items array to contain only those items that were in it when the last
        # breakpoint was encountered and returns the items' index of the last breakpoint.
        def reset_line_to_last_breakpoint_state
          @line_items.slice!(@last_breakpoint_line_items_index..-1)
          @break_prohibited_state = false
          @last_breakpoint_index
        end

        # Returns +true+ if the item fits on the line.
        def item_fits_on_line?(item)
          @width + item.width <= @available_width
        end

        # Creates a Line object from the current line items.
        def create_line
          Line.new(@line_items)
        end

        # Creates a Line object from the current line items that ignores line justification.
        def create_unjustified_line
          create_line.tap(&:ignore_justification!)
        end

        # Resets the line state variables to their initial values. The +index+ specifies the items
        # index of the first item on the new line.
        def reset_after_line_break(index)
          @beginning_of_line_index = index
          @line_items.clear
          @width = 0
          @glue_items.clear
          @last_breakpoint_index = index
          @last_breakpoint_line_items_index = 0
          @break_prohibited_state = false
          @available_width = @width_block.call(0)

          @line_height = 0
          @height_calc.reset
        end

      end


      # Creates a new TextLayouter object for the given text and returns it.
      #
      # See ::new for information on +height+.
      #
      # The style that gets applied to the text and the layout itself can be specified using
      # additional options, of which font is mandatory.
      def self.create(text, width:, height: nil, x_offsets: nil, **options)
        frag = TextFragment.create(text, **options)
        new(items: [frag], width: width, height: height, x_offsets: x_offsets, style: frag.style)
      end

      # The style to be applied.
      #
      # Only the following properties are used: Style#text_indent, Style#align, Style#valign,
      # Style#text_segmentation_algorithm, Style#text_line_wrapping_algorithm
      attr_reader :style

      # The items (TextFragment and InlineBox objects) that should be layed out.
      attr_reader :items

      # Array of Line objects describing the layed out lines.
      #
      # The array is only valid after #fit was called.
      attr_reader :lines

      # The actual height of the layed out text. Can be +nil+ if the items have not been layed out
      # yet, i.e. if #fit has not been called.
      attr_reader :actual_height

      # Creates a new TextLayouter object with the given width containing the given items.
      #
      # The width can either be a simple number specifying a fixed width, or an object that responds
      # to #call(height, line_height) where +height+ is the bottom of last line and +line_height+ is
      # the height of the line to be layed out. The return value should be the available width given
      # these height restrictions.
      #
      # The optional +x_offsets+ argument works like +width+ but can be used to specify (varying)
      # offsets from the left side (e.g. when the left side of the text should follow a certain
      # shape).
      #
      # The height is optional and if not specified means that the text layout has infinite height.
      #
      # The +style+ argument can either be a Style object or a hash of style options. See #style for
      # the properties that are used by the layouter.
      def initialize(items: [], width:, height: nil, x_offsets: nil, style: Style.new)
        @style = (style.kind_of?(Style) ? style : Style.new(style))
        @lines = []
        self.items = items
        @width = width
        @height = height || Float::INFINITY
        @x_offsets = x_offsets && (x_offsets.respond_to?(:call) ? x_offsets : proc { x_offsets })
      end

      # Sets the items to be arranged by the text layouter, clearing the internal state.
      #
      # If the items array contains items before text segmentation, the text segmentation algorithm
      # is automatically applied.
      def items=(items)
        unless items.empty? || items[0].respond_to?(:type)
          items = style.text_segmentation_algorithm.call(items)
        end
        @items = items.freeze
        @lines.clear
        @actual_height = nil
      end

      # :call-seq:
      #   text_layouter.fit  -> [remaining_items, actual_height]
      #
      # Fits the items into the set area and returns the remaining items as well as the actual
      # height needed.
      #
      # Note: If no height has been set and variable line widths are used, no search for a possible
      # vertical offset is done in case a single item doesn't fit.
      #
      # This method is automatically called as part of the drawing routine but it can also be used
      # by itself to determine the actual height of the layed out text.
      def fit
        @lines.clear
        @actual_height = 0

        y_offset = 0
        indent = (style.text_indent != 0 ? style.text_indent : 0)
        width_block = if @width.respond_to?(:call)
                        proc {|h| @width.call(@actual_height, h) - indent }
                      else
                        proc { @width - indent }
                      end

        rest = style.text_line_wrapping_algorithm.call(@items, width_block) do |line, item|
          line << TextFragment.new(items: [], style: style) if item&.type != :box && line.items.empty?
          new_height = @actual_height + line.height +
            (@lines.empty? ? 0 : style.line_spacing.gap(@lines.last, line))

          if new_height <= @height && !line.items.empty?
            # valid line found, use it
            cur_width = width_block.call(line.height)
            line.x_offset = indent + horizontal_alignment_offset(line, cur_width)
            line.x_offset += @x_offsets.call(@actual_height, line.height) if @x_offsets
            line.y_offset =  if y_offset
                               y_offset + (@lines.last ? -@lines.last.y_min + line.y_max : 0)
                             else
                               style.line_spacing.baseline_distance(@lines.last, line)
                             end
            @actual_height = new_height
            @lines << line
            y_offset = nil
            indent = if item&.type == :penalty && item.penalty == Penalty::PARAGRAPH_BREAK
                       style.text_indent
                     else
                       0
                     end
            true
          elsif new_height <= @height && @height != Float::INFINITY
            # some height left but item didn't fit on the line, search downwards for usable space
            old_height = @actual_height
            while item.width > width_block.call(item.height) && @actual_height <= @height
              @actual_height += item.height / 3
            end
            if @actual_height + item.height <= @height
              y_offset = @actual_height - old_height
              true
            else
              @actual_height = old_height
              nil
            end
          else
            nil
          end
        end

        [rest, @actual_height]
      end

      # Draws the layed out text onto the canvas with the top-left corner being at [x, y].
      #
      # Depending on the value of +fit+ the text may also be fitted:
      #
      # * If +true+, then #fit is always called.
      # * If +:if_needed+, then #fit is only called if it has not been called before.
      # * If +false+, then #fit is never called.
      def draw(canvas, x, y, fit: :if_needed)
        self.fit if fit == true || (!@actual_height && fit == :if_needed)
        return if @lines.empty?

        canvas.save_graphics_state do
          y -= initial_baseline_offset + @lines.first.y_offset
          @lines.each_with_index do |line, index|
            line_x = x + line.x_offset
            line.each do |item, item_x, item_y|
              if item.kind_of?(TextFragment)
                item.draw(canvas, line_x + item_x, y + item_y)
              elsif !item.empty?
                canvas.restore_graphics_state
                item.draw(canvas, line_x + item_x, y + item_y)
                canvas.save_graphics_state
              end
            end
            y -= @lines[index + 1].y_offset if @lines[index + 1]
          end
        end
      end

      private

      # Returns the initial baseline offset from the top, based on the valign style option.
      def initial_baseline_offset
        case style.valign
        when :top
          @lines.first.y_max
        when :center
          if @height == Float::INFINITY
            raise HexaPDF::Error, "Can't vertically align when using unlimited height"
          end
          (@height - @actual_height) / 2.0 + @lines.first.y_max
        when :bottom
          if @height == Float::INFINITY
            raise HexaPDF::Error, "Can't vertically align when using unlimited height"
          end
          (@height - @actual_height) + @lines.first.y_max
        end
      end

      # Returns the horizontal offset from the left side, based on the align style option.
      def horizontal_alignment_offset(line, available_width)
        case style.align
        when :left then 0
        when :center then (available_width - line.width) / 2
        when :right then available_width - line.width
        when :justify then (justify_line(line, available_width); 0)
        end
      end

      # Justifies the given line.
      def justify_line(line, width)
        return if line.ignore_justification? || (width - line.width).abs < 0.001

        indexes = []
        sum = 0.0
        line.items.each_with_index do |item, item_index|
          next if item.kind_of?(InlineBox)
          item.items.each_with_index do |glyph, glyph_index|
            if !glyph.kind_of?(Numeric) && glyph.str == ' '.freeze
              sum += glyph.width * item.style.scaled_font_size
              indexes << item_index << glyph_index
            end
          end
        end

        if sum > 0
          adjustment = (width - line.width) / sum
          i = indexes.length - 2
          while i >= 0
            frag = line.items[indexes[i]]
            value = -frag.items[indexes[i + 1]].width * adjustment
            if frag.items.frozen?
              value = HexaPDF::Layout::TextFragment.new(items: [value], style: frag.style)
              line.items.insert(indexes[i], value)
            else
              frag.items.insert(indexes[i + 1], value)
              frag.clear_cache
            end
            i -= 2
          end
          line.clear_cache
        end
      end

    end

  end
end
