# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'hexapdf/error'
require 'hexapdf/content/graphics_state'

module HexaPDF
  module Layout

    # A Style is a container for properties that describe the appearance of text or graphics.
    #
    # Each property except #font has a default value, so only the desired properties need to be
    # changed.
    #
    # Each property has three associated methods:
    #
    # property_name:: Getter method.
    # property_name(*args) and property_name=:: Setter method.
    # property_name?:: Tester method to see if a value has been set or if the default value has
    #                  already been used.
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
        def initialize(type:, value: 1)
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

        # Returns the distance between the baselines of the two given Line objects.
        def baseline_distance(line1, line2)
          case type
          when :proportional then (line1.y_min.abs + line2.y_max) * value
          when :fixed then value
          when :leading then line1.y_min.abs + line2.y_max + value
          end
        end

        # Returns the gap between the two given Line objects, i.e. the distance between the y_min of
        # the first line and the y_max of the second line.
        def gap(line1, line2)
          case type
          when :proportional then (line1.y_min.abs + line2.y_max) * (value - 1)
          when :fixed then value - line1.y_min.abs - line2.y_max
          when :leading then value
          end
        end

      end

      # A Quad holds four values and allows them to be accessed by the names top, right, bottom and
      # left. Quads are normally used for holding values pertaining to boxes, like margins, paddings
      # or borders.
      class Quad

        # The value for top.
        attr_accessor :top

        # The value for bottom.
        attr_accessor :bottom

        # The value for left.
        attr_accessor :left

        # The value for right.
        attr_accessor :right

        # Creates a new Quad object. See #set for more information.
        def initialize(obj)
          set(obj)
        end

        # :call-seq:
        #   quad.set(value)
        #   quad.set(array)
        #   quad.set(quad)
        #
        # Sets all values of the quad.
        #
        # * If a single value is provided that is neither a Quad nor an array, it is handled as if
        #   an array with one value was given.
        #
        # * If a Quad is provided, its values are used.
        #
        # * If an array is provided, it depends on the number of elemens in it:
        #
        #   * One value: All attributes are set to the same value.
        #   * Two values: Top and bottom are set to the first value, left and right to the second
        #     value.
        #   * Three values: Top is set to the first, left and right to the second, and bottom to the
        #     third value.
        #   * Four or more values: Top is set to the first, right to the second, bottom to the third
        #     and left to the fourth value.
        def set(obj)
          case obj
          when Quad
            @top = obj.top
            @bottom = obj.bottom
            @left = obj.left
            @right = obj.right
          when Array
            @top = obj[0]
            @bottom = obj[2] || obj[0]
            @left = obj[3] || obj[1] || obj[0]
            @right = obj[1] || obj[0]
          else
            @top = @bottom = @left = @right = obj
          end
        end

        # Returns +true+ if the quad effectively contains only one value.
        def simple?
          @top == @bottom && @top == @left && @top == @right
        end

      end

      # Represents the border of a rectangular area.
      class Border

        # The widths of each edge. See Quad.
        attr_reader :width

        # The colors of each edge. See Quad.
        attr_reader :color

        # The styles of each edge. See Quad.
        attr_reader :style

        # Creates a new border style. All arguments can be set to any value that a Quad can process.
        def initialize(width: 0, color: 0, style: :solid)
          @width = Quad.new(width)
          @color = Quad.new(color)
          @style = Quad.new(style)
        end

        # Duplicates a Border object's properties.
        def initialize_copy(other)
          super
          @width = @width.dup
          @color = @color.dup
          @style = @style.dup
        end

        # Returns +true+ if there is no border.
        def none?
          width.simple? && width.top == 0
        end

        # Draws the border onto the canvas, inside the rectangle (x, y, w, h).
        def draw(canvas, x, y, w, h)
          return if none?

          canvas.save_graphics_state do
            if width.simple? && color.simple? && style.simple?
              draw_simple_border(canvas, x, y, w, h)
            else
              draw_complex_border(canvas, x, y, w, h)
            end
          end
        end

        private

        # Draws the border assuming that only one width, style and color are used.
        def draw_simple_border(canvas, x, y, w, h)
          offset = width.top / 2.0
          canvas.stroke_color(color.top).
            line_width(width.top).
            line_join_style(:miter).
            miter_limit(10).
            line_cap_style(line_cap_style(:top))

          canvas.rectangle(x, y, w, h).clip_path.end_path
          if style.top == :solid
            canvas.line_dash_pattern(0).
              rectangle(x + offset, y + offset, w - 2 * offset, h - 2 * offset).stroke
          else
            canvas.line_dash_pattern(line_dash_pattern(:top, w)).
              line(x, y + h - offset, x + w, y + h - offset).
              line(x + w, y + offset, x, y + offset).stroke
            canvas.line_dash_pattern(line_dash_pattern(:right, h)).
              line(x + w - offset, y + h, x + w - offset, y).
              line(x + offset, y, x + offset, y + h).stroke
          end
        end

        # Draws a complex border, i.e. one where every edge is potentially differently styled.
        def draw_complex_border(canvas, x, y, w, h)
          left = x
          bottom = y
          right = left + w
          top = bottom + h
          inner_left = left + width.left
          inner_bottom = bottom + width.bottom
          inner_right = right - width.right
          inner_top = top - width.top

          if width.top > 0
            canvas.save_graphics_state do
              canvas.polyline(left, top, right, top, inner_right, inner_top,
                              inner_left, inner_top).
                clip_path.end_path
              canvas.stroke_color(color.top).
                line_width(width.top).
                line_cap_style(line_cap_style(:top)).
                line_dash_pattern(line_dash_pattern(:top, w)).
                line(left, top - width.top / 2.0, right, top - width.top / 2.0).stroke
            end
          end

          if width.right > 0
            canvas.save_graphics_state do
              canvas.polyline(right, top, right, bottom, inner_right, inner_bottom,
                              inner_right, inner_top).
                clip_path.end_path
              canvas.stroke_color(color.right).
                line_width(width.right).
                line_cap_style(line_cap_style(:right)).
                line_dash_pattern(line_dash_pattern(:right, h)).
                line(right - width.right / 2.0, top, right - width.right / 2.0, bottom).stroke
            end
          end

          if width.bottom > 0
            canvas.save_graphics_state do
              canvas.polyline(right, bottom, left, bottom, inner_left, inner_bottom,
                              inner_right, inner_bottom).
                clip_path.end_path
              canvas.stroke_color(color.bottom).
                line_width(width.bottom).
                line_cap_style(line_cap_style(:bottom)).
                line_dash_pattern(line_dash_pattern(:bottom, w)).
                line(right, bottom + width.bottom / 2.0, left, bottom + width.bottom / 2.0).stroke
            end
          end

          if width.left > 0
            canvas.save_graphics_state do
              canvas.polyline(left, bottom, left, top, inner_left, inner_top,
                              inner_left, inner_bottom).
                clip_path.end_path
              canvas.stroke_color(color.left).
                line_width(width.left).
                line_cap_style(line_cap_style(:left)).
                line_dash_pattern(line_dash_pattern(:left, h)).
                line(left + width.left / 2.0, bottom, left + width.left / 2.0, top).stroke
            end
          end
        end

        # Returns the line cap style for the given edge name.
        def line_cap_style(edge)
          case style.send(edge)
          when :solid then :butt
          when :dashed then :projecting_square
          when :dashed_round, :dotted then :round
          else
            raise ArgumentError, "Invalid border style specified: #{style.send(edge)}"
          end
        end

        # Returns the line dash pattern for the given edge name. The argument +length+ needs to
        # contain the length of the edge.
        def line_dash_pattern(edge, length)
          case style.send(edge)
          when :solid
            0
          when :dashed, :dashed_round
            # Due to the used line cap styles, a dash of length w appears with a length of 2w. The
            # gap between dashes is nominally 3w but adjusted so that full dashes start and end in
            # the corners.
            w = width.send(edge)
            count = [(length.to_f / (w * 3)).floor, 1].max
            gap = [(length - w * (count + 2)).to_f, 0].max / count
            HexaPDF::Content::LineDashPattern.new([w, gap], w * 0.5 + gap)
          when :dotted
            # Adjust the gap so that full dots appear in the corners.
            w = width.send(edge)
            gap = [(length - w).to_f / (length.to_f / (w * 2)).ceil, 1].max
            HexaPDF::Content::LineDashPattern.new([0, gap], [gap - w * 0.5, 0].max)
          end
        end

      end

      # Represents layers that can be drawn under or over a box.
      #
      # There are two ways to specify layers via #add:
      #
      # * Directly by providing a callable object.
      #
      # * By reference to a callable object or class in the 'style.layers_map' configuration option.
      #   The reference name is looked up in the configuration option using
      #   HexaPDF::Configuration#constantize. If the resulting object is a callable object, it is
      #   used; otherwise it is assumed that it is a class and an object is instantiated, passing in
      #   any options given on #add.
      #
      # The object resolved in this way needs to respond to #call(canvas, box) where +canvas+ is the
      # HexaPDF::Content::Canvas object on which it should be drawn and +box+ is a box-like object
      # (e.g. Box or TextFragment). The coordinate system is translated so that the origin is at the
      # bottom left corner of the box during the drawing operations.
      class Layers

        # Creates a new Layers object popuplated with the given +layers+.
        def initialize(layers = [])
          @layers = layers
        end

        # Duplicates the array holding the layers.
        def initialize_copy(other)
          super
          @layers = @layers.dup
        end

        # :call-seq:
        #   layers.add {|canvas, box| block}
        #   layers.add(name, **options)
        #
        # Adds a new layer object.
        #
        # The layer object can either be specified as a block or by reference to a configured layer
        # object in 'style.layers_map'. In this case +name+ is used as the reference and the options
        # are passed to layer object if it needs initialization.
        def add(name = nil, **options, &block)
          if block_given?
            @layers << block
          elsif name
            @layers << [name, options]
          else
            raise ArgumentError, "Layer object name or block missing"
          end
        end

        # Draws all layer objects onto the canvas at the position [x, y] for the given box.
        def draw(canvas, x, y, box)
          return if none?

          canvas.translate(x, y) do
            each(canvas.context.document.config) do |layer|
              canvas.save_graphics_state { layer.call(canvas, box) }
            end
          end
        end

        # Yields all layer objects. Objects that have been specified via a reference are first
        # resolved using the provided configuration object.
        def each(config) #:yield: layer
          @layers.each do |obj, options|
            obj = config.constantize('style.layers_map', obj) unless obj.respond_to?(:call)
            obj = obj.new(**options) unless obj.respond_to?(:call)
            yield(obj)
          end
        end

        # Returns +true+ if there are no layers defined.
        def none?
          @layers.empty?
        end

      end

      # The LinkLayer class provides support for linking to in-document or remote destinations for
      # Style objects using link annotations. Typical use cases would be linking to a (named)
      # destination on a different page or executing a URI action.
      #
      # See: PDF1.7 s12.5.6.6, Layers, HexaPDF::Type::Annotations::Link
      class LinkLayer

        # Creates a new LinkLayer object.
        #
        # The following arguments are allowed (note that only *one* of +dest+, +uri+ or +file+ may
        # be specified):
        #
        # +dest+::
        #   The destination array or a name of a named destination for in-document links.
        #
        # +uri+::
        #   The URI to link to.
        #
        # +file+::
        #   The file that should be opened or, if it refers to an application, the application that
        #   should be launched. Can either be a string or a Filespec object. Also see:
        #   HexaPDF::Type::FileSpecification.
        #
        # +border+::
        #   If set to +true+, a standard border is used. Also accepts an array that adheres to the
        #   rules for annotation borders.
        #
        # +border_color+::
        #   Defines the border color. Can be an array with 0 (transparent), 1 (grayscale), 3 (RGB)
        #   or 4 (CMYK) values.
        #
        # Examples:
        #   LinkLayer.new(dest: [page, :XYZ, nil, nil, nil], border: true)
        #   LinkLayer.new(uri: "https://my.example.com/path", border: [5 5 2])
        def initialize(dest: nil, uri: nil, file: nil, border: false, border_color: nil)
          if dest && (uri || file) || uri && file
            raise ArgumentError, "Only one of dest, uri and file is allowed"
          end
          @dest = dest
          @action = if uri
                      {S: :URI, URI: uri}
                    elsif file
                      {S: :Launch, F: file, NewWindow: true}
                    end
          @border = case border
                    when false then [0, 0, 0]
                    when true then nil
                    when Array then border
                    else raise ArgumentError, "Invalid value for border: #{border}"
                    end
          @border_color = border_color
        end

        # Creates the needed link annotation if possible, i.e. if the context of the canvas is a
        # page.
        def call(canvas, box)
          return unless canvas.context.type == :Page
          page = canvas.context
          matrix = canvas.graphics_state.ctm
          quad_points = [*matrix.evaluate(0, 0), *matrix.evaluate(box.width, 0),
                         *matrix.evaluate(box.width, box.height), *matrix.evaluate(0, box.height)]
          x_minmax = quad_points.values_at(0, 2, 4, 6).minmax
          y_minmax = quad_points.values_at(1, 3, 5, 7).minmax
          annot = {
            Subtype: :Link,
            Rect: [x_minmax[0], y_minmax[0], x_minmax[1], y_minmax[1]],
            QuadPoints: quad_points,
            Dest: @dest,
            A: @action,
            Border: @border,
            C: @border_color && canvas.color_from_specification(@border_color).components,
          }
          (page[:Annots] ||= []) << page.document.add(annot)
        end

      end

      UNSET = ::Object.new # :nodoc:

      # Creates a new Style object.
      #
      # The +properties+ hash may be used to set the initial values of properties by using keys
      # equivalent to the property names.
      #
      # Example:
      #   Style.new(font_size: 15, align: :center, valign: center)
      def initialize(**properties)
        update(**properties)
        @scaled_item_widths = {}.compare_by_identity
      end

      # Duplicates the complex properties that can be modified, as well as the cache.
      def initialize_copy(other)
        super
        @scaled_item_widths = {}
        clear_cache

        @font_features = @font_features.dup if defined?(@font_features)
        @padding = @padding.dup if defined?(@padding)
        @margin = @margin.dup if defined?(@margin)
        @border = @border.dup if defined?(@border)
        @overlays = @overlays.dup if defined?(@overlays)
        @underlays = @underlays.dup if defined?(@underlays)
      end

      # :call-seq:
      #   style.update(**properties)    -> style
      #
      # Updates the style's properties using the key-value pairs specified by the +properties+ hash.
      def update(**properties)
        properties.each {|key, value| send(key, value) }
        self
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
      # :method: text_rendering_mode
      # :call-seq:
      #   text_rendering_mode(mode = nil)
      #
      # The text rendering mode, i.e. whether text should be filled, stroked, clipped, invisible or
      # a combination thereof, defaults to :fill. The returned values is always a normalized text
      # rendering mode value.
      #
      # See: HexaPDF::Content::Canvas#text_rendering_mode

      ##
      # :method: subscript
      # :call-seq:
      #   subscript(enable = false)
      #
      # Render the text as subscript, i.e. lower and in a smaller font size; defaults to false.
      #
      # If superscript is set, it will be deactivated.

      ##
      # :method: superscript
      # :call-seq:
      #   superscript(enable = false)
      #
      # Render the text as superscript, i.e. higher and in a smaller font size; defaults to false.
      #
      # If subscript is set, it will be deactivated.

      ##
      # :method: fill_color
      # :call-seq:
      #   fill_color(color = nil)
      #
      # The color used for filling (e.g. text), defaults to black.
      #
      # See: HexaPDF::Content::Canvas#fill_color

      ##
      # :method: fill_alpha
      # :call-seq:
      #   fill_alpha(alpha = nil)
      #
      # The alpha value applied to filling operations (e.g. text), defaults to 1 (i.e. 100%
      # opaque).
      #
      # See: HexaPDF::Content::Canvas#opacity

      ##
      # :method: stroke_color
      # :call-seq:
      #   stroke_color(color = nil)
      #
      # The color used for stroking (e.g. text outlines), defaults to black.
      #
      # See: HexaPDF::Content::Canvas#stroke_color

      ##
      # :method: stroke_alpha
      # :call-seq:
      #   stroke_alpha(alpha = nil)
      #
      # The alpha value applied to stroking operations (e.g. text outlines), defaults to 1 (i.e.
      # 100% opaque).
      #
      # See: HexaPDF::Content::Canvas#opacity

      ##
      # :method: stroke_width
      # :call-seq:
      #   stroke_width(width = nil)
      #
      # The line width used for stroking operations (e.g. text outlines), defaults to 1.
      #
      # See: HexaPDF::Content::Canvas#line_width

      ##
      # :method: stroke_cap_style
      # :call-seq:
      #   stroke_cap_style(style = nil)
      #
      # The line cap style used for stroking operations (e.g. text outlines), defaults to :butt. The
      # returned values is always a normalized line cap style value.
      #
      # See: HexaPDF::Content::Canvas#line_cap_style

      ##
      # :method: stroke_join_style
      # :call-seq:
      #   stroke_join_style(style = nil)
      #
      # The line join style used for stroking operations (e.g. text outlines), defaults to :miter.
      # The returned values is always a normalized line joine style value.
      #
      # See: HexaPDF::Content::Canvas#line_join_style

      ##
      # :method: stroke_miter_limit
      # :call-seq:
      #   stroke_miter_limit(limit = nil)
      #
      # The miter limit used for stroking operations (e.g. text outlines) when #stroke_join_style is
      # :miter, defaults to 10.0.
      #
      # See: HexaPDF::Content::Canvas#miter_limit

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

      ##
      # :method: line_spacing
      # :call-seq:
      #   line_spacing(type = nil, value = nil)
      #   line_spacing(type:, value: 1)
      #
      # The type of line spacing to be used for text lines, defaults to type :single.
      #
      # This method can set the line spacing in two ways:
      #
      # * Using two positional arguments +type+ and +value+.
      # * Or a hash with the keys +type+ and +value+.
      #
      # See LineSpacing for supported types of line spacing.

      ##
      # :method: last_line_gap
      # :call-seq:
      #   last_line_gap(enable = false)
      #
      # Add an appropriately sized gap after the last line of text if enabled, defaults to false.

      ##
      # :method: background_color
      # :call-seq:
      #   background_color(color = nil)
      #
      # The color used for backgrounds, defaults to +nil+ (i.e. no background).

      ##
      # :method: padding
      # :call-seq:
      #   padding(value = nil)
      #
      # The padding between the border and the contents, defaults to 0 for all four sides.

      ##
      # :method: margin
      # :call-seq:
      #   margin(value = nil)
      #
      # The margin around a box, defaults to 0 for all four sides.

      ##
      # :method: border
      # :call-seq:
      #   border(value = nil)
      #
      # The border around the contents, defaults to no border.

      ##
      # :method: overlays
      # :call-seq:
      #   overlays(layers = nil)
      #
      # A Layers object containing all the layers that should be drawn over the box; defaults to no
      # layers being drawn.

      ##
      # :method: underlays
      # :call-seq:
      #   underlays(layers = nil)
      #
      # A Layers object containing all the layers that should be drawn under the box; defaults to no
      # layers being drawn.

      ##
      # :method: position
      # :call-seq:
      #   position(value = nil)
      #
      # Specifies how a box should be positioned in a frame. The property #position_hint provides
      # additional, position specific data. Defaults to :default.
      #
      # Possible values:
      #
      # :default:: Position the box at the current position. The exact horizontal position is given
      #            via the position hint. Space to the left/right of the box can't be used for other
      #            boxes.
      #
      # :float:: Position the box at the current position but let it "float" so that the space to
      #          the left/right can still be used. The position hint specifies where the box should
      #          float.
      #
      # :flow:: Flows the content of the box inside the frame around objects.
      #
      # :absolute:: Position the box at an absolute position relative to the frame. The coordinates
      #             are given via the position hint.

      ##
      # :method: position_hint
      # :call-seq:
      #   position_hint(value = nil)
      #
      # Specifies additional information on how a box should be positioned in a frame. The exact
      # meaning depends on the value of the #position property.
      #
      # Possible values depending on the #position property:
      #
      # :default::
      #
      #   :left:: (default) Align the box to the left side of the available region.
      #   :right:: Align the box to the right side of the available region.
      #   :center:: Horizontally center the box in the available region.
      #
      # :float::
      #
      #   :left:: (default) Float the box to the left side of the available region.
      #   :right::  Float the box to the right side of the available region.
      #
      # :absolute::
      #
      #    An array with the x- and y-coordinates of the bottom left corner of the absolutely
      #    positioned box. The coordinates are taken as being relative to the bottom left corner of
      #    the frame into which the box is drawn.

      [
        [:font, "raise HexaPDF::Error, 'No font set'"],
        [:font_size, 10],
        [:character_spacing, 0],
        [:word_spacing, 0],
        [:horizontal_scaling, 100],
        [:text_rise, 0],
        [:font_features, {}],
        [:text_rendering_mode, "Content::TextRenderingMode::FILL",
         {setter: "Content::TextRenderingMode.normalize(value)"}],
        [:subscript, false,
         {setter: "value; superscript(false) if superscript",
          valid_values: [true, false]}],
        [:superscript, false,
         {setter: "value; subscript(false) if subscript",
          valid_values: [true, false]}],
        [:underline, false, {valid_values: [true, false]}],
        [:strikeout, false, {valid_values: [true, false]}],
        [:fill_color, "default_color"],
        [:fill_alpha, 1],
        [:stroke_color, "default_color"],
        [:stroke_alpha, 1],
        [:stroke_width, 1],
        [:stroke_cap_style, "Content::LineCapStyle::BUTT_CAP",
         {setter: "Content::LineCapStyle.normalize(value)"}],
        [:stroke_join_style, "Content::LineJoinStyle::MITER_JOIN",
         {setter: "Content::LineJoinStyle.normalize(value)"}],
        [:stroke_miter_limit, 10.0],
        [:stroke_dash_pattern, "Content::LineDashPattern.new",
         {setter: "Content::LineDashPattern.normalize(value, phase)", extra_args: ", phase = 0"}],
        [:align, :left, {valid_values: [:left, :center, :right, :justify]}],
        [:valign, :top, {valid_values: [:top, :center, :bottom]}],
        [:text_indent, 0],
        [:line_spacing, "LineSpacing.new(type: :single)",
         {setter: "LineSpacing.new(**(value.kind_of?(Symbol) ? {type: value, value: extra_arg} : value))",
          extra_args: ", extra_arg = nil"}],
        [:last_line_gap, false, {valid_values: [true, false]}],
        [:background_color, nil],
        [:padding, "Quad.new(0)", {setter: "Quad.new(value)"}],
        [:margin, "Quad.new(0)", {setter: "Quad.new(value)"}],
        [:border, "Border.new", {setter: "Border.new(**value)"}],
        [:overlays, "Layers.new", {setter: "Layers.new(value)"}],
        [:underlays, "Layers.new", {setter: "Layers.new(value)"}],
        [:position, :default, {valid_values: [:default, :float, :flow, :absolute]}],
        [:position_hint, nil],
      ].each do |name, default, options = {}|
        default = default.inspect unless default.kind_of?(String)
        setter = options.delete(:setter) || "value"
        extra_args = options.delete(:extra_args) || ""
        valid_values = options.delete(:valid_values)
        raise ArgumentError, "Invalid keywords: #{options.keys.join(', ')}" unless options.empty?
        valid_values_const = "#{name}_valid_values".upcase
        const_set(valid_values_const, valid_values)
        module_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def #{name}(value = UNSET#{extra_args})
            if value == UNSET
              @#{name} ||= #{default}
            elsif #{valid_values_const} && !#{valid_values_const}.include?(value)
              raise ArgumentError, "\#{value.inspect} is not a valid #{name} value " \\
                "(\#{#{valid_values_const}.map(&:inspect).join(', ')})"
            else
              @#{name} = #{setter}
              self
            end
          end
          def #{name}?
            defined?(@#{name})
          end
        EOF
        alias_method("#{name}=", name)
      end

      ##
      # :method: text_segmentation_algorithm
      # :call-seq:
      #   text_segmentation_algorithm(algorithm = nil) {|items| block }
      #
      # The algorithm to use for text segmentation purposes, defaults to
      # TextLayouter::SimpleTextSegmentation.
      #
      # When setting the algorithm, either an object that responds to #call(items) or a block can be
      # used.

      ##
      # :method: text_line_wrapping_algorithm
      # :call-seq:
      #   text_line_wrapping_algorithm(algorithm = nil) {|items, width_block| block }
      #
      # The line wrapping algorithm that should be used, defaults to
      # TextLayouter::SimpleLineWrapping.
      #
      # When setting the algorithm, either an object that responds to #call or a block can be used.
      # See TextLayouter::SimpleLineWrapping#call for the needed method signature.

      [
        [:text_segmentation_algorithm, 'TextLayouter::SimpleTextSegmentation'],
        [:text_line_wrapping_algorithm, 'TextLayouter::SimpleLineWrapping'],
      ].each do |name, default|
        default = default.inspect unless default.kind_of?(String)
        module_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def #{name}(value = UNSET, &block)
            if value == UNSET && !block
              @#{name} ||= #{default}
            else
              @#{name} = (value != UNSET ? value : block)
              self
            end
          end
          def #{name}?
            defined?(@#{name})
          end
        EOF
        alias_method("#{name}=", name)
      end

      # The calculated text rise, taking superscript and subscript into account.
      def calculated_text_rise
        if superscript
          text_rise + font_size * 0.33
        elsif subscript
          text_rise - font_size * 0.20
        else
          text_rise
        end
      end

      # The calculated font size, taking superscript and subscript into account.
      def calculated_font_size
        (superscript || subscript ? 0.583 : 1) * font_size
      end

      # Returns the correct offset from the baseline for the underline.
      def calculated_underline_position
        calculated_text_rise +
          calculated_font_size / 1000.0 * font.wrapped_font.underline_position *
          font.scaling_factor - calculated_underline_thickness / 2.0
      end

      # Returns the correct thickness for the underline.
      def calculated_underline_thickness
        calculated_font_size / 1000.0 * font.wrapped_font.underline_thickness * font.scaling_factor
      end

      # Returns the correct offset from the baseline for the strikeout line.
      def calculated_strikeout_position
        calculated_text_rise +
          calculated_font_size / 1000.0 * font.wrapped_font.strikeout_position *
          font.scaling_factor - calculated_strikeout_thickness / 2.0
      end

      # Returns the correct thickness for the strikeout line.
      def calculated_strikeout_thickness
        calculated_font_size / 1000.0 * font.wrapped_font.strikeout_thickness * font.scaling_factor
      end

      # The font size scaled appropriately.
      def scaled_font_size
        @scaled_font_size ||= calculated_font_size / 1000.0 * scaled_horizontal_scaling
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
        @scaled_font_ascender ||= font.wrapped_font.ascender * font.scaling_factor * font_size / 1000
      end

      # The descender of the font scaled appropriately.
      def scaled_font_descender
        @scaled_font_descender ||= font.wrapped_font.descender * font.scaling_factor * font_size / 1000
      end

      # The minimum y-coordinate, calculated using the scaled descender of the font.
      def scaled_y_min
        @scaled_y_min ||= scaled_font_descender + calculated_text_rise
      end

      # The maximum y-coordinate, calculated using the scaled descender of the font.
      def scaled_y_max
        @scaled_y_max ||= scaled_font_ascender + calculated_text_rise
      end

      # Returns the width of the item scaled appropriately (by taking font size, characters spacing,
      # word spacing and horizontal scaling into account).
      #
      # The item may be a (singleton) glyph object or an integer/float, i.e. items that can appear
      # inside a TextFragment.
      def scaled_item_width(item)
        @scaled_item_widths[item] ||=
          begin
            if item.kind_of?(Numeric)
              -item * scaled_font_size
            else
              item.width * scaled_font_size + scaled_character_spacing +
                (item.apply_word_spacing? ? scaled_word_spacing : 0)
            end
          end
      end

      # Clears all cached values.
      #
      # This method needs to be called if the following style properties are changed and values were
      # already cached: font, font_size, character_spacing, word_spacing, horizontal_scaling,
      # ascender, descender.
      def clear_cache
        @scaled_font_size = @scaled_character_spacing = @scaled_word_spacing = nil
        @scaled_horizontal_scaling = @scaled_font_ascender = @scaled_font_descender = nil
        @scaled_y_min = @scaled_y_max = nil
        @scaled_item_widths.clear
      end

      private

      # Returns the default color for an empty PDF page, i.e. black.
      def default_color
        GlobalConfiguration.constantize('color_space.map', :DeviceGray).new.default_color
      end

    end

  end
end
