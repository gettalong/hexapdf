# -*- encoding: utf-8 -*-

module HexaPDF
  module Font
    module Type1

      # Represents the character metrics for an individual character.
      class CharacterMetrics

        # Decimal value of the default character code (-1 if not encoded).
        attr_accessor :code

        # Character width in x-direction (y-direction is implicitly 0).
        attr_accessor :width

        # PostScript language character name.
        attr_accessor :name

        # Character bounding box as array of four numbers, specifying the x- and y-coordinates of
        # the lower-left corner and the x- and y-coordinates of the upper-right corner.
        attr_accessor :bbox

        # Mapping of possible ligatures. This character combined with the character specified by a
        # key forms the ligature character stored as value of that key. Both keys and values are
        # character names.
        attr_accessor :ligatures

        def initialize #:nodoc:
          @ligatures = {}
        end

      end

    end
  end
end
