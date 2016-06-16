# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'glyf' table contains the instructions for rendering glyphs and some additional glyph
        # information.
        #
        # This is probably always the largest table in a TrueType font, so care is taken to perform
        # operations lazily.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6glyf.html
        class Glyf < Table

          # Represents the definition of a glyph. Since the purpose of this implementation is not
          # editing or rendering glyphs, the raw glyph data is only decoded so far as to get general
          # information about the glyph.
          class Glyph

            # Contains the raw byte data of the glyph.
            attr_reader :raw_data

            # The number of contours in the glyph. A zero or positive number implies a simple glyph,
            # a negative number a glyph made up from multiple components
            attr_reader :number_of_contours

            # The minimum x value for coordinate data.
            attr_reader :x_min

            # The minimum y value for coordinate data.
            attr_reader :y_min

            # The maximum x value for coordinate data.
            attr_reader :x_max

            # The maximum y value for coordinate data.
            attr_reader :y_max

            # The array with the component glyph IDs, or +nil+ if this is not a compound glyph.
            attr_reader :components

            # Creates a new glyph from the given raw data.
            def initialize(raw_data)
              @raw_data = raw_data
              @number_of_contours, @x_min, @y_min, @x_max, @y_max = @raw_data.unpack('s>5')
              @number_of_contours ||= 0
              @components = nil
              parse_compound_glyph if compound?
            end

            # Returns +true+ if this a compound glyph.
            def compound?
              number_of_contours < 0
            end

            private

            FLAG_ARG_1_AND_2_ARE_WORDS =    1 << 0 #:nodoc:
            FLAG_MORE_COMPONENTS =          1 << 5 #:nodoc:
            FLAG_WE_HAVE_A_SCALE =          1 << 3 #:nodoc:
            FLAG_WE_HAVE_AN_X_AND_Y_SCALE = 1 << 6 #:nodoc:
            FLAG_WE_HAVE_A_TWO_BY_TWO =     1 << 7 #:nodoc:

            # Parses the raw data to get the component glyphs.
            #
            # This is needed because the component glyphs are referenced by their glyph IDs and
            # those may change when subsetting the font.
            def parse_compound_glyph
              @components = []
              @component_offsets = []
              index = 10
              while true
                flags, glyph_id = raw_data[index, 4].unpack('n2')
                @components << glyph_id
                @component_offsets << index
                break if flags & FLAG_MORE_COMPONENTS == 0

                index += 4 # fields flags and glyphIndex
                index += (flags & FLAG_ARG_1_AND_2_ARE_WORDS == 0 ? 2 : 4) # arguments
                if flags & FLAG_WE_HAVE_A_TWO_BY_TWO != 0 # transformation
                  index += 8
                elsif flags & FLAG_WE_HAVE_AN_X_AND_Y_SCALE != 0
                  index += 4
                elsif flags & FLAG_WE_HAVE_A_SCALE != 0
                  index += 2
                end
              end
            end

          end

          # The mapping from glyph ID to Glyph object or +nil+ (if the glyph has no outline).
          attr_accessor :glyphs

          # Returns the Glyph object for the given glyph ID, or +nil+ if it has no outline (e.g. the
          # space character).
          def [](glyph_id)
            if @glyphs.key?(glyph_id)
              return @glyphs[glyph_id]
            elsif !directory_entry
              return nil
            end

            offset = font[:loca].offset(glyph_id)
            length = font[:loca].length(glyph_id)

            if length == 0
              @glyphs[glyph_id] = Glyph.new('')
            else
              raw_data = with_io_pos(directory_entry.offset + offset) { io.read(length) }
              @glyphs[glyph_id] = Glyph.new(raw_data)
            end
          end

          private

          # Nothing to parse here since we lazily parse glyphs.
          def parse_table
            @glyphs = {}
          end

          def load_default #:nodoc:
            @glyphs = {}
          end

        end

      end
    end
  end
end
