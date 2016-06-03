# -*- encoding: utf-8 -*-

require 'hexapdf/content/operator'
require 'hexapdf/content/graphics_state'

module HexaPDF
  module Content

    # This class is used for processing content operators extracted from a content stream.
    #
    # == General Information
    #
    # When a content stream is read, operators and their operands are extracted. After extracting
    # these operators are normally processed with a Processor instance that ensures that the needed
    # setup (like modifying the graphics state) is done before further processing.
    #
    # == How Processing Works
    #
    # The operator implementations (see the Operator module) are called first and they ensure that
    # the processing state is consistent. For example, operators that modify the graphics state do
    # actually modify the #graphics_state object. However, operator implementations are *only* used
    # for this task and not more, so they are very specific and normally don't need to be changed.
    #
    # After that methods corresponding to the operator names are invoked on the processor object (if
    # they exist). Each PDF operator name is mapped to a nicer message name via the
    # OPERATOR_MESSAGE_NAME_MAP constant. For example, the operator 'q' is mapped to
    # 'save_graphics_state".
    #
    # The task of these methods is to do something useful with the content itself, it doesn't need
    # to concern itself with ensuring the consistency of the processing state. For example, the
    # processor could use the processing state to extract the text. Or paint the content on a
    # canvas.
    #
    # For inline images only the 'BI' operator mapped to 'inline_image' is used. Although also the
    # operators 'ID' and 'EI' exist for inline images, they are not used because they are consumed
    # while parsing inline images and do not reflect separate operators.
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
        m: :move_to,
        l: :line_to,
        c: :curve_to,
        v: :curve_to_no_first_control_point,
        y: :curve_to_no_second_control_point,
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
        W: :clip_path_non_zero,
        'W*'.to_sym => :clip_path_even_odd,
        BT: :begin_text,
        ET: :end_text,
        Tc: :set_character_spacing,
        Tw: :set_word_spacing,
        Tz: :set_horizontal_scaling,
        TL: :set_leading,
        Tf: :set_font_and_size,
        Tr: :set_text_rendering_mode,
        Ts: :set_text_rise,
        Td: :move_text,
        TD: :move_text_and_set_leading,
        Tm: :set_text_matrix,
        'T*'.to_sym => :move_text_next_line,
        Tj: :show_text,
        '\''.to_sym => :move_text_next_line_and_show_text,
        '"'.to_sym => :set_spacing_move_text_next_line_and_show_text,
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

      # Mapping from operator name (Symbol) to a callable object.
      #
      # This hash is prepopulated with the default operator implementations (see
      # DEFAULT_OPERATORS). If a default operator implementation is not satisfactory, it can
      # easily be changed by modifying this hash.
      attr_reader :operators

      # The resources dictionary used during processing.
      attr_accessor :resources

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
      #
      # It is not mandatory to set the resources dictionary on initialization but it needs to be set
      # prior to processing operators!
      def initialize(resources = nil)
        @operators = Operator::DEFAULT_OPERATORS.dup
        @graphics_state = GraphicsState.new
        @resources = resources
        @graphics_object = :none
      end

      # Processes the operator with the given operands.
      #
      # The operator is first processed with an operator implementation (if any) to ensure correct
      # operations and then the corresponding method on this object is invoked.
      def process(operator, operands = [])
        @operators[operator].invoke(self, *operands) if @operators.key?(operator)
        msg = OPERATOR_MESSAGE_NAME_MAP[operator]
        send(msg, *operands) if msg && respond_to?(msg)
      end

    end

  end
end
