# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/content/color'
require 'hexapdf/pdf/content/text_state'
require 'hexapdf/pdf/content/transformation_matrix'

module HexaPDF
  module PDF
    module Content

      # Defines all available line cap styles as constants. For use with
      # GraphicsState#line_cap_style.
      #
      # See: PDF1.7 s8.4.3.3
      module LineCapStyle

        # Stroke is squared off at the endpoint of a path.
        BUTT_CAP = 0

        # A semicircular arc is drawn at the endpoint of a path.
        ROUND_CAP = 1

        # The stroke continues half the line width beyond the endpoint of a path.
        PROJECTING_SQUARE_CAP = 2

      end


      # Defines all available line join styles as constants. For use with
      # GraphicsState#line_join_style.
      #
      # See: PDF1.7 s8.4.3.4
      module LineJoinStyle

        # The outer lines of the two segments continue until the meet at an angle.
        MITER_JOIN = 0

        # An arc of a circle is drawn around the point where the segments meet.
        ROUND_JOIN = 1

        # The two segments are finished with butt caps and the space between the ends is filled with
        # a triangle.
        BEVEL_JOIN = 2

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

      end


      # Defines all available rendering intents as constants. For use with
      # GraphicsState#rendering_intent.
      #
      # See: PDF1.7 s8.6.5.8
      module RenderingIntent

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
        attr_accessor :stroking_color

        # The current color used for all other (i.e. non-stroking) painting operations.
        attr_accessor :non_stroking_color

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
        attr_accessor :stroking_alpha

        # The alpha constant for non-stroking operations in the transparent imaging model.
        attr_accessor :non_stroking_alpha

        # A boolean specifying whether the current soft mask and alpha parameters should be
        # interpreted as shape values or opacity values.
        attr_accessor :alpha_source

        # Initializes the graphics state parameters to their default values.
        def initialize
          @ctm = TransformationMatrix.new
          @stroking_color = @non_stroking_color = DeviceGrayColorSpace.default_color
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
          @stroking_alpha = @non_stroking_alpha = 1.0
          @alpha_source = false

          @stack = []
        end

        # Saves the current graphics state on the internal stack.
        def save
          @stack.push([@ctm, @stroking_color, @non_stroking_color, @text_state,
                       @line_width, @line_cap_style, @line_join_style, @miter_limit,
                       @line_dash_pattern, @rendering_intent, @stroke_adjustment, @blend_mode,
                       @soft_mask, @stroking_alpha, @non_stroking_alpha, @alpha_source])
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
          @ctm, @stroking_color, @non_stroking_color, @text_state,
          @line_width, @line_cap_style, @line_join_style, @miter_limit, @line_dash_pattern,
          @rendering_intent, @stroke_adjustment, @blend_mode,
          @soft_mask, @stroking_alpha, @non_stroking_alpha, @alpha_source = @stack.pop
        end

        ##
        # :attr_accessor: stroking_color_space
        #
        # The current color space for stroking operations during painting.

        # :nodoc:
        def stroking_color_space
          @stroking_color.color_space
        end

        def stroking_color_space=(color_space) # :nodoc:
          self.stroking_color = color_space.default_color
        end

        ##
        # :attr_accessor: non_stroking_color_space
        #
        # The current color space for non-stroking operations during painting.

        # :nodoc:
        def non_stroking_color_space
          @non_stroking_color.color_space
        end

        def non_stroking_color_space=(color_space) #:nodoc:
          self.non_stroking_color = color_space.default_color
        end

      end

    end
  end
end
