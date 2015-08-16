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
      # stroking color but take this information from the graphics state.
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
        # See: #restore_graphics_state
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
        # See: #save_graphics_state
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
        # If invoked with a block, the transformation is only active during the block.
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
        # If invoked with a block, the rotation of the user space is only active during the block.
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
        # If invoked with a block, the scaling is only active during the block.
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
        # If invoked with a block, the translation of the user space is only active during the
        # block.
        #
        # Examples:
        #
        #   canvas.translate(100, 100) do        # Origin is now at (100, 100)
        #     canvas.line(0, 0, 100, 0)          # Actually from (100, 100) to (200, 100)
        #   end
        #   canvas.line(0, 0, 100, 0)            # Again from (0, 0) to (100, 0)
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
        # If invoked with a block, the skewing is only active during the block.
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
        def skew(a, b, origin: nil, &block)
          tan_a = Math.tan(deg_to_rad(a))
          tan_b = Math.sin(deg_to_rad(b))

          # As with rotation, skewing is performed around the coordinate system origin but points
          # are translated so that the skewed skewing origin coincides with the unskewed one.
          tx = (origin ? -origin[1] * tan_b : 0)
          ty = (origin ? -origin[0] * tan_a : 0)
          transform(1, tan_a, tan_b, 1, tx, ty, &block)
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

      end

    end
  end
end
