# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Content

      # Defines all available text rendering modes as constants. For use with
      # TextState#rendering_mode.
      #
      # See: PDF1.7 s9.3.6
      module TextRenderingMode

        # Fill text
        FILL = 0

        # Stroke text
        STROKE = 1

        # Fill, then stroke text
        FILL_STROKE = 2

        # Neither fill nor stroke text (invisible)
        INVISIBLE = 3

        # Fill text and add to path for clipping
        FILL_CLIP = 4

        # Stroke text and add to path for clipping
        STROKE_CLIP = 5

        # Fill, then stroke text and add to path for clipping
        FILL_STROKE_CLIP = 6

        # Add text to path for clipping
        CLIP = 7

      end


      # The TextState is part of the GraphicsState and contains all parameters that only affect
      # text.
      #
      # See: PDF1.7 s9.3.1, GraphicsState
      class TextState

        # The character spacing in unscaled text units.
        #
        # It specifies the additional spacing used for the horizontal or vertical displacement of
        # glyphs.
        attr_accessor :character_spacing

        # The word spacing in unscaled text units.
        #
        # It works like the character spacing but is only applied to the ASCII space character.
        attr_accessor :word_spacing

        # The horizontal text scaling.
        #
        # It is a value between 0 and 100 specifying the percentage of the normal width that should
        # be used.
        attr_accessor :horizontal_scaling

        # The leading in unscaled text units.
        #
        # It specifies the distance between the baselines of adjacent lines of text.
        attr_accessor :leading

        # The font for the text.
        attr_accessor :font

        # The font size.
        attr_accessor :font_size

        # The text rendering mode.
        #
        # It determines if and how the glyphs of a text should be shown (for all available values
        # see TextRenderingMode).
        attr_accessor :rendering_mode

        # The text rise distance in unscaled text units.
        #
        # It specifies the distance that the baseline should be moved up or down from its default
        # location.
        attr_accessor :rise

        # The text knockout, a boolean value.
        #
        # It specifies whether each glyph should be treated as separate elementary object for the
        # purpose of color compositing in the transparent imaging model (knockout = +false+) or if
        # all glyphs together are treated as one elementary object (knockout = +true+).
        attr_accessor :knockout

        # Initializes the text state parameters to their default values.
        def initialize
          @character_spacing = 0
          @word_spacing = 0
          @horizontal_scaling = 100
          @leading = 0
          @font = nil
          @font_size = nil
          @rendering_mode = TextRenderingMode::FILL
          @rise = 0
          @knockout = true
        end

      end

    end
  end
end
