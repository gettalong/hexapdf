# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'loca' (location) table contains the offsets of the glyphs relative to the start of
        # the 'glyf' table.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6loca.html
        class Loca < Table

          # The array containing the byte offsets for each glyph relative to the start of the 'glyf'
          # table.
          attr_accessor :offsets

          # Returns the byte offset for the given glyph ID relative to the start of the 'glyf'
          # table.
          def offset(glyph_id)
            @offsets[glyph_id]
          end

          # Returns the length of the 'glyf' entry for the given glyph ID.
          def length(glyph_id)
            @offsets[glyph_id + 1] - @offsets[glyph_id]
          end

          private

          def parse_table #:nodoc:
            entry_size = font[:head].index_to_loc_format
            @offsets = read_formatted(directory_entry.length, (entry_size == 0 ? 'n*' : 'N*'))
            @offsets.map! {|offset| offset * 2} if entry_size == 0
          end

          def load_default #:nodoc:
            @offsets = []
          end

        end

      end
    end
  end
end
