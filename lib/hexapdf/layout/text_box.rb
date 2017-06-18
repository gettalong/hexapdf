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
require 'hexapdf/layout/line_fragment'
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
    # 1. The items of the text box are broken into pieces which are wrapped into Box, Glue or
    #    Penalty objects. Additional Penalty objects marking line breaking opportunities are
    #    inserted where needed. This step is done by the SimpleTextSegmentation module.
    #
    # 2. The pieces are arranged into lines using a very simple algorithm that just puts the maximum
    #    number of consecutive pieces into each line. This step is done by the SimpleLineWrapping
    #    module.
    class TextBox

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

        # The normal width of the glue item.
        def width
          @item.width
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

        # Singleton object describing a Penalty for a mandatory break.
        MandatoryBreak = new(-Penalty::INFINITY)

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
      # * Hyphens are attached to the preceeding text fragment (or are a standalone text fragment)
      #   and followed by a Penalty object to allow a break.
      #
      # * If a soft-hyphens is encountered, a hyphen wrapped by a Penalty object is inserted to
      #   allow a break.
      #
      # * If a zero-width-space is encountered, a Penalty object is inserted to allow a break.
      module SimpleTextSegmentation

        # Breaks are detected at: space, tab, zero-width-space, hyphen, soft-hypen and any valid
        # Unicode newline separator
        BREAK_RE = /[ \u{A}-\u{D}\u{85}\u{2028}\u{2029}\t\u{200B}\u{00AD}-]/

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
                  when "\n", "\v", "\f", "\u{85}", "\u{2028}", "\u{2029}"
                    result << Penalty::MandatoryBreak
                  when "\r"
                    if item.items[i + 1]&.kind_of?(Numeric) || item.items[i + 1].str != "\n"
                      result << Penalty::MandatoryBreak
                    end
                  when '-'
                    result << Penalty::Standard
                  when "\t"
                    spaces = [item.style.font.decode_utf8(" ").first] * 8
                    result << Glue.new(TextFragment.new(items: spaces.freeze, style: item.style))
                  when "\u{00AD}"
                    hyphen = item.style.font.decode_utf8("-").first
                    frag = TextFragment.new(items: [hyphen].freeze, style: item.style)
                    result << Penalty.new(50, frag.width, item: frag)
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
      module SimpleLineWrapping

        # :call-seq:
        #   SimpleLineWrapping.call(items, available_width) {|line, item| block }   -> rest
        #
        # Arranges the items into lines.
        #
        # The +available_width+ argument can either be a simple number or a callable object:
        #
        # * If all lines should have the same width, the +available_width+ argument should be a
        #   number. This is the general case.
        #
        # * However, if lines should have varying lengths (e.g. for flowing text around shapes), the
        #   +available_width+ argument should be an object responding to #call(line_height) where
        #   +line_height+ is the height of the currently layed out line. The caller is responsible
        #   for tracking the height of the already layed out lines. The result of the method call
        #   should be the available width.
        #
        # Regardless of whether varying line widths are used or not, each time a line is finished,
        # it is yielded to the caller. The second argument +item+ is the TextFragment or InlineBox
        # that doesn't fit anymore, or +nil+ in case of mandatory line breaks or when the line break
        # occured at a glue item. If the yielded line is empty and the yielded item is not +nil+,
        # this single item doesn't fit into the available width; the caller has to handle this
        # situation, e.g. by stopping.
        #
        # After the algorithm is finished, it returns the unused items.
        def self.call(items, available_width)
          index = 0
          beginning_of_line_index = 0
          line = LineFragment.new
          width = 0
          glue_items = []

          while (item = items[index])
            case item.type
            when :box
              if width + item.width <= available_width
                glue_items.each {|i| line << i}
                line << item.item
                width += item.width
                glue_items.clear
              else
                break unless yield(line, item.item)
                beginning_of_line_index = index
                line = LineFragment.new
                width = 0
                glue_items.clear
                redo
              end
            when :glue
              if width + item.width <= available_width
                unless line.items.empty? # ignore glue at beginning of line
                  glue_items << item.item
                  width += item.width
                end
              else
                break unless yield(line, nil)
                beginning_of_line_index = index + 1
                line = LineFragment.new
                width = 0
                glue_items.clear # ignore glue at beginning of line
              end
            when :penalty
              if item.penalty <= -Penalty::INFINITY
                line.ignore_justification!
                break unless yield(line, nil)
                beginning_of_line_index = index + 1
                line = LineFragment.new
                width = 0
                glue_items.clear
              elsif item.width > 0 && width + item.width <= available_width
                next_index = index + 1
                next_item = items[next_index]
                next_item = items[n_index += 1] while next_item && next_item.type == :penalty
                if next_item && width + next_item.width > available_width
                  glue_items.each {|i| line << i}
                  line << item.item
                  width += item.width
                end
              end
            end

            index += 1
          end

          line.ignore_justification!
          last_line_used = true
          last_line_used = yield(line) if available_width && !line.items.empty?

          item.nil? && last_line_used ? [] : items[beginning_of_line_index..-1]
        end

      end


      # Creates a new TextBox object for the given text and returns it.
      #
      # See ::new for information on +height+.
      #
      # The style of the text box can be specified using additional options, of which font is
      # mandatory.
      def self.create(text, width:, height: nil, **options)
        frag = TextFragment.create(text, **options)
        new(items: [frag], width: width, height: height, style: frag.style)
      end

      # The style to be applied.
      #
      # Only the following properties are used: Style#text_indent, Style#align, Style#valign,
      # Style#text_segmentation_algorithm, Style#text_line_wrapping_algorithm
      attr_reader :style

      # The items (TextFragment and InlineBox objects) of the text box that should be layed out.
      attr_reader :items

      # Array of LineFragment objects describing the lines of the text box.
      #
      # The array is only valid after #fit was called.
      attr_reader :lines

      # The actual height of the text box. Can be +nil+ if the items have not been layed out yet,
      # i.e. if #fit has not been called.
      attr_reader :actual_height

      # Creates a new TextBox object with the given width containing the given items.
      #
      # The height is optional and if not specified means that the text box has infinite height.
      def initialize(items: [], width:, height: nil, style: Style.new)
        @style = style
        @lines = []
        self.items = items
        @width = width
        @height = height || Float::INFINITY
      end

      # Sets the items to be arranged by the text box, clearing the internal state.
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
      #   text_box.fit  -> [remaining_items, actual_height]
      #
      # Fits the items into the text box and returns the remaining items as well as the actual
      # height needed.
      #
      # This method is automatically called as part of the drawing routine but it can also be used
      # by itself to determine the actual height of the text box.
      def fit
        @lines.clear
        @actual_height = 0

        items = @items
        if style.text_indent != 0
          items = [Box.new(InlineBox.new(style.text_indent, 0) { })].concat(items)
        end

        rest = style.text_line_wrapping_algorithm.call(items, @width) do |line, item|
          line << TextFragment.new(items: [], style: style) if item.nil? && line.items.empty?
          new_height = @actual_height + line.height +
            (@lines.empty? ? 0 : style.line_spacing.gap(@lines.last, line))

          if new_height <= @height && !line.items.empty?
            # valid line found, use it
            @actual_height = new_height
            line.x_offset = horizontal_alignment_offset(line, @width)
            line.y_offset = style.line_spacing.baseline_distance(@lines.last, line) if @lines.last
            @lines << line
            true
          else
            nil
          end
        end

        [rest, @actual_height]
      end

      # Draws the text box onto the canvas with the top-left corner being at [x, y].
      #
      # Depending on the value of +fit+ the text may also be fitted:
      #
      # * If +true+, then #fit is always called.
      # * If +:if_needed+, then #fit is only called if it has been called before.
      # * If +false+, then #fit is never called.
      def draw(canvas, x, y, fit: :if_needed)
        self.fit if fit == true || (!@actual_height && fit == :if_needed)
        return if @lines.empty?

        canvas.save_graphics_state do
          y -= initial_baseline_offset + @lines.first.y_offset
          @lines.each_with_index do |line, index|
            line_x = x + line.x_offset
            line.each {|item, item_x, item_y| item.draw(canvas, line_x + item_x, y + item_y) }
            y -= @lines[index + 1].y_offset if @lines[index + 1]
          end
        end
      end

      private

      # Returns the initial baseline offset from the top of the text box, based on the valign style
      # option.
      def initial_baseline_offset
        case style.valign
        when :top
          @lines.first.y_max
        when :center
          if @height == Float::INFINITY
            raise HexaPDF::Error, "Can't vertically align a text box with unlimited height"
          end
          (@height - @actual_height) / 2.0 + @lines.first.y_max
        when :bottom
          if @height == Float::INFINITY
            raise HexaPDF::Error, "Can't vertically align a text box with unlimited height"
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
