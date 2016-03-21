# -*- encoding: utf-8 -*-

require 'hexapdf/content/graphics_state'
require 'hexapdf/content/operator'
require 'hexapdf/serializer'
require 'hexapdf/utils/math_helpers'
require 'hexapdf/content/graphic_object'

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
    # Some operators modify the so called graphics state (see GraphicsState). The graphics state
    # is a collection of settings that is used during processing or creating a content stream. For
    # example, the path painting operators don't have operands to specify the line width or the
    # stroke color but take this information from the graphics state.
    #
    # One important thing about the graphics state is that it is only possible to restore a prior
    # state using the save and restore methods. It is not possible to reset the graphics state
    # while creating the content stream!
    #
    # === Paths
    #
    # A PDF path object consists of one or more subpaths. Each subpath can be a rectangle or can
    # consist of lines and cubic bézier curves. No other types of subpaths are known to PDF.
    # However, the Canvas class contains additional methods that use the basic path construction
    # methods for drawing other paths like circles.
    #
    # When a subpath is started, the current graphics object is changed to 'path object'. After all
    # path constructions are finished, a path painting method needs to be invoked to change back to
    # the page description level. Optionally, the path painting method may be preceeded by a
    # clipping path method to change the current clipping path (see #clip_path).
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
    # = Special Graphics State Methods
    #
    # These methods are only allowed when the current graphics object is the page description
    # level.
    #
    # * #save_graphics_state
    # * #restore_graphics_state
    # * #transform, #rotate, #scale, #translate, #skew
    #
    # See: PDF1.7 s8, s9
    class Canvas

      include HexaPDF::Utils::MathHelpers

      # The context for which the canvas was created (a Type::Page or Type::Form object).
      attr_reader :context

      # The GraphicsState object containing the current graphics state.
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

      # The operator name/implementation map used when invoking or serializing an operator.
      attr_reader :operators

      # Create a new Canvas object for the given context object (either a Page or a Form).
      #
      # content::
      #   Specifies if the new contents should be appended (:append, default), prepended
      #   (:prepend) or if the new contents should replace the old one (:replace).
      def initialize(context, content: :append)
        @context = context
        @operators = Operator::DEFAULT_OPERATORS.dup
        @graphics_state = GraphicsState.new
        @graphics_object = :none
        @serializer = HexaPDF::Serializer.new
        init_contents(content)
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
        invoke(:q)
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
        invoke(:Q)
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
      # Returns the current line width (see GraphicsState#line_width) when no argument is given.
      # Otherwise sets the line width to the given +width+ and returns self. The setter version
      # can also be called in the line_width= form.
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
      alias :line_width= :line_width

      # :call-seq:
      #   canvas.line_cap_style                    => current_line_cap_style
      #   canvas.line_cap_style(style)             => canvas
      #   canvas.line_cap_style(style) { block }   => canvas
      #
      # The line cap style specifies how the ends of stroked open paths should look like. The
      # +style+ parameter can either be a valid integer or one of the symbols :butt, :round or
      # :projecting_square (see LineCapStyle.normalize for details). Note that the return value is
      # always a normalized line cap style.
      #
      # Returns the current line cap style (see GraphicsState#line_cap_style) when no argument is
      # given. Otherwise sets the line cap style to the given +style+ and returns self. The setter
      # version can also be called in the line_cap_style= form.
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
      alias :line_cap_style= :line_cap_style

      # :call-seq:
      #   canvas.line_join_style                    => current_line_join_style
      #   canvas.line_join_style(style)             => canvas
      #   canvas.line_join_style(style) { block }   => canvas
      #
      # The line join style specifies the shape that is used at the corners of stroked paths. The
      # +style+ parameter can either be a valid integer or one of the symbols :miter, :round or
      # :bevel (see LineJoinStyle.normalize for details). Note that the return value is always a
      # normalized line join style.
      #
      # Returns the current line join style (see GraphicsState#line_join_style) when no argument
      # is given. Otherwise sets the line join style to the given +style+ and returns self. The
      # setter version can also be called in the line_join_style= form.
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
      alias :line_join_style= :line_join_style

      # :call-seq:
      #   canvas.miter_limit                    => current_miter_limit
      #   canvas.miter_limit(limit)             => canvas
      #   canvas.miter_limit(limit) { block }   => canvas
      #
      # The miter limit specifies the maximum ratio of the miter length to the line width for
      # mitered line joins (see #line_join_style). When the limit is exceeded, a bevel join is
      # used instead of a miter join.
      #
      # Returns the current miter limit (see GraphicsState#miter_limit) when no argument is given.
      # Otherwise sets the miter limit to the given +limit+ and returns self. The setter version
      # can also be called in the miter_limit= form.
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
      alias :miter_limit= :miter_limit

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
      # * By providing a LineDashPattern object
      # * By providing a single Integer/Float that is used for both dashes and gaps
      # * By providing an array of Integers/Floats that specify the alternating dashes and gaps
      #
      # The phase (i.e. the distance into the dashes/gaps at which to start) can additionally be
      # set in the last two cases.
      #
      # A solid line can be achieved by using 0 for the length or by using an empty array.
      #
      # Returns the current line dash pattern (see GraphicsState#line_dash_pattern) when no
      # argument is given. Otherwise sets the line dash pattern using the given arguments and
      # returns self. The setter version can also be called in the line_dash_pattern= form (but
      # only without the second argument!).
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
        case value
        when nil, LineDashPattern
        when Array
          value = LineDashPattern.new(value, phase)
        when 0
          value = LineDashPattern.new([], 0)
        else
          value = LineDashPattern.new([value], phase)
        end
        gs_getter_setter(:line_dash_pattern, :d, value, &block)
      end
      alias :line_dash_pattern= :line_dash_pattern

      # :call-seq:
      #   canvas.rendering_intent                       => current_rendering_intent
      #   canvas.rendering_intent(intent)               => canvas
      #   canvas.rendering_intent(intent) { block }     => canvas
      #
      # The rendering intent is used to specify the intent on how colors should be rendered since
      # sometimes compromises have to be made when the capabilities of an output device are not
      # sufficient. The +intent+ parameter can be one of the following symbols:
      #
      # * :AbsoluteColorimetric
      # * :RelativeColorimetric
      # * :Saturation
      # * :Perceptual
      #
      # Returns the current rendering intent (see GraphicsState#rendering_intent) when no argument
      # is given. Otherwise sets the rendering intent using the +intent+ argument and returns
      # self. The setter version can also be called in the rendering_intent= form.
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
      alias :rendering_intent= :rendering_intent

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
      # * A single numeric argument specifies a gray color (see ColorSpace::DeviceGray::Color).
      # * Three numeric arguments specify an RGB color (see ColorSpace::DeviceRGB::Color).
      # * A string in the format "RRGGBB" where "RR" is the hexadecimal number for the red, "GG"
      #   for the green and "BB" for the blue color value also specifies an RGB color.
      # * Four numeric arguments specify a CMYK color (see ColorSpace::DeviceCMYK::Color).
      # * A color object is used directly (normally used for color spaces other than DeviceRGB,
      #   DeviceCMYK and DeviceGray).
      # * An array is treated as if its items were specified separately as arguments.
      #
      # Returns the current stroke color (see GraphicsState#stroke_color) when no argument is
      # given. Otherwise sets the stroke color using the given arguments and returns self. The
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
      alias :stroke_color= :stroke_color

      # The fill color defines the color used for non-stroking operations, i.e. for filling paths.
      #
      # Works exactly the same #stroke_color but for the fill color. See #stroke_color for
      # details on invocation and use.
      def fill_color(*color, &block)
        color_getter_setter(:fill_color, color, :rg, :g, :k, :cs, :scn, &block)
      end
      alias :fill_color= :fill_color

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
      # Returns the current fill alpha (see GraphicsState#fill_alpha) and stroke alpha
      # (GraphicsState#stroke_alpha) values using a hash with the keys :fill_alpha and
      # :stroke_alpha when no argument is given. Otherwise sets the fill and stroke alpha values
      # and returns self. The setter version can also be called in the opacity= form.
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
            invoke(:gs, resources.add_ext_gstate(dict))
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
      #   canvas.move_to([x, y])     => canvas
      #
      # Begins a new subpath (and possibly a new path) by moving the current point to the given
      # point.
      #
      # The point can either be specified as +x+ and +y+ arguments or as an array containing two
      # numbers.
      #
      # Examples:
      #
      #   canvas.move_to(100, 50)
      #   canvas.move_to([100, 50]
      def move_to(*point)
        raise_unless_at_page_description_level_or_in_path
        point.flatten!
        invoke(:m, *point)
        self
      end

      # :call-seq:
      #   canvas.line_to(x, y)       => canvas
      #   canvas.line_to([x, y])     => canvas
      #
      # Appends a straight line segment from the current point to the given point to the current
      # subpath.
      #
      # The point can either be specified as +x+ and +y+ arguments or as an array containing two
      # numbers.
      #
      # Examples:
      #
      #   canvas.line_to(100, 100)
      #   canvas.line_to([100, 100])
      def line_to(*point)
        raise_unless_in_path
        point.flatten!
        invoke(:l, *point)
        self
      end

      # :call-seq:
      #   canvas.curve_to(x, y, p1:, p2:)       => canvas
      #   canvas.curve_to([x, y], p1:, p2:)     => canvas
      #   canvas.curve_to(x, y, p1:)            => canvas
      #   canvas.curve_to([x, y], p1:)          => canvas
      #   canvas.curve_to(x, y, p2:)            => canvas
      #   canvas.curve_to([x, y], p2:)          => canvas
      #
      # Appends a cubic Bezier curve to the current subpath starting from the current point.
      #
      # A Bezier curve consists of the start point, the end point and the two control points +p1+
      # and +p2+. The start point is always the current point and the end point is specified as
      # +x+ and +y+ arguments or as an array containing two numbers.
      #
      # Additionally, either the first control point +p1+ or the second control +p2+ or both
      # control points have to be specified (as arrays containing two numbers). If the first
      # control point is not specified, the current point is used as first control point. If the
      # second control point is not specified, the end point is used as the second control point.
      #
      # Examples:
      #
      #   canvas.curve_to(100, 100, p1: [100, 50], p2: [50, 100])
      #   canvas.curve_to([100, 100], p1: [100, 50])
      #   canvas.curve_to(100, 100, p2: [50, 100])
      def curve_to(*point, p1: nil, p2: nil)
        raise_unless_in_path
        point.flatten!
        if p1 && p2
          invoke(:c, *p1, *p2, *point)
        elsif p1
          invoke(:y, *p1, *point)
        elsif p2
          invoke(:v, *p2, *point)
        else
          raise ArgumentError, "At least one control point must be specified for Bézier curves"
        end
        self
      end

      # :call-seq:
      #   canvas.rectangle(x, y, width, height, radius: 0)       => canvas
      #   canvas.rectangle([x, y], width, height, radius: 0)     => canvas
      #
      # Appends a rectangle to the current path as a complete subpath (drawn in counterclockwise
      # direction), with the lower-left corner specified by +x+ and +y+ and the given +width+ and
      # +height+.
      #
      # If +radius+ is greater than 0, the corners are rounded with the given radius.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # Examples:
      #
      #   canvas.rectangle(100, 100, 100, 50)
      #   canvas.rectangle([100, 100], 100, 50)
      #
      #   canvas.rectangle([100, 100], 100, 50, radius: 10)
      def rectangle(*point, width, height, radius: 0)
        raise_unless_at_page_description_level_or_in_path
        point.flatten!
        if radius == 0
          invoke(:re, *point, width, height)
          self
        else
          x, y = point
          polygon(x, y, x + width, y, x + width, y + height, x, y + height, radius: radius)
        end
      end

      # :call-seq:
      #   canvas.close_subpath      => canvas
      #
      # Closes the current subpath by appending a straight line from the current point to the
      # start point of the subpath.
      def close_subpath
        raise_unless_in_path
        invoke(:h)
        self
      end

      # :call-seq:
      #   canvas.line(x0, y0, x1, y1)        => canvas
      #   canvas.line([x0, y0], [x1, y1])    => canvas
      #
      # Moves the current point to (x0, y0) and appends a line to (x1, y1) to the current path.
      #
      # The points can either be specified as +x+ and +y+ arguments or as arrays containing two
      # numbers.
      #
      # Examples:
      #
      #   canvas.line(10, 10, 100, 100)
      #   canvas.line([10, 10], [100, 100])
      def line(*points)
        points.flatten!
        move_to(points[0], points[1])
        line_to(points[2], points[3])
      end

      # :call-seq:
      #   canvas.polyline(x0, y0, x1, y1, x2, y2, ...)          => canvas
      #   canvas.polyline([x0, y0], [x1, y1], [x2, y2], ...)    => canvas
      #
      # Moves the current point to (x0, y0) and appends line segments between all given
      # consecutive points, i.e. between (x0, y0) and (x1, y1), between (x1, y1) and (x2, y2) and
      # so on.
      #
      # The points can either be specified as +x+ and +y+ arguments or as arrays containing two
      # numbers.
      #
      # Examples:
      #
      #   canvas.polyline(0, 0, 100, 0, 100, 100, 0, 100, 0, 0)
      #   canvas.polyline([0, 0], [100, 0], [100, 100], [0, 100], [0, 0])
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
      #   canvas.polygon([x0, y0], [x1, y1], [x2, y2], ..., radius: 0)    => canvas
      #
      # Appends a polygon consisting of the given points to the path as a complete subpath.
      #
      # If +radius+ is greater than 0, the corners are rounded with the given radius.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # The points can either be specified as +x+ and +y+ arguments or as arrays containing two
      # numbers.
      #
      # Examples:
      #
      #   canvas.polygon(0, 0, 100, 0, 100, 100, 0, 100)
      #   canvas.polygon([0, 0], [100, 0], [100, 100], [0, 100])
      #
      #   canvas.polygon(0, 0, 100, 0, 100, 100, 0, 100, radius: 10)
      def polygon(*points, radius: 0)
        if radius == 0
          polyline(*points)
        else
          check_poly_points(points)
          move_to(point_on_line(points[0], points[1], points[2], points[3], distance: radius))
          points.concat(points[0, 4])
          0.step(points.length - 6, 2) {|i| line_with_rounded_corner(*points[i, 6], radius)}
        end
        close_subpath
      end

      # :call-seq:
      #   canvas.circle(cx, cy, radius)      => canvas
      #   canvas.circle([cx, cy], radius)    => canvas
      #
      # Appends a circle with center (cx, cy) and the given +radius+ (in degrees) to the path as a
      # complete subpath (drawn in counterclockwise direction).
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # The center point can either be specified as +x+ and +y+ arguments or as an array
      # containing two numbers.
      #
      # After the circle has been appended, the current point is at (center_x + radius, center_y).
      #
      # Examples:
      #
      #   canvas.circle(100, 100, 10)
      #   canvas.circle([100, 100], 10)
      #
      # See: #arc (for approximation accuracy)
      def circle(*center, radius)
        arc(*center, a: radius)
        close_subpath
      end

      # :call-seq:
      #   canvas.ellipse(cx, cy, a:, b:, inclination: 0)      => canvas
      #   canvas.ellipse([cx, cy], a:, b:, inclination: 0)    => canvas
      #
      # Appends an ellipse with center (cx, cy), semi-major axis +a+, semi-minor axis +b+ and an
      # inclination from the x-axis of +inclination+ degrees to the path as a complete subpath.
      #
      # If there is no current path when the method is invoked, a new path is automatically begun.
      #
      # The center point can either be specified as +x+ and +y+ arguments or as an array
      # containing two numbers.
      #
      # After the ellipse has been appended, the current point is the outer-most point on the
      # semi-major axis.
      #
      # Examples:
      #
      #   # Ellipse aligned to x-axis and y-axis
      #   canvas.ellipse(100, 100, a: 10, b: 5)
      #   canvas.ellipse([100, 100], a: 10, b: 5)
      #
      #   # Inclined ellipse
      #   canvas.ellipse(100, 100, a: 10, b: 5, inclination: 45)
      #
      # See: #arc (for approximation accuracy)
      def ellipse(*center, a:, b:, inclination: 0)
        arc(*center, a: a, b: b, inclination: inclination)
        close_subpath
      end

      # :call-seq:
      #   canvas.arc(cx, cy, a:, b: a, start_angle: 0, end_angle: 360, sweep: true, inclination: 0)   => canvas
      #   canvas.arc([cx, cy], a:, b: a, start_angle: 0, end_angle: 360, sweep: true, inclination: 0) => canvas
      #
      # Appends an elliptical arc to the path.
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
      # +sweep+::
      #   If +true+ the arc is drawn in a positive-angle direction, otherwise in a negative-angle
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
      # The center point can either be specified as +x+ and +y+ arguments or as an array
      # containing two numbers.
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
      #   # Arcs from 135 degrees to 15 degrees, the first in positive direction (i.e. to 15 + 360
      #   # degrees, the big arc), the other in negative direction (the small arc)
      #   canvas.arc(0, 0, a: 10, start_angle: 135, end_angle: 15)
      #   canvas.arc(0, 0, a: 10, start_angle: 135, end_angle: 15, sweep: false)
      #
      # See: GraphicObject::Arc
      def arc(*center, a:, b: a, start_angle: 0, end_angle: 360, sweep: true, inclination: 0)
        center.flatten!
        arc = GraphicObject::Arc.configure(cx: center[0], cy: center[1], a: a, b: b,
          start_angle: start_angle, end_angle: end_angle, sweep: sweep, theta: inclination)
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
        obj = obj.configure(options) if options.size > 0 || !obj.respond_to?(:draw)
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
        invoke(:S)
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
        invoke(:s)
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
        invoke(rule == :nonzero ? :f : :'f*')
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
        invoke(rule == :nonzero ? :B : :'B*')
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
        invoke(rule == :nonzero ? :b : :'b*')
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
        invoke(:n)
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
        invoke(rule == :nonzero ? :W : :'W*')
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
      # Any image format for which an ImageLoader object is available and registered with the
      # configuration option 'image_loader' can be used. PNG and JPEG images are supported out of
      # the box.
      #
      # If the filename or the IO specifies a PDF file, the first page of this file is used to
      # create a form XObject which is then drawn.
      #
      # The +at+ argument has to be an array containing two numbers specifying the lower-left
      # corner at which to draw the XObject.
      #
      # If +width+ and +height+ are specified, the drawn XObject will have exactly these
      # dimensions. If only one of them is specified, the other dimension is automatically
      # calculated so that the aspect ratio is retained. If neither is specified, the width and
      # height of the XObject are used (for images, 1 pixel being represented by 1 PDF point, i.e.
      # 72 DPI).
      #
      # Note: If a form XObject is drawn, all currently set graphics state parameters influence
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
      #   canvas.xobject(image, at: [100, 200], width: 200, heigth: 300)
      #
      # See: PDF1.7 s8.8, s.8.10.1
      def xobject(obj, at:, width: nil, height: nil)
        unless obj.kind_of?(HexaPDF::Stream)
          obj = context.document.utils.add_image(obj)
        end

        if obj[:Subtype] == :Image
          width, height = calculate_dimensions(obj[:Width], obj[:Height],
                                               rwidth: width, rheight: height)
        else
          width, height = calculate_dimensions(obj.box.width, obj.box.height,
                                               rwidth: width, rheight: height)
          width /= obj.box.width.to_f
          height /= obj.box.height.to_f
          at[0] -= obj.box.left
          at[1] -= obj.box.bottom
        end

        transform(width, 0, 0, height, at[0], at[1]) do
          invoke(:Do, resources.add_xobject(obj))
        end

        obj
      end
      alias :image :xobject

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
      # Returns the current character spacing value (see GraphicsState#character_spacing) when no
      # argument is given. Otherwise sets the character spacing using the +amount+ argument and
      # returns self. The setter version can also be called in the character_spacing= form.
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
      alias :character_spacing= :character_spacing

      # :call-seq:
      #   canvas.word_spacing                       => current_word_spacing
      #   canvas.word_spacing(amount)               => canvas
      #   canvas.word_spacing(amount) { block }     => canvas
      #
      # The word spacing determines how much additional space is added when the ASCII space
      # character is encountered in a text. For horizontal writing positive values increase the
      # distance between two words, whereas for vertical writing negative values increase the
      # distance.
      #
      # Returns the current word spacing value (see GraphicsState#word_spacing) when no argument
      # is given. Otherwise sets the word spacing using the +amount+ argument and returns self.
      # The setter version can also be called in the word_spacing= form.
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
      alias :word_spacing= :word_spacing

      # :call-seq:
      #   canvas.horizontal_scaling                        => current_horizontal_scaling
      #   canvas.horizontal_scaling(percent)               => canvas
      #   canvas.horizontal_scaling(percent) { block }     => canvas
      #
      # The horizontal scaling adjusts the width of text character glyphs by stretching or
      # compressing them in the horizontal direction. The value is specified as percent of the
      # normal width.
      #
      # Returns the current horizontal scaling value (see GraphicsState#horizontal_scaling) when
      # no argument is given. Otherwise sets the horizontal scaling using the +percent+ argument
      # and returns self. The setter version can also be called in the horizontal_scaling= form.
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
      alias :horizontal_scaling= :horizontal_scaling

      # :call-seq:
      #   canvas.leading                       => current_leading
      #   canvas.leading(amount)               => canvas
      #   canvas.leading(amount) { block }     => canvas
      #
      # The leading specifies the vertical distance between the baselines of adjacent text lines.
      #
      # Returns the current leading value (see GraphicsState#leading) when no argument is given.
      # Otherwise sets the leading using the +amount+ argument and returns self. The setter
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
      alias :leading= :leading

      # :call-seq:
      #   canvas.text_rendering_mode                     => current_text_rendering_mode
      #   canvas.text_rendering_mode(mode)               => canvas
      #   canvas.text_rendering_mode(mode) { block }     => canvas
      #
      # The text rendering mode determines if and how glyphs are rendered. The +mode+ parameter
      # can either be a valid integer or one of the symbols :fill, :stroke, :fill_stroke,
      # :invisible, :fill_clip, :stroke_clip, :fill_stroke_clip or :clip (see
      # TextRenderingMode.normalize for details). Note that the return value is always a
      # normalized text rendering mode value.
      #
      # Returns the current text rendering mode value (see GraphicsState#text_rendering_mode) when
      # no argument is given. Otherwise sets the text rendering mode using the +mode+ argument and
      # returns self. The setter version can also be called in the text_rendering_mode= form.
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
      alias :text_rendering_mode= :text_rendering_mode

      # :call-seq:
      #   canvas.text_rise                       => current_text_rise
      #   canvas.text_rise(amount)               => canvas
      #   canvas.text_rise(amount) { block }     => canvas
      #
      # The text rise specifies the vertical distance to move the baseline up or down from its
      # default location. Positive values move the baseline up, negative values down.
      #
      # Returns the current text rise value (see GraphicsState#text_rise) when no argument is
      # given. Otherwise sets the text rise using the +amount+ argument and returns self. The
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
      alias :text_rise= :text_rise

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
        invoke(:BT) if graphics_object == :none
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
        invoke(:ET) if graphics_object == :text
        self
      end

      private

      def init_contents(strategy)
        case strategy
        when :replace
          context.contents = @contents = ''.force_encoding(Encoding::BINARY)
        else
          raise ArgumentError, "Unknown content handling strategy: #{strategy}"
        end
      end

      # Invokes the given operator with the operands and serializes it.
      def invoke(operator, *operands)
        @operators[operator].invoke(self, *operands)
        serialize(operator, *operands)
      end

      # Serializes the operator with the operands to the content stream.
      def serialize(operator, *operands)
        @contents << @operators[operator].serialize(@serializer, *operands)
      end

      # Raises an error unless the current graphics object is a path.
      def raise_unless_in_path
        if graphics_object != :path
          raise HexaPDF::Error, "Operation only allowed when current graphics object is a path"
        end
      end

      # Raises an error unless the current graphics object is a path or a clipping path.
      def raise_unless_in_path_or_clipping_path
        if graphics_object != :path && graphics_object != :clipping_path
          raise HexaPDF::Error, "Operation only allowed when current graphics object is a " \
            "path or clipping path"
        end
      end

      # Raises an error unless the current graphics object is none, i.e. the page description
      # level.
      def raise_unless_at_page_description_level
        end_text if graphics_object == :text
        if graphics_object != :none
          raise HexaPDF::Error, "Operation only allowed when current graphics object is a " \
            "path or clipping path"
        end
      end

      # Raises an error unless the current graphics object is none or a text object.
      def raise_unless_at_page_description_level_or_in_text
        if graphics_object != :none && graphics_object != :text
          raise HexaPDF::Error, "Operation only allowed when current graphics object is a " \
            "text object or if there is no current object"
        end
      end

      # Raises an error unless the current graphics object is none or a path object.
      def raise_unless_at_page_description_level_or_in_path
        end_text if graphics_object == :text
        if graphics_object != :none && graphics_object != :path
          raise HexaPDF::Error, "Operation only allowed when current graphics object is a" \
            "path object or if there is no current object"
        end
      end

      # Utility method that abstracts the implementation of the stroke and fill color methods.
      def color_getter_setter(name, color, rg, g, k, cs, scn)
        color.flatten!
        if color.length > 0
          raise_unless_at_page_description_level_or_in_text
          color = color_from_specification(color)

          save_graphics_state if block_given?
          if color != graphics_state.send(name)
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

      # Creates a color object from the given color specification. See #stroke_color for details
      # on the possible color specifications.
      def color_from_specification(spec)
        if spec.length == 1 && spec[0].kind_of?(String)
          resources.color_space(:DeviceRGB).color(*spec[0].scan(/../).map!(&:hex))
        elsif spec.length == 1 && spec[0].respond_to?(:color_space)
          spec[0]
        else
          resources.color_space(color_space_for_components(spec)).color(*spec)
        end
      end

      # Returns the name of the device color space that should be used for creating a color object
      # from the components array.
      def color_space_for_components(components)
        case components.length
        when 1 then :DeviceGray
        when 3 then :DeviceRGB
        when 4 then :DeviceCMYK
        else
          raise ArgumentError, "Invalid number of color components, 1|3|4 expected, " \
            "#{components.length} given"
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
            value.respond_to?(:to_operands) ? invoke(op, *value.to_operands) : invoke(op, value)
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
        points.flatten!
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
        line_to(p0)
        curve_to(p3, p1: p1, p2: p2)
      end

      # Given two points p0 = (x0, y0) and p1 = (x1, y1), returns the point on the line through
      # these points that is +distance+ units away from p0.
      #
      #   v = p1 - p0
      #   result = p0 + distance * v/norm(v)
      def point_on_line(x0, y0, x1, y1, distance:)
        norm = Math.sqrt((x1 - x0)**2 + (y1 - y0)**2)
        [x0 + distance / norm * (x1 - x0), y0 + distance / norm * (y1 - y0)]
      end

      # Calculates and returns the requested dimensions for the rectangular object with the given
      # +width+ and +height+ based on the options.
      #
      # +rwidth+::
      #     The requested width. If +rheight+ is not specified, it is chosen so that the aspect
      #     ratio is maintained
      #
      # +rheight+::
      #     The requested height. If +rwidth+ is not specified, it is chosen so that the aspect
      #     ratio is maintained
      def calculate_dimensions(width, height, rwidth: nil, rheight: nil)
        if rwidth && rheight
          [rwidth, rheight]
        elsif rwidth
          [rwidth, height * rwidth / width.to_f]
        elsif rheight
          [width * rheight / height.to_f, rheight]
        else
          [width, height]
        end
      end

    end

  end
end
