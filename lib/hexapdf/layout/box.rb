# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2023 Thomas Leitner
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
require 'hexapdf/layout/style'
require 'geom2d/utils'

module HexaPDF
  module Layout

    # The base class for all layout boxes.
    #
    # == Box Model
    #
    # HexaPDF uses the following box model:
    #
    # * Each box can specify a width and height. Padding and border are inside, the margin outside
    #   of this rectangle.
    #
    # * The #content_width and #content_height accessors can be used to get the width and height of
    #   the content box without padding and the border.
    #
    # * If width or height is set to zero, they are determined automatically during layouting.
    #
    #
    # == Subclasses
    #
    # Each subclass should only take keyword arguments on initialization so that the boxes can be
    # instantiated from the common convenience method HexaPDF::Document::Layout#box. To use this
    # facility subclasses need to be registered with the configuration option 'layout.boxes.map'.
    #
    # The methods #fit, #supports_position_flow?, #split or #split_content, #empty?, and #draw or
    # #draw_content need to be customized according to the subclass's use case.
    #
    # #fit:: This method should return +true+ if fitting was successful. Additionally, the
    #        @fit_successful instance variable needs to be set to the fit result as it is used in
    #        #split.
    #
    # #supports_position_flow?::
    #        If the subclass supports the value :flow of the 'position' style property, this method
    #        needs to be overridden to return +true+.
    #
    # #split:: This method splits the content so that the current region is used as good as
    #          possible. The default implementation should be fine for most use-cases, so only
    #          #split_content needs to be implemented. The method #create_split_box should be used
    #          for getting a basic cloned box.
    #
    # #empty?:: This method should return +true+ if the subclass won't draw anything when #draw is
    #           called.
    #
    # #draw:: This method draws the content and the default implementation already handles things
    #         like drawing the border and background. Therefore it's best to implement #draw_content
    #         which should just draw the content.
    class Box

      include HexaPDF::Utils

      # Creates a new Box object, using the provided block as drawing block (see ::new).
      #
      # If +content_box+ is +true+, the width and height are taken to mean the content width and
      # height and the style's padding and border are added to them appropriately.
      #
      # The +style+ argument defines the Style object (see Style::create for details) for the box.
      # Any additional keyword arguments have to be style properties and are applied to the style
      # object.
      def self.create(width: 0, height: 0, content_box: false, style: nil, **style_properties, &block)
        style = Style.create(style).update(**style_properties)
        if content_box
          width += style.padding.left + style.padding.right +
            style.border.width.left + style.border.width.right
          height += style.padding.top + style.padding.bottom +
            style.border.width.top + style.border.width.bottom
        end
        new(width: width, height: height, style: style, &block)
      end

      # The width of the box, including padding and/or borders.
      attr_reader :width

      # The height of the box, including padding and/or borders.
      attr_reader :height

      # The style to be applied.
      #
      # Only the following properties are used:
      #
      # * Style#background_color
      # * Style#background_alpha
      # * Style#padding
      # * Style#border
      # * Style#overlays
      # * Style#underlays
      attr_reader :style

      # Hash with custom properties. The keys should be strings and can be arbitrary.
      #
      # This can be used to store arbitrary information on boxes for later use. For example, a
      # generic style layer could use one or more custom properties for its work.
      #
      # The Box class itself uses the following properties:
      #
      # optional_content::
      #
      #       If this property is set, it needs to be an optional content group dictionary, a String
      #       defining an (optionally existing) optional content group dictionary, or an optional
      #       content membership dictionary.
      #
      #       The whole content of the box, i.e. including padding, border, background..., is
      #       wrapped with the appropriate commands so that the optional content group or membership
      #       dictionary specifies whether the content is shown or not.
      #
      #       See: HexaPDF::Type::OptionalContentProperties
      attr_reader :properties

      # :call-seq:
      #    Box.new(width: 0, height: 0, style: nil, properties: nil) {|canv, box| block} -> box
      #
      # Creates a new Box object with the given width and height that uses the provided block when
      # it is asked to draw itself on a canvas (see #draw).
      #
      # Since the final location of the box is not known beforehand, the drawing operations inside
      # the block should draw inside the rectangle (0, 0, content_width, content_height) - note that
      # the width and height of the box may not be known beforehand.
      def initialize(width: 0, height: 0, style: nil, properties: nil, &block)
        @width = @initial_width = width
        @height = @initial_height = height
        @style = Style.create(style)
        @properties = properties || {}
        @draw_block = block
        @fit_successful = false
        @split_box = false
      end

      # Returns +true+ if this is a split box, i.e. the rest of another box after it was split.
      def split_box?
        @split_box
      end

      # Returns +false+ since a basic box doesn't support the 'position' style property value :flow.
      def supports_position_flow?
        false
      end

      # The width of the content box, i.e. without padding and/or borders.
      def content_width
        width = @width - reserved_width
        width < 0 ? 0 : width
      end

      # The height of the content box, i.e. without padding and/or borders.
      def content_height
        height = @height - reserved_height
        height < 0 ? 0 : height
      end

      # Fits the box into the Frame and returns +true+ if fitting was successful.
      #
      # The arguments +available_width+ and +available_height+ are the width and height of the
      # current region of the frame. The frame itself is provided as third argument.
      #
      # The default implementation uses the available width and height for the box width and height
      # if they were initially set to 0. Otherwise the specified dimensions are used.
      def fit(available_width, available_height, _frame)
        @width = (@initial_width > 0 ? @initial_width : available_width)
        @height = (@initial_height > 0 ? @initial_height : available_height)
        @fit_successful = (@width <= available_width && @height <= available_height)
      end

      # Tries to split the box into two, the first of which needs to fit into the current region of
      # the frame, and returns the parts as array.
      #
      # If the first item in the result array is not +nil+, it needs to be this box and it means
      # that even when #fit fails, a part of the box may still fit. Note that #fit should not be
      # called before #draw on the first box since it is already fitted. If not even a part of this
      # box fits into the current region, +nil+ should be returned as the first array element.
      #
      # Possible return values:
      #
      # [self]:: The box fully fits into the current region.
      # [nil, self]:: The box can't be split or no part of the box fits into the current region.
      # [self, new_box]:: A part of the box fits and a new box is returned for the rest.
      #
      # This default implementation provides the basic functionality based on the #fit result that
      # should be sufficient for most subclasses; only #split_content needs to be implemented if
      # necessary.
      def split(available_width, available_height, frame)
        if @fit_successful
          [self, nil]
        elsif (style.position != :flow &&
               (float_compare(@width, available_width) > 0 ||
                float_compare(@height, available_height) > 0)) ||
            content_height == 0 || content_width == 0
          [nil, self]
        else
          split_content(available_width, available_height, frame)
        end
      end

      # Draws the content of the box onto the canvas at the position (x, y).
      #
      # The coordinate system is translated so that the origin is at the bottom left corner of the
      # **content box** during the drawing operations when +@draw_block+ is used.
      #
      # The block specified when creating the box is invoked with the canvas and the box as
      # arguments. Subclasses can specify an on-demand drawing method by setting the +@draw_block+
      # instance variable to +nil+ or a valid block. This is useful to avoid unnecessary set-up
      # operations when the block does nothing.
      def draw(canvas, x, y)
        if (oc = properties['optional_content'])
          canvas.optional_content(oc)
        end

        if style.background_color? && style.background_color
          canvas.save_graphics_state do
            canvas.opacity(fill_alpha: style.background_alpha).
              fill_color(style.background_color).rectangle(x, y, width, height).fill
          end
        end

        style.underlays.draw(canvas, x, y, self) if style.underlays?
        style.border.draw(canvas, x, y, width, height) if style.border?

        draw_content(canvas, x + reserved_width_left, y + reserved_height_bottom)

        style.overlays.draw(canvas, x, y, self) if style.overlays?

        canvas.end_optional_content if oc
      end

      # Returns +true+ if no drawing operations are performed.
      def empty?
        !(@draw_block ||
          (style.background_color? && style.background_color) ||
          (style.underlays? && !style.underlays.none?) ||
          (style.border? && !style.border.none?) ||
          (style.overlays? && !style.overlays.none?))
      end

      private

      # Returns the width that is reserved by the padding and border style properties.
      def reserved_width
        reserved_width_left + reserved_width_right
      end

      # Returns the height that is reserved by the padding and border style properties.
      def reserved_height
        reserved_height_top + reserved_height_bottom
      end

      # Returns the width that is reserved by the padding and the border style properties on the
      # left side of the box.
      def reserved_width_left
        result = 0
        result += style.padding.left if style.padding?
        result += style.border.width.left if style.border?
        result
      end

      # Returns the width that is reserved by the padding and the border style properties on the
      # right side of the box.
      def reserved_width_right
        result = 0
        result += style.padding.right if style.padding?
        result += style.border.width.right if style.border?
        result
      end

      # Returns the height that is reserved by the padding and the border style properties on the
      # top side of the box.
      def reserved_height_top
        result = 0
        result += style.padding.top if style.padding?
        result += style.border.width.top if style.border?
        result
      end

      # Returns the height that is reserved by the padding and the border style properties on the
      # bottom side of the box.
      def reserved_height_bottom
        result = 0
        result += style.padding.bottom if style.padding?
        result += style.border.width.bottom if style.border?
        result
      end

      # Draws the content of the box at position [x, y] which is the bottom-left corner of the
      # content box.
      def draw_content(canvas, x, y)
        if @draw_block
          canvas.translate(x, y) { @draw_block.call(canvas, self) }
        end
      end

      # Splits the content of the box.
      #
      # This is just a stub implementation, returning [nil, self] since we can't know how to split
      # the content when it didn't fit.
      #
      # Subclasses that support splitting content need to provide an appropriate implementation and
      # use #create_split_box to create a cloned box to supply as the second argument.
      def split_content(_available_width, _available_height, _frame)
        [nil, self]
      end

      # Creates a new box based on this one and resets the data back to their original values.
      #
      # The variable +@split_box+ is set to +split_box_value+ (defaults to +true+) to make the new
      # box aware that it is a split box. If needed, subclasses can set the variable to other truthy
      # values to convey more meaning.
      #
      # This method should be used by subclasses to create their split box.
      def create_split_box(split_box_value: true)
        box = clone
        box.instance_variable_set(:@width, @initial_width)
        box.instance_variable_set(:@height, @initial_height)
        box.instance_variable_set(:@fit_successful, nil)
        box.instance_variable_set(:@split_box, split_box_value)
        box
      end

    end

  end
end
