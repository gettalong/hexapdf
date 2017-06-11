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

module HexaPDF
  module Layout

    # A Style is a container for properties that describe the appearance of text or graphics.
    #
    # Each property except #font has a default value, so only the desired properties need to be
    # changed.
    class Style

      # Defines how the distance between the baselines of two adjacent text lines is determined:
      #
      # :single::
      #     :proportional with value 1.
      #
      # :double::
      #     :proportional with value 2.
      #
      # :proportional::
      #     The y_min of the first line and the y_max of the second line are multiplied with the
      #     specified value, and the sum is used as baseline distance.
      #
      # :fixed::
      #     The distance between the baselines is set to the specified value.
      #
      # :leading::
      #     The distance between the baselines is set to the sum of the y_min of the first line, the
      #     y_max of the second line and the specified value.
      class LineSpacing

        # The type of line spacing - see LineSpacing
        attr_reader :type

        # The value (needed for some types) - see LineSpacing
        attr_reader :value

        # Creates a new LineSpacing object for the given type which can be any valid line spacing
        # type or a LineSpacing object.
        def initialize(type, value: 1)
          case type
          when :single
            @type = :proportional
            @value = 1
          when :double
            @type = :proportional
            @value = 2
          when :fixed, :proportional, :leading
            unless value.kind_of?(Numeric)
              raise ArgumentError, "Need a valid number for #{type} line spacing"
            end
            @type = type
            @value = value
          when LineSpacing
            @type = type.type
            @value = type.value
          else
            raise ArgumentError, "Invalid type #{type} for line spacing"
          end
        end

        # Returns the distance between the baselines of the two given LineFragment objects.
        def baseline_distance(line1, line2)
          case type
          when :proportional then (line1.y_min.abs + line2.y_max) * value
          when :fixed then value
          when :leading then line1.y_min.abs + line2.y_max + value
          end
        end

        # Returns the gap between the two given LineFragment objects, i.e. the distance between the
        # y_min of the first line and the y_max of the second line.
        def gap(line1, line2)
          case type
          when :proportional then (line1.y_min.abs + line2.y_max) * (value - 1)
          when :fixed then value - line1.y_min.abs - line2.y_max
          when :leading then value
          end
        end

      end

      UNSET = ::Object.new # :nodoc:

      # Creates a new Style object.
      #
      # The +options+ hash may be used to set the initial values of properties by using keys
      # equivalent to the property names.
      #
      # Example:
      #   Style.new(font_size: 15, align: :center, valign: center)
      def initialize(**options)
        options.each {|key, value| send(key, value)}
      end

      ##
      # :method: font
      # :call-seq:
      #   font(name = nil)
      #
      # The font to be used, must be set to a valid font wrapper object before it can be used.
      #
      # This is the only style property without a default value!
      #
      # See: HexaPDF::Content::Canvas#font

      ##
      # :method: font_size
      # :call-seq:
      #   font_size(size = nil)
      #
      # The font size, defaults to 10.
      #
      # See: HexaPDF::Content::Canvas#font_size

      ##
      # :method: character_spacing
      # :call-seq:
      #   character_spacing(amount = nil)
      #
      # The character spacing, defaults to 0 (i.e. no additional character spacing).
      #
      # See: HexaPDF::Content::Canvas#character_spacing

      ##
      # :method: word_spacing
      # :call-seq:
      #   word_spacing(amount = nil)
      #
      # The word spacing, defaults to 0 (i.e. no additional word spacing).
      #
      # See: HexaPDF::Content::Canvas#word_spacing

      ##
      # :method: horizontal_scaling
      # :call-seq:
      #   horizontal_scaling(percent = nil)
      #
      # The horizontal scaling, defaults to 100 (in percent, i.e. normal scaling).
      #
      # See: HexaPDF::Content::Canvas#horizontal_scaling

      ##
      # :method: text_rise
      # :call-seq:
      #   text_rise(amount = nil)
      #
      # The text rise, i.e. the vertical offset from the baseline, defaults to 0.
      #
      # See: HexaPDF::Content::Canvas#text_rise

      ##
      # :method: font_features
      # :call-seq:
      #   font_features(features = nil)
      #
      # The font features (e.g. kerning, ligatures, ...) that should be applied by the shaping
      # engine, defaults to {} (i.e. no font features are applied).
      #
      # Each feature to be applied is indicated by a key with a truthy value.
      #
      # See: HexaPDF::Layout::TextShaper#shape_text for available features.

      ##
      # :method: align
      # :call-seq:
      #   align(direction = nil)
      #
      # The horizontal alignment of text, defaults to :left.
      #
      # Possible values:
      #
      # :left::    Left-align the text, i.e. the right side is rugged.
      # :center::  Center the text horizontally.
      # :right::   Right-align the text, i.e. the left side is rugged.
      # :justify:: Justify the text, except for those lines that end in a hard line break.

      ##
      # :method: valign
      # :call-seq:
      #   valign(direction = nil)
      #
      # The vertical alignment of items (normally text) inside a box, defaults to :top.
      #
      # Possible values:
      #
      # :top::    Vertically align the items to the top of the box.
      # :center:: Vertically align the items in the center of the box.
      # :bottom:: Vertically align the items to the bottom of the box.

      ##
      # :method: text_indent
      # :call-seq:
      #   text_indent(amount = nil)
      #
      # The indentation to be used for the first line of a sequence of text lines, defaults to 0.

      [
        [:font, "raise HexaPDF::Error, 'No font set'"],
        [:font_size, 10],
        [:character_spacing, 0],
        [:word_spacing, 0],
        [:horizontal_scaling, 100],
        [:text_rise, 0],
        [:font_features, {}],
        [:align, :left],
        [:valign, :top],
        [:text_indent, 0],
      ].each do |name, default|
        default = default.inspect unless default.kind_of?(String)
        module_eval(<<-EOF, __FILE__, __LINE__)
          def #{name}(value = UNSET)
            value == UNSET ? (@#{name} ||= #{default}) : (@#{name} = value; self)
          end
        EOF
        alias_method("#{name}=", name)
      end

      # :call-seq:
      #   line_spacing(type = nil, value = nil)
      #
      # The spacing between consecutive lines, defaults to type = :single.
      #
      # See: LineSpacing
      def line_spacing(type = UNSET, value = nil)
        if type == UNSET
          @line_spacing ||= LineSpacing.new(:single)
        else
          @line_spacing = LineSpacing.new(type, value: value)
          self
        end
      end
      alias_method(:line_spacing=, :line_spacing)

      # :call-seq:
      #   text_segmentation_algorithm(algorithm = nil) {|items| block }
      #
      # The algorithm to use for text segmentation purposes, defaults to
      # TextBox::SimpleTextSegmentation.
      #
      # When setting the algorithm, either an object that responds to #call(items) or a block can be
      # used.
      def text_segmentation_algorithm(algorithm = UNSET, &block)
        if algorithm == UNSET && !block
          @text_segmentation_algorithm ||= TextBox::SimpleTextSegmentation
        else
          @text_segmentation_algorithm = (algorithm != UNSET ? algorithm : block)
          self
        end
      end
      alias_method(:text_segmentation_algorithm=, :text_segmentation_algorithm)

      # :call-seq:
      #   text_line_wrapping_algorithm(algorithm = nil) {|items| block }
      #
      # The line wrapping algorithm that should be used, defaults to TextBox::SimpleLineWrapping.
      #
      # When setting the algorithm, either an object that responds to #call or a block can be used.
      # See TextBox::SimpleLineWrapping#call for the needed method signature.
      def text_line_wrapping_algorithm(algorithm = UNSET, &block)
        if algorithm == UNSET && !block
          @text_line_wrapping_algorithm ||= TextBox::SimpleLineWrapping
        else
          @text_line_wrapping_algorithm = (algorithm != UNSET ? algorithm : block)
          self
        end
      end
      alias_method(:text_line_wrapping_algorithm=, :text_line_wrapping_algorithm)

      # The font size scaled appropriately.
      def scaled_font_size
        @scaled_font_size ||= font_size / 1000.0 * scaled_horizontal_scaling
      end

      # The character spacing scaled appropriately.
      def scaled_character_spacing
        @scaled_character_spacing ||= character_spacing * scaled_horizontal_scaling
      end

      # The word spacing scaled appropriately.
      def scaled_word_spacing
        @scaled_word_spacing ||= word_spacing * scaled_horizontal_scaling
      end

      # The horizontal scaling scaled appropriately.
      def scaled_horizontal_scaling
        @scaled_horizontal_scaling ||= horizontal_scaling / 100.0
      end

      # The ascender of the font scaled appropriately.
      def scaled_font_ascender
        @ascender ||= font.wrapped_font.ascender * font.scaling_factor * font_size / 1000
      end

      # The descender of the font scaled appropriately.
      def scaled_font_descender
        @descender ||= font.wrapped_font.descender * font.scaling_factor * font_size / 1000
      end

      # Clears all cached values.
      #
      # This method needs to be called if the following style properties are changed and values were
      # already cached: font, font_size, character_spacing, word_spacing, horizontal_scaling,
      # ascender, descender.
      def clear_cache
        @scaled_font_size = @scaled_character_spacing = @scaled_word_spacing = nil
        @scaled_horizontal_scaling = @ascender = @descender = nil
      end

    end

  end
end
