# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/content/graphics_state'
require 'hexapdf/pdf/content/operator'
require 'hexapdf/pdf/serializer'
require 'hexapdf/pdf/utils/math_helpers'

module HexaPDF
  module PDF
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
      # methods for drawing other standard paths like circles.
      #
      # When a subpath is started, the current graphics object is changed to path object. After all
      # path constructions are finished, a path painting methods needs to be invoked to change back
      # to the page description level. Optionally, the path painting method may be preceeded by a
      # clipping path method to change the current clipping path (see TODO).
      #
      # There are three kinds of path painting methods: Those that stroke the path, those that fill
      # the path and those that stroke and fill the path. In addition filling may be done using
      # either the nonzero winding number rule or the even-odd rule.
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

        include Utils::MathHelpers

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
          @serializer = HexaPDF::PDF::Serializer.new
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
        # always a normalized (i.e. Integer) line cap style.
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
        #   canvas.line_cap_style               # => 0
        #   canvas.line_cap_style = :round      # => 1
        #
        #   canvas.line_cap_style(:butt) do
        #     canvas.line_cap_style             # => 0
        #   end
        #   canvas.line_cap_style               # => 1
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
        # normalized (i.e. Integer) line join style.
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
        #   canvas.line_join_style               # => 0
        #   canvas.line_join_style = :round      # => 1
        #
        #   canvas.line_join_style(:bevel) do
        #     canvas.line_join_style             # => 2
        #   end
        #   canvas.line_join_style               # => 1
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
        #   color = HexaPDF::PDF::Content::ColorSpace::DeviceRGB.color(255, 255, 0)
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
          point.flatten!
          if p1 && p2
            invoke(:c, *p1, *p2, *point)
          elsif p1
            invoke(:y, *p1, *point)
          elsif p2
            invoke(:v, *p2, *point)
          else
            raise HexaPDF::Error, "At least one control point must be specified for Bézier curves"
          end
          self
        end

        # :call-seq:
        #   canvas.rectangle(x, y, width, height)       => canvas
        #   canvas.rectangle([x, y], width, height)     => canvas
        #
        # Appends a rectangle to the current path as a complete subpath, with the upper-left corner
        # specified by +x+ and +y+ and the given +width+ and +height+.
        #
        # If there is no current path when the method is invoked, a new path is automatically begun.
        # The current point after invoking this method will be the upper-left corner.
        #
        # Examples:
        #
        #   canvas.rectangle(100, 100, 100, 50)
        #   canvas.rectangle([100, 100], 100, 50)
        def rectangle(*point, width, height)
          point.flatten!
          invoke(:re, *point, width, -height)
          self
        end

        # :call-seq:
        #   canvas.close_subpath      => canvas
        #
        # Closes the current subpath by appending a straight line from the current point to the
        # start point of the subpath.
        def close_subpath
          invoke(:h)
          self
        end

        private

        def init_contents(strategy)
          case strategy
          when :replace
            context.contents = @contents = ''.force_encoding(Encoding::BINARY)
          else
            raise HexaPDF::Error, "Unknown content handling strategy"
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

        # Utility method that abstracts the implementation of the stroke and fill color methods.
        def color_getter_setter(name, color, rg, g, k, cs, scn)
          color.flatten!
          if color.length > 0
            color = color_from_specification(color)
            color_changed = (color != graphics_state.send(name))
            color_space_changed = (color.color_space != graphics_state.send(name).color_space)

            save_graphics_state if block_given? && color_changed
            graphics_state.send(:"#{name}=", color)

            if color_changed
              case color.color_space.family
              when :DeviceRGB then serialize(rg, *color.components)
              when :DeviceGray then serialize(g, *color.components)
              when :DeviceCMYK then serialize(k, *color.components)
              else
                serialize(cs, resources.add_color_space(color.color_space)) if color_space_changed
                serialize(scn, *color.components)
              end
            end

            yield if block_given?
            restore_graphics_state if block_given? && color_changed
            self
          elsif block_given?
            raise HexaPDF::Error, "Block only allowed with arguments"
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
            raise HexaPDF::Error, "Invalid number of color components"
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
            value_changed = (graphics_state.send(name) != value)
            save_graphics_state if block_given? && value_changed
            if value_changed
              value.respond_to?(:to_operands) ? invoke(op, *value.to_operands) : invoke(op, value)
            end
            yield if block_given?
            restore_graphics_state if block_given? && value_changed
            self
          elsif block_given?
            raise HexaPDF::Error, "Block only allowed with an argument"
          else
            graphics_state.send(name)
          end
        end

      end

    end
  end
end
