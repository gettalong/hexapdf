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

require 'hexapdf/content/graphics_state'
require 'hexapdf/content/operator'
require 'hexapdf/serializer'
require 'hexapdf/utils/math_helpers'
require 'hexapdf/utils/graphics_helpers'
require 'hexapdf/content/graphic_object'
require 'hexapdf/stream'

module HexaPDF
  module Content

    # This class provides the basic drawing operations supported by PDF.
    #
    # == General Information
    #
    # A canvas object is used for modifying content streams on a level higher than text. It would
    # be possible to write a content stream by hand since PDF uses a simplified reversed polish
    # notation for specifying operators: First come the operands, then comes the operator and no
    # operator returns any result. However, it is easy to make mistakes this way and one has to
    # know all operators and their operands.
    #
    # This is rather tedious and therefore this class exists. It allows one to modify a content
    # stream by invoking methods that should be familiar to anyone that has ever used a graphic
    # API. There are methods for moving the current point, drawing lines and curves, setting the
    # color, line width and so on.
    #
    # The PDF operators themselves are implemented as classes, see Operator. The canvas class uses
    # the Operator::BaseOperator#invoke and Operator::BaseOperator#serialize methods for applying
    # changes and serialization, with one exception: color setters don't invoke the corresponding
    # operator implementation but directly work on the graphics state.
    #
    #
    # == PDF Graphics
    #
    # === Graphics Operators and Objects
    #
    # There are about 60 PDF content stream operators. Some are used for changing the graphics
    # state, some for drawing paths and others for showing text. This is all abstracted through
    # the Canvas class.
    #
    # PDF knows about five different graphics objects: path objects, text objects, external
    # objects, inline image objects and shading objects. If none of the five graphics objects is
    # current, the content stream is at the so called page description level (in between graphics
    # objects).
    #
    # Additionally the PDF operators are divided into several groups, like path painting or text
    # showing operators, and such groups of operators are allowed to be used only in certain
    # graphics objects or the page description level.
    #
    # Have a look at the PDF specification (PDF1.7 s8.2) for more details.
    #
    # HexaPDF tries to ensure the proper use of the operators and graphics objects and if it
    # cannot do it, an error is raised. So if you don't modify a content stream directly but via
    # the Canvas methods, you generally don't have to worry about the low-level inner workings.
    #
    # === Graphics State
    #
    # Some operators modify the so called graphics state (see Content::GraphicsState). The graphics
    # state is a collection of settings that is used during processing or creating a content stream.
    # For example, the path painting operators don't have operands to specify the line width or the
    # stroke color but take this information from the graphics state.
    #
    # One important thing about the graphics state is that it is only possible to restore a prior
    # state using the save and restore methods. It is not possible to reset the graphics state
    # while creating the content stream!
    #
    # === Paths
    #
    # A PDF path object consists of one or more subpaths. Each subpath can be a rectangle or can
    # consist of lines and cubic bezier curves. No other types of subpaths are known to PDF.
    # However, the Canvas class contains additional methods that use the basic path construction
    # methods for drawing other paths like circles.
    #
    # When a subpath is started, the current graphics object is changed to :path. After all path
    # constructions are finished, a path painting method needs to be invoked to change back to the
    # page description level. Optionally, the path painting method may be preceeded by a clipping
    # path method to change the current clipping path (see #clip_path).
    #
    # There are four kinds of path painting methods:
    #
    # * Those that stroke the path,
    # * those that fill the path,
    # * those that stroke and fill the path and
    # * one to neither stroke or fill the path (used, for example, to just set the clipping path).
    #
    # In addition filling may be done using either the nonzero winding number rule or the even-odd
    # rule.
    #
    #
    # == Special Graphics State Methods
    #
    # These methods are only allowed when the current graphics object is :none, i.e. operations are
    # done on the page description level.
    #
    # * #save_graphics_state
    # * #restore_graphics_state
    # * #transform, #rotate, #scale, #translate, #skew
    #
    # See: PDF1.7 s8, s9
    class Canvas

      include HexaPDF::Utils::MathHelpers
      include HexaPDF::Utils::GraphicsHelpers

      # The context for which the canvas was created (a HexaPDF::Type::Page or HexaPDF::Type::Form
      # object).
      attr_reader :context

      # The serialized contents produced by the various canvas operations up to this point.
      #
      # Note that the returned string may not be a completely valid PDF content stream since a
      # graphic object may be open or the graphics state not completely restored.
      #
      # See: #stream_data
      attr_reader :contents

      # A StreamData object representing the serialized contents produced by the various canvas
      # operations.
      #
      # In contrast to #contents, it is ensured that an open graphics object is closed and all saved
      # graphics states are restored when the contents of the stream data object is read. *Note*
      # that this means that reading the stream data object may change the state of the canvas.
      attr_reader :stream_data

      # The Content::GraphicsState object containing the current graphics state.
      #
      # The graphics state must not be changed directly, only by using the provided methods. If it
      # is changed directly, the output will not be correct.
      attr_reader :graphics_state

      # The current graphics object.
      #
      # The graphics object should not be changed directly. It is automatically updated according
      # to the invoked methods.
      #
      # This attribute can have the following values:
      #
      # :none:: No current graphics object, i.e. the page description level.
      # :path:: The current graphics object is a path.
      # :clipping_path:: The current graphics object is a clipping path.
      # :text:: The current graphics object is a text object.
      #
      # See: PDF1.7 s8.2
      attr_accessor :graphics_object

      # The current point [x, y] of the path.
      #
      # This attribute holds the current point which is only valid if the current graphics objects
      # is :path.
      #
      # When the current point changes, the array is modified in place instead of creating a new
      # array!
      attr_reader :current_point

      # The operator name/implementation map used when invoking or serializing an operator.
      attr_reader :operators

      # Creates a new Canvas object for the given context object (either a Page or a Form).
      def initialize(context)
        @context = context
        @operators = Operator::DEFAULT_OPERATORS.dup
        @graphics_state = GraphicsState.new
        @graphics_object = :none
        @font = nil
        @font_stack = []
        @serializer = HexaPDF::Serializer.new
        @current_point = [0, 0]
        @start_point = [0, 0]
        @contents = ''.b
        @stream_data = HexaPDF::StreamData.new do
          case graphics_object
          when :path, :clipping_path then end_path
          when :text then end_text
          end
          restore_graphics_state while graphics_state.saved_states?
          @contents
        end
      end

      # Returns the resource dictionary of the context object.
      def resources
        @context.resources
      end

      # :call-seq:
      #   canvas.save_graphics_state              => canvas
      #   canvas.save_graphics_state { block }    => canvas
      #
      # Saves the current graphics state and returns self.
      #
      # If invoked without a block a corresponding call to #restore_graphics_state must be done.
      # Otherwise the graphics state is automatically restored when the block is finished.
      #
      # Examples:
      #
      #   # With a block
      #   canvas.save_graphics_state do
      #     canvas.line_width(10)
      #     canvas.line(100, 100, 200, 200)
      #   end
      #
      #   # Same without a block
      #   canvas.save_graphics_state
      #   canvas.line_width(10)
      #   canvas.line(100, 100, 200, 200)
      #   canvas.restore_graphics_state
      #
      # See: PDF1.7 s8.4.2, #restore_graphics_state
      def save_graphics_state
        raise_unless_at_page_description_level
        invoke0(:q)
        @font_stack.push(@font)
        if block_given?
          yield
          restore_graphics_state
        end
        self
      end

      # :call-seq:
      #   canvas.restore_graphics_state      => canvas
      #
      # Restores the current graphics state and returns self.
      #
      # Must not be invoked more times than #save_graphics_state.
      #
      # See: PDF1.7 s8.4.2, #save_graphics_state
      def restore_graphics_state
        raise_unless_at_page_description_level
        invoke0(:Q)
        @font = @font_stack.pop
        self
      end

      # :call-seq:
      #   canvas.transform(a, b, c, d, e, f)              => canvas
      #   canvas.transform(a, b, c, d, e, f) { block }    => canvas
      #
      # Transforms the user space by applying the given matrix to the current transformation
      # matrix and returns self.
      #
      # If invoked with a block, the transformation is only active during the block by saving and
      # restoring the graphics state.
      #
      # The given values are interpreted as a matrix in the following way:
      #
      #   a b 0
      #   c d 0
      #   e f 1
      #
      # Examples:
      #
      #   canvas.transform(1, 0, 0, 1, 100, 100) do  # Translate origin to (100, 100)
      #     canvas.line(0, 0, 100, 100)              # Actually from (100, 100) to (200, 200)
      #   end
      #   canvas.line(0, 0, 100, 100)                # Again from (0, 0) to (100, 100)
      #
      # See: PDF1.7 s8.3, s8.4.4
      def transform(a, b, c, d, e, f)
        raise_unless_at_page_description_level
        save_graphics_state if block_given?
        invoke(:cm, a, b, c, d, e, f)
        if block_given?
          yield
          restore_graphics_state
        end
        self
      end

      # :call-seq:
      #   canvas.rotate(angle, origin: nil)               => canvas
      #   canvas.rotate(angle, origin: nil) { block }     => canvas
      #
      # Rotates the user space +angle+ degrees around the coordinate system origin or around the
      # given point and returns self.
      #
      # If invoked with a block, the rotation of the user space is only active during the block by
      # saving and restoring the graphics state.
      #
      # Note that the origin of the coordinate system itself doesn't change!
      #
      # origin::
      #   The point around which the user space should be rotated.
      #
      # Examples:
      #
      #   canvas.rotate(90) do                 # Positive x-axis is now pointing upwards
      #     canvas.line(0, 0, 100, 0)          # Actually from (0, 0) to (0, 100)
      #   end
      #   canvas.line(0, 0, 100, 0)            # Again from (0, 0) to (100, 0)
      #
      #   canvas.rotate(90, origin: [100, 100]) do
      #     canvas.line(100, 100, 200, 0)      # Actually from (100, 100) to (100, 200)
      #   end
      #
      # See: #transform
      def rotate(angle, origin: nil, &block)
        cos = Math.cos(deg_to_rad(angle))
        sin = Math.sin(deg_to_rad(angle))

        # Rotation is performed around the coordinate system origin but points are translated so
        # that the rotated rotation origin coincides with the unrotated one.
        tx = (origin ? origin[0] - (origin[0] * cos - origin[1] * sin) : 0)
        ty = (origin ? origin[1] - (origin[0] * sin + origin[1] * cos) : 0)
        transform(cos, sin, -sin, cos, tx, ty, &block)
      end

      # :call-seq:
      #   canvas.scale(sx, sy = sx, origin: nil)              => canvas
      #   canvas.scale(sx, sy = sx, origin: nil) { block }    => canvas
      #
      # Scales the user space +sx+ units in the horizontal and +sy+ units in the vertical
      # direction and returns self. If the optional +origin+ is specified, scaling is done from
      # that point.
      #
      # If invoked with a block, the scaling is only active during the block by saving and
      # restoring the graphics state.
      #
      # Note that the origin of the coordinate system itself doesn't change!
      #
      # origin::
      #   The point from which the user space should be scaled.
      #
      # Examples:
      #
      #   canvas.scale(2, 3) do                # Point (1, 1) is now actually (2, 3)
      #     canvas.line(50, 50, 100, 100)      # Actually from (100, 150) to (200, 300)
      #   end
      #   canvas.line(0, 0, 100, 0)            # Again from (0, 0) to (100, 0)
      #
      #   canvas.scale(2, 3, origin: [50, 50]) do
      #     canvas.line(50, 50, 100, 100)      # Actually from (50, 50) to (200, 300)
      #   end
      #
      # See: #transform
      def scale(sx, sy = sx, origin: nil, &block)
        # As with rotation, scaling is performed around the coordinate system origin but points
        # are translated so that the scaled scaling origin coincides with the unscaled one.
        tx = (origin ? origin[0] - origin[0] * sx : 0)
        ty = (origin ? origin[1] - origin[1] * sy : 0)
        transform(sx, 0, 0, sy, tx, ty, &block)
      end

      # :call-seq:
      #   canvas.translate(x, y)               => canvas
      #   canvas.translate(x, y) { block }     => canvas
      #
      # Translates the user space coordinate system origin to the given +x+ and +y+ coordinates
      # and returns self.
      #
      # If invoked with a block, the translation of the user space is only active during the block
      # by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.translate(100, 100) do        # Origin is now at (100, 100)
      #     canvas.line(0, 0, 100, 0)          # Actually from (100, 100) to (200, 100)
      #   end
      #   canvas.line(0, 0, 100, 0)            # Again from (0, 0) to (100, 0)
      #
      # See: #transform
      def translate(x, y, &block)
        transform(1, 0, 0, 1, x, y, &block)
      end

      # :call-seq:
      #   canvas.skew(a, b, origin: nil)               => canvas
      #   canvas.skew(a, b, origin: nil) { block }     => canvas
      #
      # Skews the the x-axis by +a+ degrees and the y-axis by +b+ degress and returns self. If the
      # optional +origin+ is specified, skewing is done from that point.
      #
      # If invoked with a block, the skewing is only active during the block by saving and
      # restoring the graphics state.
      #
      # Note that the origin of the coordinate system itself doesn't change!
      #
      # origin::
      #   The point from which the axes are skewed.
      #
      # Examples:
      #
      #   canvas.skew(0, 45) do                 # Point (1, 1) is now actually (2, 1)
      #     canvas.line(50, 50, 100, 100)       # Actually from (100, 50) to (200, 100)
      #   end
      #   canvas.line(0, 0, 100, 0)             # Again from (0, 0) to (100, 0)
      #
      #   canvas.skew(0, origin: [50, 50]) do
      #     canvas.line(50, 50, 100, 100)       # Actually from (50, 50) to (200, 300)
      #   end
      #
      # See: #transform
      def skew(a, b, origin: nil, &block)
        tan_a = Math.tan(deg_to_rad(a))
        tan_b = Math.sin(deg_to_rad(b))

        # As with rotation, skewing is performed around the coordinate system origin but points
        # are translated so that the skewed skewing origin coincides with the unskewed one.
        tx = (origin ? -origin[1] * tan_b : 0)
        ty = (origin ? -origin[0] * tan_a : 0)
        transform(1, tan_a, tan_b, 1, tx, ty, &block)
      end

      # :call-seq:
      #   canvas.line_width                    => current_line_width
      #   canvas.line_width(width)             => canvas
      #   canvas.line_width(width) { block }   => canvas
      #
      # The line width determines the thickness of a stroked path.
      #
      # Returns the current line width (see Content::GraphicsState#line_width) when no argument is
      # given. Otherwise sets the line width to the given +width+ and returns self. The setter
      # version can also be called in the line_width= form.
      #
      # If the +width+ and a block are provided, the changed line width is only active during the
      # block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.line_width(10)
      #   canvas.line_width          # => 10
      #   canvas.line_width = 5      # => 5
      #
      #   canvas.line_width(10) do
      #     canvas.line_width        # => 10
      #   end
      #   canvas.line_width          # => 5
      #
      # See: PDF1.7 s8.4.3.2
      def line_width(width = nil, &block)
        gs_getter_setter(:line_width, :w, width, &block)
      end
      alias line_width= line_width

      # :call-seq:
      #   canvas.line_cap_style                    => current_line_cap_style
      #   canvas.line_cap_style(style)             => canvas
      #   canvas.line_cap_style(style) { block }   => canvas
      #
      # The line cap style specifies how the ends of stroked open paths should look like. The
      # +style+ parameter can either be a valid integer or one of the symbols +:butt+, +:round+ or
      # +:projecting_square+ (see Content::LineCapStyle.normalize for details). Note that the return
      # value is always a normalized line cap style.
      #
      # Returns the current line cap style (see Content::GraphicsState#line_cap_style) when no
      # argument is given. Otherwise sets the line cap style to the given +style+ and returns self.
      # The setter version can also be called in the line_cap_style= form.
      #
      # If the +style+ and a block are provided, the changed line cap style is only active during
      # the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.line_cap_style(:butt)
      #   canvas.line_cap_style               # => #<NamedValue @name=:butt, @value=0>
      #   canvas.line_cap_style = :round      # => #<NamedValue @name=:round, @value=1>
      #
      #   canvas.line_cap_style(:butt) do
      #     canvas.line_cap_style             # => #<NamedValue @name=:butt, @value=0>
      #   end
      #   canvas.line_cap_style               # => #<NamedValue @name=:round, @value=1>
      #
      # See: PDF1.7 s8.4.3.3
      def line_cap_style(style = nil, &block)
        gs_getter_setter(:line_cap_style, :J, style && LineCapStyle.normalize(style), &block)
      end
      alias line_cap_style= line_cap_style

      # :call-seq:
      #   canvas.line_join_style                    => current_line_join_style
      #   canvas.line_join_style(style)             => canvas
      #   canvas.line_join_style(style) { block }   => canvas
      #
      # The line join style specifies the shape that is used at the corners of stroked paths. The
      # +style+ parameter can either be a valid integer or one of the symbols +:miter+, +:round+ or
      # +:bevel+ (see Content::LineJoinStyle.normalize for details). Note that the return value is
      # always a normalized line join style.
      #
      # Returns the current line join style (see Content::GraphicsState#line_join_style) when no
      # argument is given. Otherwise sets the line join style to the given +style+ and returns self.
      # The setter version can also be called in the line_join_style= form.
      #
      # If the +style+ and a block are provided, the changed line join style is only active during
      # the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.line_join_style(:miter)
      #   canvas.line_join_style               # => #<NamedValue @name=:miter, @value=0>
      #   canvas.line_join_style = :round      # => #<NamedValue @name=:round, @value=1>
      #
      #   canvas.line_join_style(:bevel) do
      #     canvas.line_join_style             # => #<NamedValue @name=:bevel, @value=2>
      #   end
      #   canvas.line_join_style               # => #<NamedValue @name=:round, @value=1>
      #
      # See: PDF1.7 s8.4.3.4
      def line_join_style(style = nil, &block)
        gs_getter_setter(:line_join_style, :j, style && LineJoinStyle.normalize(style), &block)
      end
      alias line_join_style= line_join_style

      # :call-seq:
      #   canvas.miter_limit                    => current_miter_limit
      #   canvas.miter_limit(limit)             => canvas
      #   canvas.miter_limit(limit) { block }   => canvas
      #
      # The miter limit specifies the maximum ratio of the miter length to the line width for
      # mitered line joins (see #line_join_style). When the limit is exceeded, a bevel join is
      # used instead of a miter join.
      #
      # Returns the current miter limit (see Content::GraphicsState#miter_limit) when no argument is
      # given. Otherwise sets the miter limit to the given +limit+ and returns self. The setter
      # version can also be called in the miter_limit= form.
      #
      # If the +limit+ and a block are provided, the changed miter limit is only active during the
      # block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.miter_limit(10)
      #   canvas.miter_limit          # => 10
      #   canvas.miter_limit = 5      # => 5
      #
      #   canvas.miter_limit(10) do
      #     canvas.miter_limit        # => 10
      #   end
      #   canvas.miter_limit          # => 5
      #
      # See: PDF1.7 s8.4.3.5
      def miter_limit(limit = nil, &block)
        gs_getter_setter(:miter_limit, :M, limit, &block)
      end
      alias miter_limit= miter_limit

      # :call-seq:
      #   canvas.line_dash_pattern                                  => current_line_dash_pattern
      #   canvas.line_dash_pattern(line_dash_pattern)               => canvas
      #   canvas.line_dash_pattern(length, phase = 0)               => canvas
      #   canvas.line_dash_pattern(array, phase = 0)                => canvas
      #   canvas.line_dash_pattern(value, phase = 0) { block }      => canvas
      #
      # The line dash pattern defines the appearance of a stroked path (line _or_ curve), ie. if
      # it is solid or if it contains dashes and gaps.
      #
      # There are multiple ways to set the line dash pattern:
      #
      # * By providing a Content::LineDashPattern object
      # * By providing a single Integer/Float that is used for both dashes and gaps
      # * By providing an array of Integers/Floats that specify the alternating dashes and gaps
      #
      # The phase (i.e. the distance into the dashes/gaps at which to start) can additionally be
      # set in the last two cases.
      #
      # A solid line can be achieved by using 0 for the length or by using an empty array.
      #
      # Returns the current line dash pattern (see Content::GraphicsState#line_dash_pattern) when no
      # argument is given. Otherwise sets the line dash pattern using the given arguments and
      # returns self. The setter version can also be called in the line_dash_pattern= form (but only
      # without the second argument!).
      #
      # If arguments and a block are provided, the changed line dash pattern is only active during
      # the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.line_dash_pattern(10)
      #   canvas.line_dash_pattern                # => LineDashPattern.new([10], 0)
      #   canvas.line_dash_pattern(10, 2)
      #   canvas.line_dash_pattern([5, 3, 1], 2)
      #   canvas.line_dash_pattern = LineDashPattern.new([5, 3, 1], 1)
      #
      #   canvas.line_dash_pattern(10) do
      #     canvas.line_dash_pattern              # => LineDashPattern.new([10], 0)
      #   end
      #   canvas.line_dash_pattern                # => LineDashPattern.new([5, 3, 1], 1)
      #
      # See: PDF1.7 s8.4.3.5, LineDashPattern
      def line_dash_pattern(value = nil, phase = 0, &block)
        gs_getter_setter(:line_dash_pattern, :d, value && LineDashPattern.normalize(value, phase),
                         &block)
      end
      alias line_dash_pattern= line_dash_pattern

      # :call-seq:
      #   canvas.rendering_intent                       => current_rendering_intent
      #   canvas.rendering_intent(intent)               => canvas
      #   canvas.rendering_intent(intent) { block }     => canvas
      #
      # The rendering intent is used to specify the intent on how colors should be rendered since
      # sometimes compromises have to be made when the capabilities of an output device are not
      # sufficient. The +intent+ parameter can be one of the following symbols:
      #
      # * +:AbsoluteColorimetric+
      # * +:RelativeColorimetric+
      # * +:Saturation+
      # * +:Perceptual+
      #
      # Returns the current rendering intent (see Content::GraphicsState#rendering_intent) when no
      # argument is given. Otherwise sets the rendering intent using the +intent+ argument and
      # returns self. The setter version can also be called in the rendering_intent= form.
      #
      # If the +intent+ and a block are provided, the changed rendering intent is only active
      # during the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.rendering_intent(:Perceptual)
      #   canvas.rendering_intent                      # => :Perceptual
      #   canvas.rendering_intent = :Saturation        # => :Saturation
      #
      #   canvas.rendering_intent(:Perceptual) do
      #     canvas.rendering_intent                    # => :Perceptual
      #   end
      #   canvas.rendering_intent                      # => :Saturation
      #
      # See: PDF1.7 s8.6.5.8, RenderingIntent
      def rendering_intent(intent = nil, &bk)
        gs_getter_setter(:rendering_intent, :ri, intent && RenderingIntent.normalize(intent), &bk)
      end
      alias rendering_intent= rendering_intent

      # :call-seq:
      #   canvas.stroke_color                             => current_stroke_color
      #   canvas.stroke_color(gray)                       => canvas
      #   canvas.stroke_color(r, g, b)                    => canvas
      #   canvas.stroke_color(c, m, y, k)                 => canvas
      #   canvas.stroke_color(string)                     => canvas
      #   canvas.stroke_color(color_object)               => canvas
      #   canvas.stroke_color(array)                      => canvas
      #   canvas.stroke_color(color_spec) { block }       => canvas
      #
      # The stroke color defines the color used for stroking operations, i.e. for painting paths.
      #
      # There are several ways to define the color that should be used:
      #
      # * A single numeric argument specifies a gray color (see
      #   Content::ColorSpace::DeviceGray::Color).
      # * Three numeric arguments specify an RGB color (see Content::ColorSpace::DeviceRGB::Color).
      # * A string in the format "RRGGBB" where "RR" is the hexadecimal number for the red, "GG"
      #   for the green and "BB" for the blue color value also specifies an RGB color.
      # * As does a string in the format "RGB" where "RR", "GG" and "BB" would be used as the
      #   hexadecimal numbers for the red, green and blue color values of an RGB color.
      # * Any other string is treated as a CSS Color Module Level 3 color name, see
      #   https://www.w3.org/TR/css-color-3/#svg-color.
      # * Four numeric arguments specify a CMYK color (see Content::ColorSpace::DeviceCMYK::Color).
      # * A color object is used directly (normally used for color spaces other than DeviceRGB,
      #   DeviceCMYK and DeviceGray).
      # * An array is treated as if its items were specified separately as arguments.
      #
      # Returns the current stroke color (see Content::GraphicsState#stroke_color) when no argument
      # is given. Otherwise sets the stroke color using the given arguments and returns self. The
      # setter version can also be called in the stroke_color= form.
      #
      # If the arguments and a block are provided, the changed stroke color is only active during
      # the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   # With no arguments just returns the current color
      #   canvas.stroke_color                        # => DeviceGray.color(0.0)
      #
      #   # Same gray color because integer values are normalized to the range of 0.0 to 1.0
      #   canvas.stroke_color(102)
      #   canvas.stroke_color(0.4)
      #
      #   # Specifying RGB colors
      #   canvas.stroke_color(255, 255, 0)
      #   canvas.stroke_color("FFFF00")
      #
      #   # Specifying CMYK colors
      #   canvas.stroke_color(255, 255, 0, 128)
      #
      #   # Can use a color object directly
      #   color = HexaPDF::Content::ColorSpace::DeviceRGB.color(255, 255, 0)
      #   canvas.stroke_color(color)
      #
      #   # An array argument is destructured - these calls are all equal
      #   cnavas.stroke_color(255, 255, 0)
      #   canvas.stroke_color([255, 255, 0])
      #   canvas.stroke_color = [255, 255, 0]
      #
      #   # As usual, can be invoked with a block to limit the effects
      #   canvas.stroke_color(102) do
      #     canvas.stroke_color                      # => ColorSpace::DeviceGray.color(0.4)
      #   end
      #
      # See: PDF1.7 s8.6, ColorSpace
      def stroke_color(*color, &block)
        color_getter_setter(:stroke_color, color, :RG, :G, :K, :CS, :SCN, &block)
      end
      alias stroke_color= stroke_color

      # The fill color defines the color used for non-stroking operations, i.e. for filling paths.
      #
      # Works exactly the same #stroke_color but for the fill color. See #stroke_color for
      # details on invocation and use.
      def fill_color(*color, &block)
        color_getter_setter(:fill_color, color, :rg, :g, :k, :cs, :scn, &block)
      end
      alias fill_color= fill_color

      # :call-seq:
      #   canvas.opacity                                           => current_values
      #   canvas.opacity(fill_alpha:)                              => canvas
      #   canvas.opacity(stroke_alpha:)                            => canvas
      #   canvas.opacity(fill_alpha:, stroke_alpha:)               => canvas
      #   canvas.opacity(fill_alpha:, stroke_alpha:) { block }     => canvas
      #
      # The fill and stroke alpha values determine how opaque drawn elements will be. Note that
      # the fill alpha value applies not just to fill values but to all non-stroking operations
      # (e.g. images, ...).
      #
      # Returns the current fill alpha (see Content::GraphicsState#fill_alpha) and stroke alpha (see
      # Content::GraphicsState#stroke_alpha) values using a hash with the keys +:fill_alpha+ and
      # +:stroke_alpha+ when no argument is given. Otherwise sets the fill and stroke alpha values
      # and returns self. The setter version can also be called in the #opacity= form.
      #
      # If the values are set and a block is provided, the changed alpha values are only active
      # during the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.opacity(fill_alpha: 0.5)
      #   canvas.opacity                               # => {fill_alpha: 0.5, stroke_alpha: 1.0}
      #   canvas.opacity(fill_alpha: 0.4, stroke_alpha: 0.9)
      #   canvas.opacity                               # => {fill_alpha: 0.4, stroke_alpha: 0.9}
      #
      #   canvas.opacity(stroke_alpha: 0.7) do
      #     canvas.opacity                             # => {fill_alpha: 0.4, stroke_alpha: 0.7}
      #   end
      #   canvas.opacity                               # => {fill_alpha: 0.4, stroke_alpha: 0.9}
      #
      # See: PDF1.7 s11.6.4.4
      def opacity(fill_alpha: nil, stroke_alpha: nil)
        if !fill_alpha.nil? || !stroke_alpha.nil?
          raise_unless_at_page_description_level_or_in_text
          save_graphics_state if block_given?
          if (!fill_alpha.nil? && graphics_state.fill_alpha != fill_alpha) ||
              (!stroke_alpha.nil? && graphics_state.stroke_alpha != stroke_alpha)
            dict = {Type: :ExtGState}
            dict[:CA] = stroke_alpha unless stroke_alpha.nil?
            dict[:ca] = fill_alpha unless fill_alpha.nil?
            dict[:AIS] = false if graphics_state.alpha_source
            invoke1(:gs, resources.add_ext_gstate(dict))
          end
          if block_given?
            yield
            restore_graphics_state
          end
          self
        elsif block_given?
          raise ArgumentError, "Block only allowed with an argument"
        else
          {fill_alpha: graphics_state.fill_alpha, stroke_alpha: graphics_state.stroke_alpha}
        end
      end

      # :call-seq:
      #   canvas.move_to(x, y)       => canvas
      #
      # Begins a new subpath (and possibly a new path) by moving the current point to the given
      # point.
      #
      # Examples:
      #
      #   canvas.move_to(100, 50)
      def move_to(x, y)
        raise_unless_at_page_description_level_or_in_path
        invoke2(:m, x, y)
        @current_point[0] = @start_point[0] = x
        @current_point[1] = @start_point[1] = y
        self
      end

      # :call-seq:
      #   canvas.line_to(x, y)       => canvas
      #
      # Appends a straight line segment from the current point to the given point (which becomes the
      # new current point) to the current subpath.
      #
      # Examples:
      #
      #   canvas.line_to(100, 100)
      def line_to(x, y)
        raise_unless_in_path
        invoke2(:l, x, y)
        @current_point[0] = x
        @current_point[1] = y
        self
      end

      # :call-seq:
      #   canvas.curve_to(x, y, p1:, p2:)       => canvas
      #   canvas.curve_to(x, y, p1:)            => canvas
      #   canvas.curve_to(x, y, p2:)            => canvas
      #
      # Appends a cubic Bezier curve to the current subpath starting from the current point. The end
      # point becomes the new current point.
      #
      # A Bezier curve consists of the start point, the end point and the two control points +p1+
      # and +p2+. The start point is always the current point and the end point is specified as
      # +x+ and +y+ arguments.
      #
      # Additionally, either the first control point +p1+ or the second control +p2+ or both
      # control points have to be specified (as arrays containing two numbers). If the first
      # control point is not specified, the current point is used as first control point. If the
      # second control point is not specified, the end point is used as the second control point.
      #
      # Examples:
      #
      #   canvas.curve_to(100, 100, p1: [100, 50], p2: [50, 100])
      #   canvas.curve_to(100, 100, p1: [100, 50])
      #   canvas.curve_to(100, 100, p2: [50, 100])
      def curve_to(x, y, p1: nil, p2: nil)
        raise_unless_in_path
        if p1 && p2
          invoke(:c, *p1, *p2, x, y)
        elsif p1
          invoke(:y, *p1, x, y)
        elsif p2
          invoke(:v, *p2, x, y)
        else
          raise ArgumentError, "At least one control point must be specified for Bézier curves"
        end
        @current_point[0] = x
        @current_point[1] = y
        self
      end

      # :call-seq:
      #   canvas.rectangle(x, y, width, height, radius: 0)       => canvas
      #
      # Appends a rectangle to the current path as a complete subpath (drawn in counterclockwise
      # direction), with the bottom left corner specified by +x+ and +y+ and the given +width+ and
      # +height+.
      #
      # If +radius+ is greater than 0, the corners are rounded with the given radius.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # The current point is set to the bottom left corner if +radius+ is zero, otherwise it is set
      # to (x, y + radius).
      #
      # Examples:
      #
      #   canvas.rectangle(100, 100, 100, 50)
      #   canvas.rectangle(100, 100, 100, 50, radius: 10)
      def rectangle(x, y, width, height, radius: 0)
        raise_unless_at_page_description_level_or_in_path
        if radius == 0
          invoke(:re, x, y, width, height)
          @current_point[0] = @start_point[0] = x
          @current_point[1] = @start_point[1] = y
          self
        else
          polygon(x, y, x + width, y, x + width, y + height, x, y + height, radius: radius)
        end
      end

      # :call-seq:
      #   canvas.close_subpath      => canvas
      #
      # Closes the current subpath by appending a straight line from the current point to the
      # start point of the subpath which also becomes the new current point.
      def close_subpath
        raise_unless_in_path
        invoke0(:h)
        @current_point = @start_point
        self
      end

      # :call-seq:
      #   canvas.line(x0, y0, x1, y1)        => canvas
      #
      # Moves the current point to (x0, y0) and appends a line to (x1, y1) to the current path.
      #
      # This method is equal to "canvas.move_to(x0, y0).line_to(x1, y1)".
      #
      # Examples:
      #
      #   canvas.line(10, 10, 100, 100)
      def line(x0, y0, x1, y1)
        move_to(x0, y0)
        line_to(x1, y1)
      end

      # :call-seq:
      #   canvas.polyline(x0, y0, x1, y1, x2, y2, ...)          => canvas
      #
      # Moves the current point to (x0, y0) and appends line segments between all given
      # consecutive points, i.e. between (x0, y0) and (x1, y1), between (x1, y1) and (x2, y2) and
      # so on. The last point becomes the new current point.
      #
      # Examples:
      #
      #   canvas.polyline(0, 0, 100, 0, 100, 100, 0, 100, 0, 0)
      def polyline(*points)
        check_poly_points(points)
        move_to(points[0], points[1])
        i = 2
        while i < points.length
          line_to(points[i], points[i + 1])
          i += 2
        end
        self
      end

      # :call-seq:
      #   canvas.polygon(x0, y0, x1, y1, x2, y2, ..., radius: 0)          => canvas
      #
      # Appends a polygon consisting of the given points to the path as a complete subpath. The
      # point (x0, y0 + radius) becomes the new current point.
      #
      # If +radius+ is greater than 0, the corners are rounded with the given radius.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # Examples:
      #
      #   canvas.polygon(0, 0, 100, 0, 100, 100, 0, 100)
      #   canvas.polygon(0, 0, 100, 0, 100, 100, 0, 100, radius: 10)
      def polygon(*points, radius: 0)
        if radius == 0
          polyline(*points)
        else
          check_poly_points(points)
          move_to(*point_on_line(points[0], points[1], points[2], points[3], distance: radius))
          points.concat(points[0, 4])
          0.step(points.length - 6, 2) {|i| line_with_rounded_corner(*points[i, 6], radius) }
        end
        close_subpath
      end

      # :call-seq:
      #   canvas.circle(cx, cy, radius)      => canvas
      #
      # Appends a circle with center (cx, cy) and the given radius (in degrees) to the path as a
      # complete subpath (drawn in counterclockwise direction). The point (center_x + radius,
      # center_y) becomes the new current point.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # Examples:
      #
      #   canvas.circle(100, 100, 10)
      #
      # See: #arc (for approximation accuracy)
      def circle(cx, cy, radius)
        arc(cx, cy, a: radius)
        close_subpath
      end

      # :call-seq:
      #   canvas.ellipse(cx, cy, a:, b:, inclination: 0)      => canvas
      #
      # Appends an ellipse with center (cx, cy), semi-major axis +a+, semi-minor axis +b+ and an
      # inclination from the x-axis of +inclination+ degrees to the path as a complete subpath. The
      # outer-most point on the semi-major axis becomes the new current point.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # Examples:
      #
      #   # Ellipse aligned to x-axis and y-axis
      #   canvas.ellipse(100, 100, a: 10, b: 5)
      #
      #   # Inclined ellipse
      #   canvas.ellipse(100, 100, a: 10, b: 5, inclination: 45)
      #
      # See: #arc (for approximation accuracy)
      def ellipse(cx, cy, a:, b:, inclination: 0)
        arc(cx, cy, a: a, b: b, inclination: inclination)
        close_subpath
      end

      # :call-seq:
      #   canvas.arc(cx, cy, a:, b: a, start_angle: 0, end_angle: 360, clockwise: false, inclination: 0)   => canvas
      #
      # Appends an elliptical arc to the path. The endpoint of the arc becomes the new current
      # point.
      #
      # +cx+::
      #   x-coordinate of the center point of the arc
      #
      # +cy+::
      #   y-coordinate of the center point of the arc
      #
      # +a+::
      #   Length of semi-major axis
      #
      # +b+::
      #   Length of semi-minor axis (default: +a+)
      #
      # +start_angle+::
      #   Angle in degrees at which to start the arc (default: 0)
      #
      # +end_angle+::
      #   Angle in degrees at which to end the arc (default: 360)
      #
      # +clockwise+::
      #   If +true+ the arc is drawn in clockwise direction, otherwise in counterclockwise
      #   direction.
      #
      # +inclination+::
      #   Angle in degrees between the x-axis and the semi-major axis (default: 0)
      #
      # If +a+ and +b+ are equal, a circular arc is drawn. If the difference of the start angle
      # and end angle is equal to 360, a full ellipse (or circle) is drawn.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # Since PDF doesn't have operators for drawing elliptical or circular arcs, they have to be
      # approximated using Bezier curves (see #curve_to). The accuracy of the approximation can be
      # controlled using the configuration option 'graphic_object.arc.max_curves'.
      #
      # Examples:
      #
      #   canvas.arc(0, 0, a: 10)                         # Circle at (0, 0) with radius 10
      #   canvas.arc(0, 0, a: 10, b: 5)                   # Ellipse at (0, 0) with radii 10 and 5
      #   canvas.arc(0, 0, a: 10, b: 5, inclination: 45)  # The above ellipse inclined 45 degrees
      #
      #   # Circular and elliptical arcs from 45 degrees to 135 degrees
      #   canvas.arc(0, 0, a: 10, start_angle: 45, end_angle: 135)
      #   canvas.arc(0, 0, a: 10, b: 5, start_angle: 45, end_angle: 135)
      #
      #   # Arcs from 135 degrees to 15 degrees, the first in counterclockwise direction (i.e. the
      #   # big arc), the other in clockwise direction (i.e. the small arc)
      #   canvas.arc(0, 0, a: 10, start_angle: 135, end_angle: 15)
      #   canvas.arc(0, 0, a: 10, start_angle: 135, end_angle: 15, clockwise: true)
      #
      # See: Content::GraphicObject::Arc
      def arc(cx, cy, a:, b: a, start_angle: 0, end_angle: 360, clockwise: false, inclination: 0)
        arc = GraphicObject::Arc.configure(cx: cx, cy: cy, a: a, b: b,
                                           start_angle: start_angle, end_angle: end_angle,
                                           clockwise: clockwise, inclination: inclination)
        arc.draw(self)
        self
      end

      # :call-seq:
      #   canvas.graphic_object(obj, **options)      => obj
      #   canvas.graphic_object(name, **options)     => graphic_object
      #
      # Returns the named graphic object, configured with the given options.
      #
      # If an object responding to :configure is given, it is used. Otherwise the graphic object
      # is looked up via the given name in the configuration option 'graphic_object.map'. Then the
      # graphic object is configured with the given options if at least one is given.
      #
      # Examples:
      #
      #   obj = canvas.graphic_object(:arc, cx: 10, cy: 10)
      #   canvas.draw(obj)
      def graphic_object(obj, **options)
        unless obj.respond_to?(:configure)
          obj = context.document.config.constantize('graphic_object.map', obj)
        end
        obj = obj.configure(**options) unless options.empty? && obj.respond_to?(:draw)
        obj
      end

      # :call-seq:
      #   canvas.draw(obj, **options)      => canvas
      #   canvas.draw(name, **options)     => canvas
      #
      # Draws the given graphic object on the canvas.
      #
      # See #graphic_object for information on the arguments.
      #
      # Examples:
      #
      #   canvas.draw(:arc, cx: 10, cy: 10)
      def draw(name, **options)
        graphic_object(name, **options).draw(self)
        self
      end

      # :call-seq:
      #   canvas.stroke    => canvas
      #
      # Strokes the path.
      #
      # See: PDF1.7 s8.5.3.1, s8.5.3.2
      def stroke
        raise_unless_in_path_or_clipping_path
        invoke0(:S)
        self
      end

      # :call-seq:
      #   canvas.close_stroke    => canvas
      #
      # Closes the last subpath and then strokes the path.
      #
      # See: PDF1.7 s8.5.3.1, s8.5.3.2
      def close_stroke
        raise_unless_in_path_or_clipping_path
        invoke0(:s)
        self
      end

      # :call-seq:
      #   canvas.fill(rule = :nonzero)    => canvas
      #
      # Fills the path using the given rule.
      #
      # The argument +rule+ may either be +:nonzero+ to use the nonzero winding number rule or
      # +:even_odd+ to use the even-odd rule for determining which regions to fill in.
      #
      # Any open subpaths are implicitly closed before being filled.
      #
      # See: PDF1.7 s8.5.3.1, s8.5.3.3
      def fill(rule = :nonzero)
        raise_unless_in_path_or_clipping_path
        invoke0(rule == :nonzero ? :f : :'f*')
        self
      end

      # :call-seq:
      #   canvas.fill_stroke(rule = :nonzero)    => canvas
      #
      # Fills and then strokes the path using the given rule.
      #
      # The argument +rule+ may either be +:nonzero+ to use the nonzero winding number rule or
      # +:even_odd+ to use the even-odd rule for determining which regions to fill in.
      #
      # See: PDF1.7 s8.5.3
      def fill_stroke(rule = :nonzero)
        raise_unless_in_path_or_clipping_path
        invoke0(rule == :nonzero ? :B : :'B*')
        self
      end

      # :call-seq:
      #   canvas.close_fill_stroke(rule = :nonzero)    => canvas
      #
      # Closes the last subpath and then fills and strokes the path using the given rule.
      #
      # The argument +rule+ may either be +:nonzero+ to use the nonzero winding number rule or
      # +:even_odd+ to use the even-odd rule for determining which regions to fill in.
      #
      # See: PDF1.7 s8.5.3
      def close_fill_stroke(rule = :nonzero)
        raise_unless_in_path_or_clipping_path
        invoke0(rule == :nonzero ? :b : :'b*')
        self
      end

      # :call-seq:
      #   canvas.end_path     => canvas
      #
      # Ends the path without stroking or filling it.
      #
      # This method is normally used in conjunction with the clipping path methods to define the
      # clipping.
      #
      # See: PDF1.7 s8.5.3.1 #clip
      def end_path
        raise_unless_in_path_or_clipping_path
        invoke0(:n)
        self
      end

      # :call-seq:
      #   canvas.clip_path(rule = :nonzero)     => canvas
      #
      # Modifies the clipping path by intersecting it with the current path.
      #
      # The argument +rule+ may either be +:nonzero+ to use the nonzero winding number rule or
      # +:even_odd+ to use the even-odd rule for determining which regions lie inside the clipping
      # path.
      #
      # Note that the current path cannot be modified after invoking this method! This means that
      # one of the path painting methods or #end_path must be called immediately afterwards.
      #
      # See: PDF1.7 s8.5.4
      def clip_path(rule = :nonzero)
        raise_unless_in_path
        invoke0(rule == :nonzero ? :W : :'W*')
        self
      end

      # :call-seq:
      #   canvas.xobject(filename, at:, width: nil, height: nil)       => xobject
      #   canvas.xobject(io, at:, width: nil, height: nil)             => xobject
      #   canvas.xobject(image_object, at:, width: nil, height: nil)   => image_object
      #   canvas.xobject(form_object, at:, width: nil, height: nil)    => form_object
      #
      # Draws the given XObject (either an image XObject or a form XObject) at the specified
      # position and returns the XObject.
      #
      # Any image format for which a HexaPDF::ImageLoader object is available and registered with
      # the configuration option 'image_loader' can be used. PNG and JPEG images are supported out
      # of the box.
      #
      # If the filename or the IO specifies a PDF file, the first page of this file is used to
      # create a form XObject which is then drawn.
      #
      # The +at+ argument has to be an array containing two numbers specifying the bottom left
      # corner at which to draw the XObject.
      #
      # If +width+ and +height+ are specified, the drawn XObject will have exactly these
      # dimensions. If only one of them is specified, the other dimension is automatically
      # calculated so that the aspect ratio is retained. If neither is specified, the width and
      # height of the XObject are used (for images, 1 pixel being represented by 1 PDF point, i.e.
      # 72 DPI).
      #
      # *Note*: If a form XObject is drawn, all currently set graphics state parameters influence
      # the rendering of the form XObject. This means, for example, that when the line width is
      # set to 20, all lines of the form XObject are drawn with that line width unless the line
      # width is changed in the form XObject itself.
      #
      # Examples:
      #
      #   canvas.xobject('test.png', at: [100, 100])
      #   canvas.xobject('test.pdf', at: [100, 100])
      #
      #   File.new('test.jpg', 'rb') do |io|
      #     canvas.xobject(io, at: [100, 200], width: 300)
      #   end
      #
      #   image = document.object(5)    # Object with oid=5 is an image XObject in this example
      #   canvas.xobject(image, at: [100, 200], width: 200, height: 300)
      #
      # See: PDF1.7 s8.8, s.8.10.1
      def xobject(obj, at:, width: nil, height: nil)
        unless obj.kind_of?(HexaPDF::Stream)
          obj = context.document.images.add(obj)
        end
        return obj if obj.width == 0 || obj.height == 0

        width, height = calculate_dimensions(obj.width, obj.height,
                                             rwidth: width, rheight: height)
        if obj[:Subtype] != :Image
          width /= obj.box.width.to_f
          height /= obj.box.height.to_f
          at[0] -= obj.box.left
          at[1] -= obj.box.bottom
        end

        transform(width, 0, 0, height, at[0], at[1]) do
          invoke1(:Do, resources.add_xobject(obj))
        end

        obj
      end
      alias image xobject

      # :call-seq:
      #   canvas.character_spacing                       => current_character_spacing
      #   canvas.character_spacing(amount)               => canvas
      #   canvas.character_spacing(amount) { block }     => canvas
      #
      # The character spacing determines how much additional space is added between two
      # consecutive characters. For horizontal writing positive values increase the distance
      # between two characters, whereas for vertical writing negative values increase the
      # distance.
      #
      # Returns the current character spacing value (see Content::GraphicsState#character_spacing)
      # when no argument is given. Otherwise sets the character spacing using the +amount+ argument
      # and returns self. The setter version can also be called in the character_spacing= form.
      #
      # If the +amount+ and a block are provided, the changed character spacing is only active
      # during the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.character_spacing(0.25)
      #   canvas.character_spacing                      # => 0.25
      #   canvas.character_spacing = 0.5                # => 0.5
      #
      #   canvas.character_spacing(0.10) do
      #     canvas.character_spacing                    # => 0.10
      #   end
      #   canvas.character_spacing                      # => 0.5
      #
      # See: PDF1.7 s9.3.2
      def character_spacing(amount = nil, &bk)
        gs_getter_setter(:character_spacing, :Tc, amount, &bk)
      end
      alias character_spacing= character_spacing

      # :call-seq:
      #   canvas.word_spacing                       => current_word_spacing
      #   canvas.word_spacing(amount)               => canvas
      #   canvas.word_spacing(amount) { block }     => canvas
      #
      # If the font's PDF encoding supports this, the word spacing determines how much additional
      # space is added when the ASCII space character is encountered in a text. For horizontal
      # writing positive values increase the distance between two words, whereas for vertical
      # writing negative values increase the distance.
      #
      # Note that in HexaPDF only the standard 14 PDF Type1 fonts support this property! When using
      # any other font, for example a TrueType font, this property has no effect.
      #
      # Returns the current word spacing value (see Content::GraphicsState#word_spacing) when no
      # argument is given. Otherwise sets the word spacing using the +amount+ argument and returns
      # self. The setter version can also be called in the word_spacing= form.
      #
      # If the +amount+ and a block are provided, the changed word spacing is only active during
      # the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.word_spacing(0.25)
      #   canvas.word_spacing                      # => 0.25
      #   canvas.word_spacing = 0.5                # => 0.5
      #
      #   canvas.word_spacing(0.10) do
      #     canvas.word_spacing                    # => 0.10
      #   end
      #   canvas.word_spacing                      # => 0.5
      #
      # See: PDF1.7 s9.3.3
      def word_spacing(amount = nil, &bk)
        gs_getter_setter(:word_spacing, :Tw, amount, &bk)
      end
      alias word_spacing= word_spacing

      # :call-seq:
      #   canvas.horizontal_scaling                        => current_horizontal_scaling
      #   canvas.horizontal_scaling(percent)               => canvas
      #   canvas.horizontal_scaling(percent) { block }     => canvas
      #
      # The horizontal scaling adjusts the width of text character glyphs by stretching or
      # compressing them in the horizontal direction. The value is specified as percent of the
      # normal width.
      #
      # Returns the current horizontal scaling value (see Content::GraphicsState#horizontal_scaling)
      # when no argument is given. Otherwise sets the horizontal scaling using the +percent+
      # argument and returns self. The setter version can also be called in the horizontal_scaling=
      # form.
      #
      # If the +percent+ and a block are provided, the changed horizontal scaling is only active
      # during the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.horizontal_scaling(50)                  # each glyph has only 50% width
      #   canvas.horizontal_scaling                      # => 50
      #   canvas.horizontal_scaling = 125                # => 125
      #
      #   canvas.horizontal_scaling(75) do
      #     canvas.horizontal_scaling                    # => 75
      #   end
      #   canvas.horizontal_scaling                      # => 125
      #
      # See: PDF1.7 s9.3.4
      def horizontal_scaling(amount = nil, &bk)
        gs_getter_setter(:horizontal_scaling, :Tz, amount, &bk)
      end
      alias horizontal_scaling= horizontal_scaling

      # :call-seq:
      #   canvas.leading                       => current_leading
      #   canvas.leading(amount)               => canvas
      #   canvas.leading(amount) { block }     => canvas
      #
      # The leading specifies the vertical distance between the baselines of adjacent text lines.
      #
      # Returns the current leading value (see Content::GraphicsState#leading) when no argument is
      # given. Otherwise sets the leading using the +amount+ argument and returns self. The setter
      # version can also be called in the leading= form.
      #
      # If the +amount+ and a block are provided, the changed leading is only active during the
      # block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.leading(14.5)
      #   canvas.leading                      # => 14.5
      #   canvas.leading = 10                 # => 10
      #
      #   canvas.leading(25) do
      #     canvas.leading                    # => 25
      #   end
      #   canvas.leading                      # => 10
      #
      # See: PDF1.7 s9.3.5
      def leading(amount = nil, &bk)
        gs_getter_setter(:leading, :TL, amount, &bk)
      end
      alias leading= leading

      # :call-seq:
      #   canvas.text_rendering_mode                     => current_text_rendering_mode
      #   canvas.text_rendering_mode(mode)               => canvas
      #   canvas.text_rendering_mode(mode) { block }     => canvas
      #
      # The text rendering mode determines if and how glyphs are rendered. The +mode+ parameter
      # can either be a valid integer or one of the symbols +:fill+, +:stroke+, +:fill_stroke+,
      # +:invisible+, +:fill_clip+, +:stroke_clip+, +:fill_stroke_clip+ or +:clip+ (see
      # TextRenderingMode.normalize for details). Note that the return value is always a
      # normalized text rendering mode value.
      #
      # Returns the current text rendering mode value (see
      # Content::GraphicsState#text_rendering_mode) when no argument is given. Otherwise sets the
      # text rendering mode using the +mode+ argument and returns self. The setter version can also
      # be called in the text_rendering_mode= form.
      #
      # If the +mode+ and a block are provided, the changed text rendering mode is only active
      # during the block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.text_rendering_mode(:fill)
      #   canvas.text_rendering_mode               # => #<NamedValue @name=:fill, @value = 0>
      #   canvas.text_rendering_mode = :stroke     # => #<NamedValue @name=:stroke, @value = 1>
      #
      #   canvas.text_rendering_mode(3) do
      #     canvas.text_rendering_mode             # => #<NamedValue @name=:invisible, @value = 3>
      #   end
      #   canvas.text_rendering_mode               # => #<NamedValue @name=:stroke, @value = 1>
      #
      # See: PDF1.7 s9.3.6
      def text_rendering_mode(m = nil, &bk)
        gs_getter_setter(:text_rendering_mode, :Tr, m && TextRenderingMode.normalize(m), &bk)
      end
      alias text_rendering_mode= text_rendering_mode

      # :call-seq:
      #   canvas.text_rise                       => current_text_rise
      #   canvas.text_rise(amount)               => canvas
      #   canvas.text_rise(amount) { block }     => canvas
      #
      # The text rise specifies the vertical distance to move the baseline up or down from its
      # default location. Positive values move the baseline up, negative values down.
      #
      # Returns the current text rise value (see Content::GraphicsState#text_rise) when no argument
      # is given. Otherwise sets the text rise using the +amount+ argument and returns self. The
      # setter version can also be called in the text_rise= form.
      #
      # If the +amount+ and a block are provided, the changed text rise is only active during the
      # block by saving and restoring the graphics state.
      #
      # Examples:
      #
      #   canvas.text_rise(5)
      #   canvas.text_rise                      # => 5
      #   canvas.text_rise = 10                 # => 10
      #
      #   canvas.text_rise(15) do
      #     canvas.text_rise                    # => 15
      #   end
      #   canvas.text_rise                      # => 10
      #
      # See: PDF1.7 s9.3.7
      def text_rise(amount = nil, &bk)
        gs_getter_setter(:text_rise, :Ts, amount, &bk)
      end
      alias text_rise= text_rise

      # :call-seq:
      #   canvas.begin_text(force_new: false)      -> canvas
      #
      # Begins a new text object.
      #
      # If +force+ is +true+ and the current graphics object is already a text object, it is ended
      # and a new text object is begun.
      #
      # See: PDF1.7 s9.4.1
      def begin_text(force_new: false)
        raise_unless_at_page_description_level_or_in_text
        end_text if force_new
        invoke0(:BT) if graphics_object == :none
        self
      end

      # :call-seq:
      #   canvas.end_text       -> canvas
      #
      # Ends the current text object.
      #
      # See: PDF1.7 s9.4.1
      def end_text
        raise_unless_at_page_description_level_or_in_text
        invoke0(:ET) if graphics_object == :text
        self
      end

      # :call-seq:
      #   canvas.text_matrix(a, b, c, d, e, f)     => canvas
      #
      # Sets the text matrix (and the text line matrix) to the given matrix and returns self.
      #
      # The given values are interpreted as a matrix in the following way:
      #
      #   a b 0
      #   c d 0
      #   e f 1
      #
      # Examples:
      #
      #   canvas.begin_text
      #   canvas.text_matrix(1, 0, 0, 1, 100, 100)
      #
      # See: PDF1.7 s9.4.2
      def text_matrix(a, b, c, d, e, f)
        begin_text
        invoke(:Tm, a, b, c, d, e, f)
        self
      end

      # :call-seq:
      #   canvas.move_text_cursor(offset: nil, absolute: true)     -> canvas
      #
      # Moves the text cursor by modifying the text and text line matrices.
      #
      # If +offset+ is not specified, the text cursor is moved to the start of the next text line
      # using #leading as vertical offset.
      #
      # Otherwise, the arguments +offset+, which has to be an array of the form [x, y], and
      # +absolute+ work together:
      #
      # * If +absolute+ is +true+, then the text and text line matrices are set to [1, 0, 0, 1, x,
      #   y], placing the origin of text space, and therefore the text cursor, at [x, y].
      #
      #   Note that +absolute+ has to be understood in terms of the text matrix since for the actual
      #   rendering the current transformation matrix is multiplied with the text matrix.
      #
      # * If +absolute+ is +false+, then the text cursor is moved to the start of the next line,
      #   offset from the start of the current line (the origin of the text line matrix) by
      #   +offset+.
      #
      # See: #show_glyphs
      def move_text_cursor(offset: nil, absolute: true)
        begin_text
        if offset
          if absolute
            text_matrix(1, 0, 0, 1, offset[0], offset[1])
          else
            invoke2(:Td, offset[0], offset[1])
          end
        else
          invoke0(:"T*")
        end
        self
      end

      # :call-seq:
      #   canvas.text_cursor     -> [x, y]
      #
      # Returns the position of the text cursor, i.e. the origin of the current text matrix.
      #
      # Note that this method can only be called while the current graphic object is a text object
      # since the text matrix is otherwise undefined.
      def text_cursor
        raise_unless_in_text
        graphics_state.tm.evaluate(0, 0)
      end

      # :call-seq:
      #   canvas.font                              => current_font
      #   canvas.font(name, size: nil, **options)  => canvas
      #
      # Specifies the font that should be used when showing text.
      #
      # A valid font size need to be provided on the first invocation, otherwise an error is raised.
      #
      # *Note* that this method returns the font object itself, not the PDF dictionary representing
      # the font!
      #
      # If +size+ is specified, the #font_size method is invoked with it as argument. All other
      # options are passed on to the font loaders (see HexaPDF::FontLoader) that are used for
      # loading the specified font.
      #
      # Returns the current font object when no argument is given.
      #
      # Examples:
      #
      #   canvas.font("Times", variant: :bold, size: 12)
      #   canvas.font                                          # => font object
      #   canvas.font = "Times"
      #
      # See: PDF1.7 s9.2.2
      def font(name = nil, size: nil, **options)
        if name
          @font = (name.respond_to?(:pdf_object) ? name : context.document.fonts.add(name, **options))
          if size
            font_size(size)
          else
            size = font_size
            raise HexaPDF::Error, "No valid font size set" if size <= 0
            invoke_font_operator(@font.pdf_object, size)
          end
          self
        else
          @font
        end
      end
      alias font= font

      # :call-seq:
      #   canvas.font_size            => font_size
      #   canvas.font_size(size       => canvas
      #
      # Specifies the font size.
      #
      # Note that an error is raised if no font has been set before!
      #
      # Returns the current font size when no argument is given.
      #
      # Examples:
      #
      #   canvas.font_size(12)
      #   canvas.font_size                       # => 12
      #   canvas.font_size = 12
      #
      # See: PDF1.7 s9.2.2
      def font_size(size = nil)
        if size
          unless @font
            raise HexaPDF::Error, "A font needs to be set before the font size can be set"
          end
          invoke_font_operator(@font.pdf_object, size)
          self
        else
          graphics_state.font_size
        end
      end
      alias font_size= font_size

      # :call-seq:
      #   canvas.text(text)                  -> canvas
      #   canvas.text(text, at: [x, y])      -> canvas
      #
      # Shows the given text string.
      #
      # If no position is provided, the text is positioned at the current position of the text
      # cursor (the origin in case of a new text object or otherwise after the last shown text).
      #
      # The text string may contain any valid Unicode newline separator and if so, multiple lines
      # are shown, using #leading for offsetting the lines.
      #
      # Note that there are no provisions to make sure that all text is visible! So if the text
      # string is too long, it will just flow off the page and be cut off.
      #
      # Examples:
      #
      #   canvas.font('Times', size: 12)
      #   canvas.text("This is a \n multiline text", at: [100, 100])
      #
      # See: http://www.unicode.org/reports/tr18/#Line_Boundaries
      def text(text, at: nil)
        raise_unless_font_set
        move_text_cursor(offset: at) if at
        lines = text.split(/\u{D A}|(?!\u{D A})[\u{A}-\u{D}\u{85}\u{2028}\u{2029}]/, -1)
        lines.each_with_index do |str, index|
          show_glyphs(@font.decode_utf8(str))
          move_text_cursor unless index == lines.length - 1
        end
        self
      end

      # :call-seq:
      #   canvas.show_glyphs(glyphs)      -> canvas
      #
      # Low-level method for actually showing text on the canvas.
      #
      # The argument +glyphs+ needs to be a an array of glyph objects valid for the current font,
      # optionally interspersed with numbers for kerning.
      #
      # Text is always shown at the current position of the text cursor, i.e. the origin of the text
      # matrix. To move the text cursor to somewhere else use #move_text_cursor before calling this
      # method.
      #
      # The text matrix is updated to correctly represent the graphics state after the invocation.
      #
      # This method is usually not invoked directly but by higher level methods like #text.
      def show_glyphs(glyphs)
        return if glyphs.empty?
        raise_unless_font_set
        begin_text

        result = [''.b]
        offset = 0
        glyphs.each do |item|
          if item.kind_of?(Numeric)
            result << item << ''.b
            offset -= item * graphics_state.scaled_font_size
          else
            encoded = @font.encode(item)
            result[-1] << encoded

            offset += item.width * graphics_state.scaled_font_size +
              graphics_state.scaled_character_spacing
            offset += graphics_state.scaled_word_spacing if encoded == " "
          end
        end

        invoke1(:TJ, result)
        graphics_state.tm.translate(offset, 0)
        self
      end

      # :call-seq:
      #   canvas.show_glyphs_only(glyphs)      -> canvas
      #
      # Same operation as with #show_glyphs but without updating the text matrix.
      #
      # This method should only be used by advanced text layouting algorithms which perform the
      # necessary calculations themselves!
      #
      # *Warning*: Since this method doesn't update the text matrix, all following results from
      # #text_cursor and other methods using the current text matrix are invalid until the next call
      # to #text_matrix or #end_text.
      def show_glyphs_only(glyphs)
        return if glyphs.empty?
        raise_unless_font_set
        begin_text

        simple = true
        result = [last = ''.b]
        glyphs.each do |item|
          if item.kind_of?(Numeric)
            simple = false
            result << item << (last = ''.b)
          else
            last << @font.encode(item)
          end
        end

        simple ? serialize1(:Tj, result[0]) : serialize1(:TJ, result)
        self
      end

      # :call-seq:
      #   canvas.marked_content_point(tag, property_list: nil)     -> canvas
      #
      # Inserts a marked-content point, optionally associated with a property list.
      #
      # A marked-content point is used to identify a position in the content stream for later use by
      # other applications. The symbol +tag+ is used to uniquely identify the role of the
      # marked-content point and should be registered with ISO to avoid conflicts.
      #
      # The optional +property_list+ argument can either be a valid PDF dictionary or a symbol
      # referencing an already used property list in the resource dictionary's /Properties
      # dictionary.
      #
      # Examples:
      #
      #   canvas.marked_content_point(:Divider)
      #   canvas.marked_content_point(:Divider, property_list: {Key: 'value'})
      #
      # See: PDF1.7 s14.6
      def marked_content_point(tag, property_list: nil)
        raise_unless_at_page_description_level_or_in_text
        if property_list
          property_list = resources.property_list(property_list) if property_list.kind_of?(Symbol)
          invoke2(:DP, tag, resources.add_property_list(property_list))
        else
          invoke1(:MP, tag)
        end
        self
      end

      # :call-seq:
      #   canvas.marked_content_sequence(tag, property_list: nil)               -> canvas
      #   canvas.marked_content_sequence(tag, property_list: nil) { block }     -> canvas
      #
      # Inserts a marked-content sequence, optionally associated with a property list.
      #
      # A marked-content sequence is used to identify a sequence of complete graphics objects in the
      # content stream for later use by other applications. The symbol +tag+ is used to uniquely
      # identify the role of the marked-content sequence and should be registered with ISO to avoid
      # conflicts.
      #
      # The optional +property_list+ argument can either be a valid PDF dictionary or a symbol
      # referencing an already used property list in the resource dictionary's /Properties
      # dictionary.
      #
      # If invoked without a block, a corresponding call to #end_marked_content_sequence must be
      # done. Otherwise the marked-content sequence automatically ends when the block is finished.
      #
      # Although the PDF specification would allow using marked-content sequences inside text
      # objects, this is prohibited.
      #
      # Examples:
      #
      #   canvas.marked_content_sequence(:Divider)
      #   # Other instructions
      #   canvas.end_marked_content_sequence
      #
      #   canvas.marked_content_sequence(:Divider, property_list: {Key: 'value'}) do
      #     # Other instructions
      #   end
      #
      # See: PDF1.7 s14.6, #end_marked_content_sequence
      def marked_content_sequence(tag, property_list: nil)
        raise_unless_at_page_description_level
        if property_list
          property_list = resources.property_list(property_list) if property_list.kind_of?(Symbol)
          invoke2(:BDC, tag, resources.add_property_list(property_list))
        else
          invoke1(:BMC, tag)
        end
        if block_given?
          yield
          end_marked_content_sequence
        end
        self
      end

      # :call-seq:
      #   canvas.end_marked_content_sequence       -> canvas
      #
      # Ends a marked-content sequence.
      #
      # See #marked_content_sequence for details.
      #
      # See: PDF1.7 s14.6, #marked_content_sequence
      def end_marked_content_sequence
        raise_unless_at_page_description_level
        invoke0(:EMC)
        self
      end

      # Creates a color object from the given color specification. See #stroke_color for details
      # on the possible color specifications.
      def color_from_specification(spec)
        if spec.length == 1 && spec[0].kind_of?(String)
          ColorSpace.device_color_from_specification(spec)
        elsif spec.length == 1 && spec[0].respond_to?(:color_space)
          spec[0]
        else
          resources.color_space(ColorSpace.for_components(spec)).color(*spec)
        end
      end

      private

      # Invokes the given operator with the operands and serializes it.
      def invoke(operator, *operands)
        @operators[operator].invoke(self, *operands)
        serialize(operator, *operands)
      end

      # Serializes the operator with the operands to the content stream.
      def serialize(operator, *operands)
        @contents << @operators[operator].serialize(@serializer, *operands)
      end

      # Optimized method for zero operands.
      def invoke0(operator)
        @operators[operator].invoke(self)
        @contents << @operators[operator].serialize(@serializer)
      end

      # Optimized method for one operand.
      def invoke1(operator, op1)
        @operators[operator].invoke(self, op1)
        @contents << @operators[operator].serialize(@serializer, op1)
      end

      # Optimized method for one operand.
      def serialize1(operator, op1)
        @contents << @operators[operator].serialize(@serializer, op1)
      end

      # Optimized method for two operands.
      def invoke2(operator, op1, op2)
        @operators[operator].invoke(self, op1, op2)
        @contents << @operators[operator].serialize(@serializer, op1, op2)
      end

      # Invokes the font operator using the given PDF font dictionary.
      def invoke_font_operator(font, font_size)
        unless graphics_state.font == font && graphics_state.font_size == font_size
          invoke(:Tf, resources.add_font(font), font_size)
        end
      end

      # Raises an error unless the current graphics object is a path.
      def raise_unless_in_path
        unless graphics_object == :path
          raise HexaPDF::Error, "Operation only allowed if current graphics object is a path"
        end
      end

      # Raises an error unless the current graphics object is a path or a clipping path.
      def raise_unless_in_path_or_clipping_path
        unless graphics_object == :path || graphics_object == :clipping_path
          raise HexaPDF::Error, "Operation only allowed if current graphics object is a " \
            "path or clipping path"
        end
      end

      # Raises an error unless the current graphics object is none, i.e. the page description
      # level.
      def raise_unless_at_page_description_level
        end_text if graphics_object == :text
        unless graphics_object == :none
          raise HexaPDF::Error, "Operation only allowed if there is no current graphics object"
        end
      end

      # Raises an error unless the current graphics object is none or a text object.
      def raise_unless_at_page_description_level_or_in_text
        unless graphics_object == :none || graphics_object == :text
          raise HexaPDF::Error, "Operation only allowed if current graphics object is a " \
            "text object or if there is no current object"
        end
      end

      # Raises an error unless the current graphics object is none or a path object.
      def raise_unless_at_page_description_level_or_in_path
        end_text if graphics_object == :text
        unless graphics_object == :none || graphics_object == :path
          raise HexaPDF::Error, "Operation only allowed if current graphics object is a " \
            "path object or if there is no current object"
        end
      end

      # Raises an error unless the current graphics object is a text object.
      def raise_unless_in_text
        unless graphics_object == :text
          raise HexaPDF::Error, "Operation only allowed if current graphics object is a " \
            "text object"
        end
      end

      # Raises an error unless a font has been set.
      def raise_unless_font_set
        unless @font
          raise HexaPDF::Error, "Operation only allowed if a font is set"
        end
      end

      # Utility method that abstracts the implementation of the stroke and fill color methods.
      def color_getter_setter(name, color, rg, g, k, cs, scn)
        color.flatten!
        if !color.empty?
          raise_unless_at_page_description_level_or_in_text
          color = color_from_specification(color)

          save_graphics_state if block_given?
          unless color == graphics_state.send(name)
            case color.color_space.family
            when :DeviceRGB then serialize(rg, *color.components)
            when :DeviceGray then serialize(g, *color.components)
            when :DeviceCMYK then serialize(k, *color.components)
            else
              if color.color_space != graphics_state.send(name).color_space
                serialize(cs, resources.add_color_space(color.color_space))
              end
              serialize(scn, *color.components)
            end
            graphics_state.send(:"#{name}=", color)
          end

          if block_given?
            yield
            restore_graphics_state
          end

          self
        elsif block_given?
          raise ArgumentError, "Block only allowed with arguments"
        else
          graphics_state.send(name)
        end
      end

      # Utility method that abstracts the implementation of a graphics state parameter
      # getter/setter method with a call sequence of:
      #
      #   canvas.method                        # => cur_value
      #   canvas.method(new_value)             # => canvas
      #   canvas.method(new_value) { block }   # => canvas
      #
      # +name+::
      #   The name (Symbol) of the graphics state parameter for fetching the value from the
      #   GraphicState.
      #
      # +op+::
      #   The operator (Symbol) which should be invoked if the value is different from the current
      #   value of the graphics state parameter.
      #
      # +value+::
      #   The new value of the graphics state parameter,  or +nil+ if the getter functionality is
      #   needed.
      def gs_getter_setter(name, op, value)
        if !value.nil?
          raise_unless_at_page_description_level_or_in_text
          save_graphics_state if block_given?
          if graphics_state.send(name) != value
            value.respond_to?(:to_operands) ? invoke(op, *value.to_operands) : invoke1(op, value)
          end
          if block_given?
            yield
            restore_graphics_state
          end
          self
        elsif block_given?
          raise ArgumentError, "Block only allowed with an argument"
        else
          graphics_state.send(name)
        end
      end

      # Modifies and checks the array +points+ so that polylines and polygons work correctly.
      def check_poly_points(points)
        if points.length < 4
          raise ArgumentError, "At least two points needed to make one line segment"
        elsif points.length.odd?
          raise ArgumentError, "Missing y-coordinate for last point"
        end
      end

      # Used for calculating the optimal distance of the control points.
      #
      # See: http://itc.ktu.lt/itc354/Riskus354.pdf, p373 right column
      KAPPA = 0.55191496 #:nodoc:

      # Appends a line with a rounded corner from the current point. The corner is specified by
      # the three points (x0, y0), (x1, y1) and (x2, y2) where (x1, y1) is the corner point.
      def line_with_rounded_corner(x0, y0, x1, y1, x2, y2, radius)
        p0 = point_on_line(x1, y1, x0, y0, distance: radius)
        p3 = point_on_line(x1, y1, x2, y2, distance: radius)
        p1 = point_on_line(p0[0], p0[1], x1, y1, distance: KAPPA * radius)
        p2 = point_on_line(p3[0], p3[1], x1, y1, distance: KAPPA * radius)
        line_to(p0[0], p0[1])
        curve_to(p3[0], p3[1], p1: p1, p2: p2)
      end

    end

  end
end
