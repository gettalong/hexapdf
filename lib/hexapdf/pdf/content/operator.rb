# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/content/graphics_state'

module HexaPDF
  module PDF
    module Content

      # This module contains the default operator implementations.
      #
      # Operators ensure internal consistency and correct operation regardless of the renderer
      # implementation. Therefore they do not render or output anything, they just modify the
      # internal state (e.g. the graphics state).
      #
      # An operator implementation is a callable object that takes an OperatorProcessor as first
      # argument and the operands as the rest of the arguments.
      #
      # See: PDF1.7 s8, s9
      module Operator

        # Implementation of the 'q' operator.
        module SaveGraphicsState

          def self.call(processor) #:nodoc:
            processor.graphics_state.save
          end

        end

        # Implementation of the 'Q' operator.
        module RestoreGraphicsState

          def self.call(processor) #:nodoc:
            processor.graphics_state.restore
          end

        end

        # Implementation of the 'cm' operator.
        module ConcatenateMatrix

          def self.call(processor, a, b, c, d, e, f) #:nodoc:
            processor.graphics_state.ctm.premultiply(a, b, c, d, e, f)
          end

        end

        # Implementation of the 'w' operator.
        module SetLineWidth

          def self.call(processor, width) #:nodoc:
            processor.graphics_state.line_width = width
          end

        end

        # Implementation of the 'J' operator.
        module SetLineCap

          def self.call(processor, cap_style) #:nodoc:
            processor.graphics_state.line_cap_style = cap_style
          end

        end

        # Implementation of the 'j' operator.
        module SetLineJoin

          def self.call(processor, join_style) #:nodoc:
            processor.graphics_state.line_join_style = join_style
          end

        end

        # Implementation of the 'M' operator.
        module SetMiterLimit

          def self.call(processor, miter_limit) #:nodoc:
            processor.graphics_state.miter_limit = miter_limit
          end

        end

        # Implementation of the 'd' operator.
        module SetLineDashPattern

          def self.call(processor, dash_array, dash_phase) #:nodoc:
            processor.graphics_state.line_dash_pattern = LineDashPattern.new(dash_array, dash_phase)
          end

        end

        # Implementation of the 'ri' operator.
        module SetRenderingIntent

          def self.call(processor, intent) #:nodoc:
            processor.graphics_state.rendering_intent = intent
          end

        end

        # Implementation of the 'gs' operator.
        #
        # Note: Only parameters supported by the GraphicsState/TextState classes are assigned, the
        # rest are ignored!
        module SetGraphicsStateParameters

          def self.call(processor, name) #:nodoc:
            dict = processor.resources[:ExtGState]
            if !dict
              raise HexaPDF::Error, "No /ExtGState entry in the resource dictionary"
            elsif !(dict = dict[name])
              raise HexaPDF::Error, "No /#{name} entry in the /ExtGState dictionary"
            end

            ops = processor.operators
            ops[:w].call(processor, dict[:LW]) if dict.key?(:LW)
            ops[:J].call(processor, dict[:LC]) if dict.key?(:LC)
            ops[:j].call(processor, dict[:LJ]) if dict.key?(:LJ)
            ops[:M].call(processor, dict[:ML]) if dict.key?(:ML)
            ops[:d].call(processor, dict[:D]) if dict.key?(:D)
            ops[:ri].call(processor, dict[:RI]) if dict.key?(:RI)
            # TODO: dict[:Font] for font and font_size
            # TODO: dict[:SMask] works differently than operator!

            # No content operator exists for the following parameters
            gs = processor.graphics_state
            gs.stroke_adjustment = dict[:SA] if dict.key?(:SA)
            gs.blend_mode = dict[:BM] if dict.key?(:BM)
            gs.stroking_alpha = dict[:CA] if dict.key?(:CA)
            gs.non_stroking_alhpa = dict[:ca] if dict.key?(:ca)
            gs.alpha_source = dict[:AIS] if dict.key?(:AIS)
            gs.text_state.knockout = dict[:TK] if dict.key?(:TK)
          end

        end

        # Implementation of the 'CS' operator.
        module SetStrokingColorSpace

          def self.call(processor, name) #:nodoc:
            processor.graphics_state.stroking_color_space = processor.color_space(name)
          end

        end

        # Implementation of the 'cs' operator.
        module SetNonStrokingColorSpace

          def self.call(processor, name) #:nodoc:
            processor.graphics_state.non_stroking_color_space = processor.color_space(name)
          end

        end

        # Implementation of the 'SC' and 'SCN' operator.
        module SetStrokingColor

          def self.call(processor, *operands) #:nodoc:
            color_space = processor.graphics_state.stroking_color.color_space
            processor.graphics_state.stroking_color = color_space.color(*operands)
          end

        end

        # Implementation of the 'sc' and 'scn' operator.
        module SetNonStrokingColor

          def self.call(processor, *operands) #:nodoc:
            color_space = processor.graphics_state.non_stroking_color.color_space
            processor.graphics_state.non_stroking_color = color_space.color(*operands)
          end

        end

        # Implementation of the 'G' operator.
        module SetDeviceGrayStrokingColor

          def self.call(processor, gray) #:nodoc:
            processor.graphics_state.stroking_color = processor.color_space(:DeviceGray).color(gray)
          end

        end

        # Implementation of the 'g' operator.
        module SetDeviceGrayNonStrokingColor

          def self.call(processor, gray) #:nodoc:
            processor.graphics_state.non_stroking_color =
              processor.color_space(:DeviceGray).color(gray)
          end

        end

        # Implementation of the 'RG' operator.
        module SetDeviceRGBStrokingColor

          def self.call(processor, r, g, b) #:nodoc:
            processor.graphics_state.stroking_color =
              processor.color_space(:DeviceRGB).color(r, g, b)
          end

        end

        # Implementation of the 'rg' operator.
        module SetDeviceRGBNonStrokingColor

          def self.call(processor, r, g, b) #:nodoc:
            processor.graphics_state.non_stroking_color =
              processor.color_space(:DeviceRGB).color(r, g, b)
          end

        end

        # Implementation of the 'K' operator.
        module SetDeviceCMYKStrokingColor

          def self.call(processor, c, m, y, k) #:nodoc:
            processor.graphics_state.stroking_color =
              processor.color_space(:DeviceCMYK).color(c, m, y, k)
          end

        end

        # Implementation of the 'k' operator.
        module SetDeviceCMYKNonStrokingColor

          def self.call(processor, c, m, y, k) #:nodoc:
            processor.graphics_state.non_stroking_color =
              processor.color_space(:DeviceCMYK).color(c, m, y, k)
          end

        end

        # Implementation of the 'm' and 're' operators.
        module BeginPath

          def self.call(processor, *) #:nodoc:
            processor.graphics_object = :path
          end

        end

        # Implementation of the 'S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'b*' and 'n' operators.
        module EndPath

          def self.call(processor) #:nodoc:
            processor.graphics_object = :none
          end

        end

        # Implementation of the 'W' and 'w' operators.
        module ClipPath

          def self.call(processor) #:nodoc:
            processor.graphics_object = :clipping_path
          end

        end

      end

    end
  end
end
