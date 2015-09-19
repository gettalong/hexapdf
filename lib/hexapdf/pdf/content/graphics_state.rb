# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/configuration'
require 'hexapdf/pdf/content/color_space'
require 'hexapdf/pdf/content/text_state'
require 'hexapdf/pdf/content/transformation_matrix'

module HexaPDF
  module PDF
    module Content

      # Associates a name with a value, used by various graphics state parameters.
      class NamedValue

        # The value itself.
        attr_reader :value

        # The name for the value.
        attr_reader :name

        # Creates a new NamedValue object and freezes it.
        def initialize(name, value)
          @name = name
          @value = value
          freeze
        end

        # The object is equal to +other+ if either the name or the value is equal to +other+, or if
        # the other object is a NamedValue object with the same name and value.
        def ==(other)
          @name == other || @value == other ||
            (other.kind_of?(NamedValue) && @name == other.name && @value == other.value)
        end

        # Returns the value.
        def to_operands
          @value
        end

      end


      # Defines all available line cap styles as constants. Each line cap style is an instance of
      # NamedValue. For use with GraphicsState#line_cap_style.
      #
      # See: PDF1.7 s8.4.3.3
      module LineCapStyle

        # Returns the argument normalized to a valid line cap style.
        #
        # * 0 or :butt can be used for the BUTT_CAP style.
        # * 1 or :round can be used for the ROUND_CAP style.
        # * 2 or :projecting_square can be used for the PROJECTING_SQUARE_CAP style.
        # * Otherwise an error is raised.
        def self.normalize(style)
          case style
          when :butt, 0 then BUTT_CAP
          when :round, 1 then ROUND_CAP
          when :projecting_square, 2 then PROJECTING_SQUARE_CAP
          else
            raise HexaPDF::Error, "Unknown line cap style: #{style}"
          end
        end

        # Stroke is squared off at the endpoint of a path.
        BUTT_CAP = NamedValue.new(:butt, 0)

        # A semicircular arc is drawn at the endpoint of a path.
        ROUND_CAP = NamedValue.new(:round, 1)

        # The stroke continues half the line width beyond the endpoint of a path.
        PROJECTING_SQUARE_CAP = NamedValue.new(:projecting_square, 2)

      end


      # Defines all available line join styles as constants. Each line join style is an instance of
      # NamedValue. For use with GraphicsState#line_join_style.
      #
      # See: PDF1.7 s8.4.3.4
      module LineJoinStyle

        # Returns the argument normalized to a valid line join style.
        #
        # * 0 or :miter can be used for the MITER_JOIN style.
        # * 1 or :round can be used for the ROUND_JOIN style.
        # * 2 or :bevel can be used for the BEVEL_JOIN style.
        # * Otherwise an error is raised.
        def self.normalize(style)
          case style
          when :miter, 0 then MITER_JOIN
          when :round, 1 then ROUND_JOIN
          when :bevel, 2 then BEVEL_JOIN
          else
            raise HexaPDF::Error, "Unknown line join style: #{style}"
          end
        end

        # The outer lines of the two segments continue until the meet at an angle.
        MITER_JOIN = NamedValue.new(:miter, 0)

        # An arc of a circle is drawn around the point where the segments meet.
        ROUND_JOIN = NamedValue.new(:round, 1)

        # The two segments are finished with butt caps and the space between the ends is filled with
        # a triangle.
        BEVEL_JOIN = NamedValue.new(:bevel, 2)

      end


      # The line dash pattern defines how a line should be dashed. For use with
      # GraphicsState#line_dash_pattern.
      #
      # A dash pattern consists of two parts: the dash array and the dash phase. The dash array
      # defines the length of alternating dashes and gaps (important: starting with dashes). And the
      # dash phase defines the distance into the dash array at which to start.
      #
      # It is easier to show. Following are dash arrays and dash phases and how they would be
      # interpreted:
      #
      #   [] 0                      No dash, one solid line
      #   [3] 0                     3 unit dash, 3 unit gap, 3 unit dash, 3 unit gap, ...
      #   [3] 1                     2 unit dash, 3 unit gap, 3 unit dash, 3 unit gap, ...
      #   [2 1] 0                   2 unit dash, 1 unit gap, 2 unit dash, 1 unit gap, ...
      #   [3 5] 6                   2 unit gap, 3 unit dash, 5 unit gap, 3 unit dash, ...
      #   [2 3] 6                   1 unit dash, 3 unit gap, 2 unit dash, 3 unit gap, ...
      #
      # See: PDF1.7 s8.4.3.6
      class LineDashPattern

        # The dash array.
        attr_reader :array

        # The dash phase.
        attr_reader :phase

        # Inititalizes the line dash pattern with the given +array+ and +phase+.
        #
        # The argument +phase+ must be non-negative and the numbers in the +array+ must be
        # non-negative and must not all be zero.
        def initialize(array = [], phase = 0)
          if phase < 0 || (!array.empty? &&
                           array.inject(0) {|m, n| m < 0 ? m : (n < 0 ? -1 : m + n)} <= 0)
            raise HexaPDF::Error, "Invalid line dash pattern: #{array.inspect} #{phase.inspect}"
          end
          @array = array.freeze
          @phase = phase
        end

        # Returns +true+ if the other line dash pattern is the same as this one.
        def ==(other)
          other.kind_of?(self.class) && other.array == array && other.phase == phase
        end

        # Converts the LineDashPattern object to an array of operands for the associated PDF content
        # operator.
        def to_operands
          [@array, @phase]
        end

      end


      # Defines all available rendering intents as constants. For use with
      # GraphicsState#rendering_intent.
      #
      # See: PDF1.7 s8.6.5.8
      module RenderingIntent

        # Returns the argument normalized to a valid rendering intent.
        #
        # * If the argument is a valid symbol, it is just returned.
        # * Otherwise an error is raised.
        def self.normalize(intent)
          case intent
          when ABSOLUTE_COLORIMETRIC, RELATIVE_COLORIMETRIC, SATURATION, PERCEPTUAL
            intent
          else
            raise HexaPDF::Error, "Invalid rendering intent: #{intent}"
          end
        end

        # Colors should be represented solely with respect to the light source.
        ABSOLUTE_COLORIMETRIC = :AbsoluteColorimetric

        # Colous should be represented with respect to the combination of the light source and the
        # output medium's white point.
        RELATIVE_COLORIMETRIC = :RelativeColorimetric

        # Colors should be represented in a manner that preserves or emphasizes saturation.
        SATURATION = :Saturation

        # Colous should be represented in a manner that provides a pleasing perceptual appearance.
        PERCEPTUAL = :Perceptual

      end


      # A GraphicsState object holds all the graphic control parameters needed for correct
      # operation when parsing or creating a content stream with a Processor object.
      #
      # While a content stream is parsed/created, operations may use the current parameters or
      # modify them.
      #
      # The device-dependent graphics state parameters have not been implemented!
      #
      # See: PDF1.7 s8.4.1
      class GraphicsState

        # The current transformation matrix.
        attr_accessor :ctm

        # The current color used for stroking operations during painting.
        attr_accessor :stroke_color

        # The current color used for all other (i.e. non-stroking) painting operations.
        attr_accessor :fill_color

        # The text state parameters (see TextState).
        attr_accessor :text_state

        # The current line width in user space units.
        attr_accessor :line_width

        # The current line cap style (for the available values see LineCapStyle).
        attr_accessor :line_cap_style

        # The current line join style (for the available values see LineJoinStyle).
        attr_accessor :line_join_style

        # The maximum line length of mitered line joins for stroked paths.
        attr_accessor :miter_limit

        # The line dash pattern (see LineDashPattern).
        attr_accessor :line_dash_pattern

        # The rendering intent (only used for CIE-based colors; for the available values see
        # RenderingIntent).
        attr_accessor :rendering_intent

        # The stroke adjustment for very small line width.
        attr_accessor :stroke_adjustment

        # The current blend mode for the transparent imaging model.
        attr_accessor :blend_mode

        # The soft mask specifying the mask shape or mask opacity value to be used in the
        # transparent imaging model.
        attr_accessor :soft_mask

        # The alpha constant for stroking operations in the transparent imaging model.
        attr_accessor :stroke_alpha

        # The alpha constant for non-stroking operations in the transparent imaging model.
        attr_accessor :fill_alpha

        # A boolean specifying whether the current soft mask and alpha parameters should be
        # interpreted as shape values or opacity values.
        attr_accessor :alpha_source

        # Initializes the graphics state parameters to their default values.
        def initialize
          @ctm = TransformationMatrix.new
          @stroke_color = @fill_color =
            GlobalConfiguration.constantize('color_space.map'.freeze, :DeviceGray).new.default_color
          @text_state = TextState.new
          @line_width = 1.0
          @line_cap_style = LineCapStyle::BUTT_CAP
          @line_join_style = LineJoinStyle::MITER_JOIN
          @miter_limit = 10.0
          @line_dash_pattern = LineDashPattern.new
          @rendering_intent = RenderingIntent::RELATIVE_COLORIMETRIC
          @stroke_adjustment = false
          @blend_mode = :Normal
          @soft_mask = :None
          @stroke_alpha = @fill_alpha = 1.0
          @alpha_source = false

          @stack = []
        end

        # Saves the current graphics state on the internal stack.
        def save
          @stack.push([@ctm, @stroke_color, @fill_color, @text_state,
                       @line_width, @line_cap_style, @line_join_style, @miter_limit,
                       @line_dash_pattern, @rendering_intent, @stroke_adjustment, @blend_mode,
                       @soft_mask, @stroke_alpha, @fill_alpha, @alpha_source])
          @ctm = @ctm.dup
          @text_state = @text_state.dup
        end

        # Restores the graphics state from the internal stack.
        #
        # Raises an error if the stack is empty.
        def restore
          if @stack.empty?
            raise HexaPDF::Error, "Can't restore graphics state because the stack is empty"
          end
          @ctm, @stroke_color, @fill_color, @text_state,
          @line_width, @line_cap_style, @line_join_style, @miter_limit, @line_dash_pattern,
          @rendering_intent, @stroke_adjustment, @blend_mode,
          @soft_mask, @stroke_alpha, @fill_alpha, @alpha_source = @stack.pop
        end

        ##
        # :attr_accessor: stroke_color_space
        #
        # The current color space for stroking operations during painting.

        # :nodoc:
        def stroke_color_space
          @stroke_color.color_space
        end

        def stroke_color_space=(color_space) # :nodoc:
          self.stroke_color = color_space.default_color
        end

        ##
        # :attr_accessor: fill_color_space
        #
        # The current color space for non-stroking operations during painting.

        # :nodoc:
        def fill_color_space
          @fill_color.color_space
        end

        def fill_color_space=(color_space) #:nodoc:
          self.fill_color = color_space.default_color
        end

      end

    end
  end
end
