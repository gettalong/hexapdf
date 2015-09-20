# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/content/graphics_state'

module HexaPDF
  module PDF
    module Content

      # This module contains the content operator implementations.
      #
      # == General Information
      #
      # A PDF content streams consists of a series of instructions, operands followed by an operator
      # name. Each operator has a specific function, for example, the 'G' operator sets the stroke
      # color to the specified gray value.
      #
      # Since HexaPDF doesn't have a content stream rendering facility, it is only interested in the
      # effects an operator has on the graphics state. By calling the #invoke method with an
      # OperatorProcessor as first argument and the operands as the rest of the arguments, the
      # operator can modify the graphics state as needed. This ensures internal consistency and
      # correct operation.
      #
      # Operator objects are designed to be state-less. This means that the operands have to be
      # passed as arguments to the methods that need them.
      #
      #
      # == Operator Implementations
      #
      # HexaPDF comes with operator implementations for all PDF operations. These operator
      # implementations are derived from the BaseOperator class which provides all needed methods.
      #
      # In general, an operator implementation is an object that responds to the following methods:
      #
      # #invoke(processor, *operands)::
      #   When an operator is invoked, it performs its job, e.g. changing the graphics state.
      #
      # #serialize(serializer, *operands)::
      #   Returns the operator together with its operands in serialized form.
      #
      # #name::
      #   Returns the name of the operator as String.
      #
      # See: PDF1.7 s8, s9
      module Operator

        # A base class for operator implementations.
        #
        # A default implementation for the #serialize method is provided. However, for performance
        # reasons each operator should provide a custom #serialize method.
        class BaseOperator

          # The name of the operator.
          attr_reader :name

          # Initialize the operator called +name+.
          def initialize(name)
            @name = name.freeze
          end

          # Invokes the operator so that it performs its job.
          #
          # This base version does nothing!
          def invoke(*)
          end

          # Returns the string representation of the operator, i.e.
          #
          #   operand1 operand2 operand3 name
          def serialize(serializer, *operands)
            result = ''.force_encoding(Encoding::BINARY)
            operands.each do |operand|
              result << serializer.serialize(operand) << " ".freeze
            end
            result << name << "\n".freeze
          end

        end

        # A specialized operator class for operators that take no arguments. Provides an optimized
        # #serialize method.
        class NoArgumentOperator < BaseOperator

          def initialize(name) #:nodoc:
            super(name)
            @serialized = "#{name}\n".freeze
          end

          # An optimized version of the serialization algorithm.
          #
          # See: BaseOperator#serialize
          def serialize(_serializer)
            @serialized
          end

        end

        # A specialized operator class for operators that take a single numeric argument. Provides
        # an optimized #serialize method.
        class SingleNumericArgumentOperator < BaseOperator

          # An optimized version of the serialization algorithm.
          #
          # See: BaseOperator#serialize
          def serialize(serializer, arg)
            "#{serializer.serialize_numeric(arg)} #{name}\n"
          end

        end

        # Implementation of the 'q' operator.
        #
        # See: PDF1.7 s8.4.4
        class SaveGraphicsState < NoArgumentOperator

          # Creates the operator.
          def initialize
            super('q')
          end

          def invoke(processor) #:nodoc:
            processor.graphics_state.save
          end

        end

        # Implementation of the 'Q' operator.
        #
        # See: PDF1.7 s8.4.4
        class RestoreGraphicsState < NoArgumentOperator

          # Creates the operator.
          def initialize
            super('Q')
          end

          def invoke(processor) #:nodoc:
            processor.graphics_state.restore
          end

        end

        # Implementation of the 'cm' operator.
        #
        # See: PDF1.7 s8.4.4
        class ConcatenateMatrix < BaseOperator

          # Creates the operator.
          def initialize
            super('cm')
          end

          def invoke(processor, a, b, c, d, e, f) #:nodoc:
            processor.graphics_state.ctm.premultiply(a, b, c, d, e, f)
          end

          def serialize(serializer, a, b, c, d, e, f) #:nodoc:
            "#{serializer.serialize_numeric(a)} #{serializer.serialize_numeric(b)} " \
              "#{serializer.serialize_numeric(c)} #{serializer.serialize_numeric(d)} " \
              "#{serializer.serialize_numeric(e)} #{serializer.serialize_numeric(f)} cm\n"
          end

        end

        # Implementation of the 'w' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetLineWidth < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('w')
          end

          def invoke(processor, width) #:nodoc:
            processor.graphics_state.line_width = width
          end

        end

        # Implementation of the 'J' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetLineCapStyle < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('J')
          end

          def invoke(processor, cap_style) #:nodoc:
            processor.graphics_state.line_cap_style = LineCapStyle.normalize(cap_style)
          end

        end

        # Implementation of the 'j' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetLineJoinStyle < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('j')
          end

          def invoke(processor, join_style) #:nodoc:
            processor.graphics_state.line_join_style = LineJoinStyle.normalize(join_style)
          end

        end

        # Implementation of the 'M' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetMiterLimit < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('M')
          end

          def invoke(processor, miter_limit) #:nodoc:
            processor.graphics_state.miter_limit = miter_limit
          end

        end

        # Implementation of the 'd' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetLineDashPattern < BaseOperator

          # Creates the operator.
          def initialize
            super('d')
          end

          def invoke(processor, dash_array, dash_phase) #:nodoc:
            processor.graphics_state.line_dash_pattern = LineDashPattern.new(dash_array, dash_phase)
          end

          def serialize(serializer, dash_array, dash_phase) #:nodoc:
            "#{serializer.serialize_array(dash_array)} " \
              "#{serializer.serialize_integer(dash_phase)} d\n".freeze
          end

        end

        # Implementation of the 'ri' operator.
        #
        # See: PDF1.7 s8.4.4
        class SetRenderingIntent < BaseOperator

          # Creates the operator.
          def initialize
            super('ri')
          end

          def invoke(processor, intent) #:nodoc:
            processor.graphics_state.rendering_intent = intent
          end

          def serialize(serializer, intent) #:nodoc:
            "#{serializer.serialize_symbol(intent)} ri\n".freeze
          end

        end

        # Implementation of the 'gs' operator.
        #
        # Note: Only parameters supported by the GraphicsState/TextState classes are assigned, the
        # rest are ignored!
        #
        # See: PDF1.7 s8.4.4
        class SetGraphicsStateParameters < BaseOperator

          # Creates the operator.
          def initialize
            super('gs')
          end

          def invoke(processor, name) #:nodoc:
            dict = processor.resources.ext_gstate(name)

            ops = processor.operators
            ops[:w].invoke(processor, dict[:LW]) if dict.key?(:LW)
            ops[:J].invoke(processor, dict[:LC]) if dict.key?(:LC)
            ops[:j].invoke(processor, dict[:LJ]) if dict.key?(:LJ)
            ops[:M].invoke(processor, dict[:ML]) if dict.key?(:ML)
            ops[:d].invoke(processor, *dict[:D]) if dict.key?(:D)
            ops[:ri].invoke(processor, dict[:RI]) if dict.key?(:RI)
            # TODO: dict[:Font] for font and font_size
            # TODO: dict[:SMask] works differently than operator!

            # No content operator exists for the following parameters
            gs = processor.graphics_state
            gs.stroke_adjustment = dict[:SA] if dict.key?(:SA)
            gs.blend_mode = dict[:BM] if dict.key?(:BM)
            gs.stroke_alpha = dict[:CA] if dict.key?(:CA)
            gs.fill_alpha = dict[:ca] if dict.key?(:ca)
            gs.alpha_source = dict[:AIS] if dict.key?(:AIS)
            gs.text_knockout = dict[:TK] if dict.key?(:TK)
          end

          def serialize(serializer, name) #:nodoc:
            "#{serializer.serialize_symbol(name)} gs\n".freeze
          end

        end

        # Implementation of the 'CS' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetStrokingColorSpace < BaseOperator

          # Creates the operator.
          def initialize
            super('CS')
          end

          def invoke(processor, name) #:nodoc:
            processor.graphics_state.stroke_color_space = processor.resources.color_space(name)
          end

          def serialize(serializer, name) #:nodoc:
            "#{serializer.serialize_symbol(name)} CS\n".freeze
          end

        end

        # Implementation of the 'cs' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetNonStrokingColorSpace < BaseOperator

          # Creates the operator.
          def initialize
            super('cs')
          end

          def invoke(processor, name) #:nodoc:
            processor.graphics_state.fill_color_space = processor.resources.color_space(name)
          end

          def serialize(serializer, name) #:nodoc:
            "#{serializer.serialize_symbol(name)} cs\n".freeze
          end

        end

        # Implementation of the 'SC' and 'SCN' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetStrokingColor < BaseOperator

          def invoke(processor, *operands) #:nodoc:
            processor.graphics_state.stroke_color =
              processor.graphics_state.stroke_color.color_space.color(*operands)
          end

        end

        # Implementation of the 'sc' and 'scn' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetNonStrokingColor < BaseOperator

          def invoke(processor, *operands) #:nodoc:
            processor.graphics_state.fill_color =
              processor.graphics_state.fill_color.color_space.color(*operands)
          end

        end

        # Implementation of the 'G' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceGrayStrokingColor < SingleNumericArgumentOperator

          def initialize #:nodoc:
            super('G')
          end

          def invoke(processor, gray) #:nodoc:
            processor.graphics_state.stroke_color =
              processor.resources.color_space(:DeviceGray).color(gray)
          end

        end

        # Implementation of the 'g' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceGrayNonStrokingColor < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('g')
          end

          def invoke(processor, gray) #:nodoc:
            processor.graphics_state.fill_color =
              processor.resources.color_space(:DeviceGray).color(gray)
          end

        end

        # Implementation of the 'RG' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceRGBStrokingColor < BaseOperator

          # Creates the operator.
          def initialize
            super('RG')
          end

          def invoke(processor, r, g, b) #:nodoc:
            processor.graphics_state.stroke_color =
              processor.resources.color_space(:DeviceRGB).color(r, g, b)
          end

          def serialize(serializer, r, g, b) #:nodoc:
            "#{serializer.serialize_numeric(r)} #{serializer.serialize_numeric(g)} " \
              "#{serializer.serialize_numeric(b)} RG\n".freeze
          end

        end

        # Implementation of the 'rg' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceRGBNonStrokingColor < BaseOperator

          # Creates the operator.
          def initialize
            super('rg')
          end

          def invoke(processor, r, g, b) #:nodoc:
            processor.graphics_state.fill_color =
              processor.resources.color_space(:DeviceRGB).color(r, g, b)
          end

          def serialize(serializer, r, g, b) #:nodoc:
            "#{serializer.serialize_numeric(r)} #{serializer.serialize_numeric(g)} " \
              "#{serializer.serialize_numeric(b)} rg\n".freeze
          end

        end

        # Implementation of the 'K' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceCMYKStrokingColor < BaseOperator

          # Creates the operator.
          def initialize
            super('K')
          end

          def invoke(processor, c, m, y, k) #:nodoc:
            processor.graphics_state.stroke_color =
              processor.resources.color_space(:DeviceCMYK).color(c, m, y, k)
          end

          def serialize(serializer, c, m, y, k) #:nodoc:
            "#{serializer.serialize_numeric(c)} #{serializer.serialize_numeric(m)} " \
              "#{serializer.serialize_numeric(y)} #{serializer.serialize_numeric(k)} K\n".freeze
          end

        end

        # Implementation of the 'k' operator.
        #
        # See: PDF1.7 s8.6.8
        class SetDeviceCMYKNonStrokingColor < BaseOperator

          # Creates the operator.
          def initialize
            super('k')
          end

          def invoke(processor, c, m, y, k) #:nodoc:
            processor.graphics_state.fill_color =
              processor.resources.color_space(:DeviceCMYK).color(c, m, y, k)
          end

          def serialize(serializer, c, m, y, k) #:nodoc:
            "#{serializer.serialize_numeric(c)} #{serializer.serialize_numeric(m)} " \
              "#{serializer.serialize_numeric(y)} #{serializer.serialize_numeric(k)} k\n".freeze
          end

        end

        # Implementation of the 'm' operator.
        #
        # See: PDF1.7 s8.5.2.1
        class MoveTo < BaseOperator

          # Creates the operator.
          def initialize
            super('m')
          end

          def invoke(processor, _x, _y) #:nodoc:
            processor.graphics_object = :path
          end

          def serialize(serializer, x, y) #:nodoc:
            "#{serializer.serialize_numeric(x)} #{serializer.serialize_numeric(y)} m\n".freeze
          end

        end

        # Implementation of the 're' operator.
        #
        # See: PDF1.7 s8.5.2.1
        class AppendRectangle < BaseOperator

          # Creates the operator.
          def initialize
            super('re')
          end

          def invoke(processor, _x, _y, _w, _h) #:nodoc:
            processor.graphics_object = :path
          end

          def serialize(serializer, x, y, w, h) #:nodoc:
            "#{serializer.serialize_numeric(x)} #{serializer.serialize_numeric(y)} " \
              "#{serializer.serialize_numeric(w)} #{serializer.serialize_numeric(h)} re\n".freeze
          end

        end

        # Implementation of the 'l' operator.
        #
        # See: PDF1.7 s8.5.2.1
        class LineTo < BaseOperator

          # Creates the operator.
          def initialize
            super('l')
          end

          def serialize(serializer, x, y) #:nodoc:
            "#{serializer.serialize_numeric(x)} #{serializer.serialize_numeric(y)} l\n".freeze
          end

        end

        # Implementation of the 'c' operators.
        #
        # See: PDF1.7 s8.5.2.1
        class CurveTo < BaseOperator

          # Creates the operator.
          def initialize
            super('c')
          end

          def serialize(serializer, x1, y1, x2, y2, x3, y3) #:nodoc:
            "#{serializer.serialize_numeric(x1)} #{serializer.serialize_numeric(y1)} " \
              "#{serializer.serialize_numeric(x2)} #{serializer.serialize_numeric(y2)} " \
              "#{serializer.serialize_numeric(x3)} #{serializer.serialize_numeric(y3)} c\n".freeze
          end

        end

        # Implementation of the 'v' operators.
        #
        # See: PDF1.7 s8.5.2.1
        class CurveToNoFirstControlPoint < BaseOperator

          # Creates the operator.
          def initialize
            super('v')
          end

          def serialize(serializer, x2, y2, x3, y3) #:nodoc:
            "#{serializer.serialize_numeric(x2)} #{serializer.serialize_numeric(y2)} " \
              "#{serializer.serialize_numeric(x3)} #{serializer.serialize_numeric(y3)} v\n".freeze
          end

        end

        # Implementation of the 'y' operators.
        #
        # See: PDF1.7 s8.5.2.1
        class CurveToNoSecondControlPoint < BaseOperator

          # Creates the operator.
          def initialize
            super('y')
          end

          def serialize(serializer, x1, y1, x3, y3) #:nodoc:
            "#{serializer.serialize_numeric(x1)} #{serializer.serialize_numeric(y1)} " \
              "#{serializer.serialize_numeric(x3)} #{serializer.serialize_numeric(y3)} y\n".freeze
          end

        end

        # Implementation of the 'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*' and 'n' operators.
        #
        # See: PDF1.7 s8.5.3.1
        class EndPath < NoArgumentOperator

          def invoke(processor) #:nodoc:
            processor.graphics_object = :none
          end

        end

        # Implementation of the 'W' and 'W*' operators.
        #
        # See: PDF1.7 s8.5.4
        class ClipPath < NoArgumentOperator

          def invoke(processor) #:nodoc:
            processor.graphics_object = :clipping_path
          end

        end

        # Implementation of the 'BI' operator which handles the *complete* inline image, i.e. the
        # 'ID' and 'EI' operators are never encountered.
        #
        # See: PDF1.7 s8.9.7
        class InlineImage < BaseOperator

          # Creates the operator.
          def initialize
            super('BI')
          end

          def serialize(serializer, dict, data) #:nodoc:
            result = "BI\n"
            dict.each do |k, v|
              result << serializer.serialize_symbol(k) << ' '.freeze
              result << serializer.serialize(v) << ' '.freeze
            end
            result << "ID\n".freeze << data << "EI\n"
          end

        end

        # Implementation of the 'Tc' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetCharacterSpacing < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('Tc')
          end

          def invoke(processor, char_space) #:nodoc:
            processor.graphics_state.character_spacing = char_space
          end

        end

        # Implementation of the 'Tw' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetWordSpacing < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('Tw')
          end

          def invoke(processor, word_space) #:nodoc:
            processor.graphics_state.word_spacing = word_space
          end

        end

        # Implementation of the 'Tz' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetHorizontalScaling < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('Tz')
          end

          def invoke(processor, scale) #:nodoc:
            processor.graphics_state.horizontal_scaling = scale
          end

        end

        # Implementation of the 'TL' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetLeading < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('TL')
          end

          def invoke(processor, leading) #:nodoc:
            processor.graphics_state.leading = leading
          end

        end

        # Implementation of the 'Tf' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetFontAndSize < BaseOperator

          # Creates the operator.
          def initialize
            super('Tf')
          end

          def invoke(processor, font, size) #:nodoc:
            :todo # TODO
          end

          def serialize(serializer, font, size) #:nodoc:
            "#{serializer.serialize_symbol(font)} #{serializer.serialize_numeric(size)} Tf\n".freeze
          end

        end

        # Implementation of the 'Tr' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetTextRenderingMode < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('Tr')
          end

          def invoke(processor, rendering_mode) #:nodoc:
            processor.graphics_state.text_rendering_mode = rendering_mode
          end

        end

        # Implementation of the 'Ts' operator.
        #
        # See: PDF1.7 s9.3.1
        class SetTextRise < SingleNumericArgumentOperator

          # Creates the operator.
          def initialize
            super('Ts')
          end

          def invoke(processor, rise) #:nodoc:
            processor.graphics_state.text_rise = rise
          end

        end

        # Implementation of the 'BT' operator.
        #
        # See: PDF1.7 s9.4.1
        class BeginText < NoArgumentOperator

          def initialize #:nodoc:
            super('BT')
          end

          def invoke(processor) #:nodoc:
            processor.graphics_object = :text
          end

        end

        # Implementation of the 'ET' operator.
        #
        # See: PDF1.7 s9.4.1
        class EndText < NoArgumentOperator

          # Creates the operator.
          def initialize
            super('ET')
          end

          def invoke(processor) #:nodoc:
            processor.graphics_object = :none
          end

        end

        # Implementation of the 'Td' operator.
        #
        # See: PDF1.7 s9.4.2
        class MoveText < BaseOperator

          # Creates the operator.
          def initialize
            super('Td')
          end

          def invoke(processor, tx, ty) #:nodoc:
            :todo # TODO
          end

          def serialize(serializer, tx, ty) #:nodoc:
            "#{serializer.serialize_numeric(tx)} #{serializer.serialize_numeric(ty)} Td\n".freeze
          end

        end

        # Implementation of the 'TD' operator.
        #
        # See: PDF1.7 s9.4.2
        class MoveTextAndSetLeading < BaseOperator

          # Creates the operator.
          def initialize
            super('TD')
          end

          def invoke(processor, tx, ty) #:nodoc:
            processor.operators[:TL].invoke(processor, -ty)
            processor.operators[:Td].invoke(processor, tx, ty)
          end

          def serialize(serializer, tx, ty) #:nodoc:
            "#{serializer.serialize_numeric(tx)} #{serializer.serialize_numeric(ty)} TD\n".freeze
          end

        end

        # Implementation of the 'Tm' operator.
        #
        # See: PDF1.7 s9.4.2
        class SetTextMatrix < BaseOperator

          # Creates the operator.
          def initialize
            super('Tm')
          end

          def invoke(processor, a, b, c, d, e, f) #:nodoc:
            :todo # TODO
          end

          def serialize(serializer, a, b, c, d, e, f) #:nodoc:
            "#{serializer.serialize_numeric(a)} #{serializer.serialize_numeric(b)} " \
              "#{serializer.serialize_numeric(c)} #{serializer.serialize_numeric(d)} " \
              "#{serializer.serialize_numeric(e)} #{serializer.serialize_numeric(f)} Tm\n".freeze
          end

        end

        # Implementation of the 'T*' operator.
        #
        # See: PDF1.7 s9.4.2
        class MoveTextNextLine < NoArgumentOperator

          # Creates the operator.
          def initialize
            super('T*')
          end

          def invoke(processor) #:nodoc:
            leading = processor.graphics_state.leading
            processor.operators[:Td].invoke(processor, 0, -leading)
          end

        end

        # Implementation of the 'Tj' operator.
        #
        # See: PDF1.7 s9.4.3
        class ShowText < BaseOperator

          # Creates the operator.
          def initialize
            super('Tj')
          end

          def invoke(processor, text) #:nodoc:
            :todo # TODO
          end

          def serialize(serializer, text) #:nodoc:
            "#{serializer.serialize_string(text)} Tj\n".freeze
          end

        end

        # Implementation of the ' operator.
        #
        # See: PDF1.7 s9.4.3
        class MoveTextNextLineAndShowText < BaseOperator

          def initialize #:nodoc:
            super("'")
          end

          def invoke(processor, text) #:nodoc:
            processor.operators[:'T*'].invoke(processor)
            processor.operators[:Tj].invoke(processor, text)
          end

          def serialize(serializer, text)
            "#{serializer.serialize_string(text)} '\n".freeze
          end

        end

        # Implementation of the " operator.
        #
        # See: PDF1.7 s9.4.3
        class SetSpacingMoveTextNextLineAndShowText < BaseOperator

          # Creates the operator.
          def initialize
            super('"')
          end

          def invoke(processor, word_space, char_space, text) #:nodoc:
            processor.operators[:Tw].invoke(processor, word_space)
            processor.operators[:Tc].invoke(processor, char_space)
            processor.operators[:"'"].invoke(processor, text)
          end

          def serialize(serializer, word_space, char_space, text) #:nodoc:
            "#{serializer.serialize_numeric(word_space)} " \
              "#{serializer.serialize_numeric(char_space)} " \
              "#{serializer.serialize_string(text)} \"\n".freeze
          end

        end


        # Implementation of the 'TJ' operator.
        #
        # See: PDF1.7 s9.4.3
        class ShowTextWithPositioning < BaseOperator

          # Creates the operator.
          def initialize
            super('TJ')
          end

          def invoke(processor, array) #:nodoc:
            :todo # TODO
          end

          def serialize(serializer, array) #:nodoc:
            "#{serializer.serialize_array(array)} TJ\n".freeze
          end

        end


        # Mapping of operator names to their default operator implementations.
        DEFAULT_OPERATORS = {
          q: SaveGraphicsState.new,
          Q: RestoreGraphicsState.new,
          cm: ConcatenateMatrix.new,
          w: SetLineWidth.new,
          J: SetLineCapStyle.new,
          j: SetLineJoinStyle.new,
          M: SetMiterLimit.new,
          d: SetLineDashPattern.new,
          ri: SetRenderingIntent.new,
          gs: SetGraphicsStateParameters.new,
          CS: SetStrokingColorSpace.new,
          cs: SetNonStrokingColorSpace.new,
          SC: SetStrokingColor.new('SC'),
          SCN: SetStrokingColor.new('SCN'),
          sc: SetNonStrokingColor.new('sc'),
          scn: SetNonStrokingColor.new('scn'),
          G: SetDeviceGrayStrokingColor.new,
          g: SetDeviceGrayNonStrokingColor.new,
          RG: SetDeviceRGBStrokingColor.new,
          rg: SetDeviceRGBNonStrokingColor.new,
          K: SetDeviceCMYKStrokingColor.new,
          k: SetDeviceCMYKNonStrokingColor.new,
          m: MoveTo.new,
          re: AppendRectangle.new,
          l: LineTo.new,
          c: CurveTo.new,
          v: CurveToNoFirstControlPoint.new,
          y: CurveToNoSecondControlPoint.new,
          h: NoArgumentOperator.new('h'),
          S: EndPath.new('S'),
          s: EndPath.new('s'),
          f: EndPath.new('f'),
          F: EndPath.new('F'),
          'f*'.to_sym => EndPath.new('f*'),
          B: EndPath.new('B'),
          'B*'.to_sym => EndPath.new('B*'),
          b: EndPath.new('b'),
          'b*'.to_sym => EndPath.new('b*'),
          n: EndPath.new('n'),
          W: ClipPath.new('W'),
          'W*'.to_sym => ClipPath.new('W*'),

          BI: InlineImage.new,

          BT: BeginText.new,
          ET: EndText.new,
          Tc: SetCharacterSpacing.new,
          Tw: SetWordSpacing.new,
          Tz: SetHorizontalScaling.new,
          TL: SetLeading.new,
          Tf: SetFontAndSize.new,
          Tr: SetTextRenderingMode.new,
          Ts: SetTextRise.new,
          Td: MoveText.new,
          TD: MoveTextAndSetLeading.new,
          Tm: SetTextMatrix.new,
          'T*'.to_sym => MoveTextNextLine.new,
          Tj: ShowText.new,
          '\''.to_sym => MoveTextNextLineAndShowText.new,
          '"'.to_sym => SetSpacingMoveTextNextLineAndShowText.new,
          TJ: ShowTextWithPositioning.new,
        }
        DEFAULT_OPERATORS.default_proc = proc {|h, k| h[k] = BaseOperator.new(k.to_s)}

      end

    end
  end
end
