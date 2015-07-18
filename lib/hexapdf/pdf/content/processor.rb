# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/content/operator'
require 'hexapdf/pdf/content/graphics_state'
require 'hexapdf/pdf/content/color'

module HexaPDF
  module PDF
    module Content

      # This class is used for processing content operators.
      #
      # == General Information
      #
      # When a content stream is read, operators and their operands are extracted. Similarily when a
      # content stream is created, operators and their operands are written to it. After extracting
      # or before writing these operators are processed with a processor that ensures that the
      # needed setup (like modifying the graphics state) is done before a renderer is called.
      #
      # == How Processing Works
      #
      # Operators are processed with two kinds of objects: operator implementations and renderers.
      #
      # The operator implementations (see the Operator module) are called first and they ensure that
      # the processing state is consistent. For example, operators that modify the graphics state do
      # actually modify the #graphics_state object. However, operator implementations are *only*
      # used for this task and not more, so they are very specific and are provided by HexaPDF.
      #
      # A renderer is an user provided object that can respond to one or all operator messages. Its
      # task is to do something useful with the content itself, it doesn't need to concern itself
      # with ensuring the consistency of the processing state. For example, a renderer could use the
      # processing state to extract the text. Or paint the content on a canvas.
      #
      # == Renderer Implementations
      #
      # Each PDF operator name is mapped to a nicer message name via the OPERATOR_MESSAGE_NAME_MAP
      # constant. For example, the operator 'q' is mapped to 'save_graphics_state".
      #
      # For inline images only the 'BI' operator mapped to 'inline_image' is used. Although also the
      # operators 'ID' and 'EI' exist for inline images, they are not used because they are consumed
      # while parsing inline images and do not reflect separate operators.
      #
      # When the processor encounters an operator and the renderer responds to the equivalent
      # message, the renderer is sent the message with the operands as method arguments.
      #
      # Therefore a renderer implementation is just a plain old Ruby object that responds to certain
      # messages.
      class Processor

        # Mapping of PDF operator names to message names that are sent to renderer implementations.
        OPERATOR_MESSAGE_NAME_MAP = {
          q: :save_graphics_state,
          Q: :restore_graphics_state,
          cm: :concatenate_matrix,
          w: :set_line_width,
          J: :set_line_cap_style,
          j: :set_line_join_style,
          M: :set_miter_limit,
          d: :set_line_dash_pattern,
          ri: :set_rendering_intent,
          i: :set_flatness_tolerance,
          gs: :set_graphics_state_parameters,
          CS: :set_stroking_color_space,
          cs: :set_non_stroking_color_space,
          SC: :set_stroking_color,
          SCN: :set_stroking_color,
          sc: :set_non_stroking_color,
          scn: :set_non_stroking_color,
          G: :set_device_gray_stroking_color,
          g: :set_device_gray_non_stroking_color,
          RG: :set_device_rgb_stroking_color,
          rg: :set_device_rgb_non_stroking_color,
          K: :set_device_cmyk_stroking_color,
          k: :set_device_cmyk_non_stroking_color,
          m: :begin_subpath,
          l: :append_line,
          c: :append_curve,
          v: :append_curve_only_second_control_point,
          y: :append_curve_only_first_control_point,
          h: :close_subpath,
          re: :append_rectangle,
          S: :stroke_path,
          s: :close_and_stroke_path,
          f: :fill_path_non_zero,
          F: :fill_path_non_zero,
          'f*'.to_sym => :fill_path_even_odd,
          B: :fill_and_stroke_path_non_zero,
          'B*'.to_sym => :fill_and_stroke_path_even_odd,
          b: :close_fill_and_stroke_path_non_zero,
          'b*'.to_sym => :close_fill_and_stroke_path_even_odd,
          n: :end_path,
          W: :set_clipping_path_non_zero,
          'W*'.to_sym => :set_clipping_path_even_odd,
          BT: :begin_text,
          ET: :end_text,
          Tc: :set_character_spacing,
          Tw: :set_word_spacing,
          Tz: :set_horizontal_text_scaling,
          TL: :set_text_leading,
          Tf: :set_text_font_and_size,
          Tr: :set_text_rendering_mode,
          Ts: :set_text_rise,
          Td: :move_to_next_line_with_offset,
          TD: :move_to_next_line_with_offset_and_set_leading,
          Tm: :set_text_matrix_and_text_line_matrix,
          'T*'.to_sym => :move_to_next_line,
          Tj: :show_text,
          '\''.to_sym => :move_to_next_line_and_show_text,
          '"'.to_sym => :set_spacing_move_to_next_line_and_show_text,
          TJ: :show_text_with_positioning,
          d0: :set_glyph_width, # only for Type 3 fonts
          d1: :set_glyph_width_and_bounding_box, # only for Type 3 fonts
          sh: :paint_shading,
          BI: :inline_image, # ID and EI are not sent because the complete image has been read
          Do: :paint_xobject,
          MP: :designate_marked_content_point,
          DP: :designate_marked_content_point_with_property_list,
          BMC: :begin_marked_content,
          BDC: :begin_marked_content_with_property_list,
          EMC: :end_marked_content,
          BX: :begin_compatibility_section,
          EX: :end_compatibility_section,
        }

        # Mapping of operator names to their default operator implentations used for processing.
        DEFAULT_OPERATORS = {
          q: Operator::SaveGraphicsState,
          Q: Operator::RestoreGraphicsState,
          cm: Operator::ConcatenateMatrix,
          w: Operator::SetLineWidth,
          J: Operator::SetLineCap,
          j: Operator::SetLineJoin,
          M: Operator::SetMiterLimit,
          d: Operator::SetLineDashPattern,
          ri: Operator::SetRenderingIntent,
          gs: Operator::SetGraphicsStateParameters,
          CS: Operator::SetStrokingColorSpace,
          cs: Operator::SetNonStrokingColorSpace,
          SC: Operator::SetStrokingColor,
          SCN: Operator::SetStrokingColor,
          sc: Operator::SetNonStrokingColor,
          scn: Operator::SetNonStrokingColor,
          G: Operator::SetDeviceGrayStrokingColor,
          g: Operator::SetDeviceGrayNonStrokingColor,
          RG: Operator::SetDeviceRGBStrokingColor,
          rg: Operator::SetDeviceRGBNonStrokingColor,
          K: Operator::SetDeviceCMYKStrokingColor,
          k: Operator::SetDeviceCMYKNonStrokingColor,
          m: Operator::BeginPath,
          re: Operator::BeginPath,
          S: Operator::EndPath,
          s: Operator::EndPath,
          f: Operator::EndPath,
          F: Operator::EndPath,
          'f*'.to_sym => Operator::EndPath,
          B: Operator::EndPath,
          'B*'.to_sym => Operator::EndPath,
          b: Operator::EndPath,
          'b*'.to_sym => Operator::EndPath,
          n: Operator::EndPath,
          W: Operator::ClipPath,
          'W*'.to_sym => Operator::ClipPath,
        }

        # Mapping of supported color space names to their implementation.
        DEFAULT_COLOR_SPACES = {
          DeviceRGB: DeviceRGBColorSpace,
          DeviceCMYK: DeviceCMYKColorSpace,
          DeviceGray: DeviceGrayColorSpace,
        }

        # Mapping from operator name (Symbol) to a callable object.
        #
        # This hash is prepopulated with the default operator implementations (see
        # DEFAULT_OPERATORS). If a default operator implementation is not satisfactory, it can
        # easily be changed by modifying this hash.
        attr_reader :operators

        # Mapping from color space name (Symbol) to a color space implementation.
        #
        # This hash is prepopulated with all supported color spaces (see DEFAULT_COLOR_SPACES) and
        # can be used to support additional color spaces or exchange the implementation of existing
        # ones.
        attr_reader :color_spaces

        # The resources dictionary used during processing.
        attr_reader :resources

        # The GraphicsState object containing the current graphics state.
        #
        # It is not advised that this attribute is changed manually, it is automatically adjusted
        # according to the processed operators!
        attr_reader :graphics_state

        # The current graphics object.
        #
        # It is not advised that this attribute is changed manually, it is automatically adjusted
        # according to the processed operators!
        #
        # This attribute can have the following values:
        #
        # :none:: No current graphics object, i.e. the processor is at the page description level.
        # :path:: The current graphics object is a path.
        # :clipping_path:: The current graphics object is a clipping path.
        # :text:: The current graphics object is text.
        #
        # See: PDF1.7 s8.2
        attr_accessor :graphics_object

        # Initializes a new processor that uses the +resources+ PDF dictionary for resolving
        # resources while processing operators.
        def initialize(resources, renderer: nil)
          @operators = DEFAULT_OPERATORS.dup
          @color_spaces = DEFAULT_COLOR_SPACES.dup
          @graphics_state = GraphicsState.new
          @resources = resources
          @renderer = renderer
          @graphics_object = :none
        end

        # Processes the operator with the given operands.
        #
        # The operator is first processed with an operator implementation (if any) to ensure correct
        # operations and then the corresponding method on the renderer is invoked.
        def process(operator, operands = [])
          @operators[operator].call(self, *operands) if @operators.key?(operator)
          msg = OPERATOR_MESSAGE_NAME_MAP[operator]
          @renderer.send(msg, *operands) if @renderer && @renderer.respond_to?(msg)
        end

        # Returns the color space implementation for the given color space name. If the color space
        # isn't yet supported, the UniversalColorSpace is returned.
        def color_space(name)
          @color_spaces.fetch(name, UniversalColorSpace)
        end

        # Returns +true+ if the current graphics object is a text object.
        def in_text?
          @graphics_object == :text
        end

        # Returns +true+ if the current graphics object is a path or clipping path object.
        def in_path?
          @graphics_object == :path || @graphics_object == :clipping_path
        end

      end

    end
  end
end
