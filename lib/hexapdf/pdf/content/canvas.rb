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
        #   canvas.save_graphics_state
        #   canvas.save_graphics_state { block }
        #
        # Saves the current graphics state.
        #
        # If invoked without a block a corresponding call to #restore_graphics_state must be done.
        # Otherwise the graphics state is automatically restored when the block is finished.
        #
        # Examples:
        #
        #   # With a block
        #   canvas.save_graphics_state do
        #     canvas.set_line_width(10)
        #     canvas.line(100, 100, 200, 200)
        #   end
        #
        #   # Same without a block
        #   canvas.save_graphics_state
        #   canvas.set_line_width(10)
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
        end

        # Restores the current graphics state.
        #
        # Must not be invoked more times than #save_graphics_state.
        #
        # See: PDF1.7 s8.4.2, #save_graphics_state
        def restore_graphics_state
          invoke(:Q)
        end

        # :call-seq:
        #   canvas.transform(a, b, c, d, e, f)
        #   canvas.transform(a, b, c, d, e, f) { block }
        #
        # Transforms the user space by applying the given matrix to the current transformation
        # matrix.
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
        end

        # :call-seq:
        #   canvas.rotate(angle, origin: nil)
        #   canvas.rotate(angle, origin: nil) { block }
        #
        # Rotates the user space +angle+ degrees around the coordinate system origin or around the
        # given point.
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
        #   canvas.scale(sx, sy = sx, origin: nil)
        #   canvas.scale(sx, sy = sx, origin: nil) { block }
        #
        # Scales the user space +sx+ units in the horizontal and +sy+ units in the vertical
        # direction. If the optional +origin+ is specified, scaling is done from that point.
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
        #   canvas.translate(x, y)
        #   canvas.translate(x, y) { block }
        #
        # Translates the user space coordinate system origin to the given +x+ and +y+ coordinates.
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
        #   canvas.skew(a, b, origin: nil)
        #   canvas.skew(a, b, origin: nil) { block }
        #
        # Skews the the x-axis by +a+ degrees and the y-axis by +b+ degress. If the optional
        # +origin+ is specified, skewing is done from that point.
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
        #   canvas.line_width(width)             => width
        #   canvas.line_width(width) { block }   => width
        #
        # The line width determines the thickness of a stroked path.
        #
        # Returns the current line width (see GraphicsState#line_width) when no argument is given.
        # Otherwise sets the line width to the given +width+ and returns it. The setter version can
        # also be called in the line_width= form.
        #
        # If the +width+ and a block are provided, the changed line width is only active during the
        # block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.line_width(10)      # => 10
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
        #   canvas.line_cap_style(style)             => style
        #   canvas.line_cap_style(style) { block }   => style
        #
        # The line cap style specifies how the ends of stroked open paths should look like. The
        # +style+ parameter can either be a valid integer or one of the symbols :butt, :round or
        # :projecting_square (see LineCapStyle.normalize for details). Note that the return value is
        # always a normalized (i.e. Integer) line cap style.
        #
        # Returns the current line cap style (see GraphicsState#line_cap_style) when no argument is
        # given. Otherwise sets the line cap style to the given +style+ and returns it. The setter
        # version can also be called in the line_cap_style= form.
        #
        # If the +style+ and a block are provided, the changed line cap style is only active during
        # the block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.line_cap_style(:butt)        # => 0
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
        #   canvas.line_join_style(style)             => style
        #   canvas.line_join_style(style) { block }   => style
        #
        # The line join style specifies the shape that is used at the corners of stroked paths. The
        # +style+ parameter can either be a valid integer or one of the symbols :miter, :round or
        # :bevel (see LineJoinStyle.normalize for details). Note that the return value is always a
        # normalized (i.e. Integer) line join style.
        #
        # Returns the current line join style (see GraphicsState#line_join_style) when no argument
        # is given. Otherwise sets the line join style to the given +style+ and returns it. The
        # setter version can also be called in the line_join_style= form.
        #
        # If the +style+ and a block are provided, the changed line join style is only active during
        # the block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.line_join_style(:miter)       # => 0
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
        #   canvas.miter_limit(limit)             => limit
        #   canvas.miter_limit(limit) { block }   => limit
        #
        # The miter limit specifies the maximum ratio of the miter length to the line width for
        # mitered line joins (see #line_join_style). When the limit is exceeded, a bevel join is
        # used instead of a miter join.
        #
        # Returns the current miter limit (see GraphicsState#miter_limit) when no argument is given.
        # Otherwise sets the miter limit to the given +limit+ and returns it. The setter version can
        # also be called in the miter_limit= form.
        #
        # If the +limit+ and a block are provided, the changed miter limit is only active during the
        # block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.miter_limit(10)      # => 10
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
        #   canvas.line_dash_pattern(line_dash_pattern)               => line_dash_pattern
        #   canvas.line_dash_pattern(length, phase = 0)               => line_dash_pattern
        #   canvas.line_dash_pattern(array, phase = 0)                => line_dash_pattern
        #   canvas.line_dash_pattern(value, phase = 0) { block }      => line_dash_pattern
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
        # returns it. The setter version can also be called in the line_dash_pattern= form (but only
        # without the second argument!).
        #
        # If arguments and a block are provided, the changed line dash pattern is only active during
        # the block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.line_dash_pattern(10)            # => LineDashPattern.new([10], 0)
        #   canvas.line_dash_pattern                # => LineDashPattern.new([10], 0)
        #   canvas.line_dash_pattern(10, 2)         # => LineDashPattern.new([10], 2)
        #   canvas.line_dash_pattern([5, 3, 1], 2)  # => LineDashPattern.new([5, 3, 1], 2)
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
        #   canvas.rendering_intent(intent)               => rendering_intent
        #   canvas.rendering_intent(intent) { block }     => rendering_intent
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
        # is given. Otherwise sets the rendering intent using the +intent+ argument and returns it.
        # The setter version can also be called in the rendering_intent= form.
        #
        # If the +intent+ and a block are provided, the changed rendering intent is only active
        # during the block by saving and restoring the graphics state.
        #
        # Examples:
        #
        #   canvas.rendering_intent(:Perceptual)         # => :Perceptual
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

        # Utility method that abstracts the implementation of a graphics state parameter
        # getter/setter method with a call sequence of:
        #
        #   canvas.method                        # => cur_value
        #   canvas.method(new_value)             # => new_value
        #   canvas.method(new_value) { block }   # => new_value
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
          elsif block_given?
            raise HexaPDF::Error, "Block only allowed with an argument"
          end
          graphics_state.send(name)
        end

      end

    end
  end
end
