# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'
require 'hexapdf/font/ttf/table/cmap_subtable'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'cmap' table contains subtables for mapping character codes to glyph indices.
        #
        # See:
        # * CmapSubtable
        # * https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
        class Cmap < Table

          # The version of the cmap table.
          attr_accessor :version

          # The available cmap subtables.
          attr_accessor :tables

          # Returns the preferred of the available cmap subtables.
          #
          # A preferred table is always a table mapping Unicode characters.
          def preferred_table
            tables.select(&:unicode?).sort {|a, b| a.format <=> b.format}.last
          end

          private

          def parse_table #:nodoc:
            @version, num_tables  = read_formatted(4, 'n2')
            @tables = []
            handle_unknown = font.config['font.ttf.cmap.unknown_format']

            num_tables.times { @tables << read_formatted(8, 'n2N') }
            offset_map = {}
            @tables.map! do |platform_id, encoding_id, offset|
              offset += directory_entry.offset
              if offset_map.key?(offset)
                subtable = offset_map[offset].dup
                subtable.platform_id = platform_id
                subtable.encoding_id = encoding_id
                next subtable
              end

              subtable = CmapSubtable.new(platform_id, encoding_id)
              supported = subtable.parse(io, offset)
              if supported
                offset_map[offset] = subtable
                subtable
              elsif handle_unknown == :raise
                raise HexaPDF::Error, "Unknown cmap subtable format #{subtable.format}"
              else
                nil
              end
            end.compact!
          end

          def load_default #:nodoc:
            @version = 0
            @tables = []
          end

        end

      end
    end
  end
end
