# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The main table of an sfnt-housed font file, providing the table directory which contains
        # information for loading all other tables.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6.html
        class Directory < Table

          # A single entry in the table directory.
          #
          # Accessors:
          #
          # tag::      The 4 byte name of the table as binary string.
          # checksum:: Checksum of the table.
          # offset::   Offset from the beginning of the file where the table can be found.
          # length::   The length of the table in bytes (without the padding).
          Entry = Struct.new(:tag, :checksum, :offset, :length)

          # The fixed entry that represents the table directory itself.
          SELF_ENTRY = Entry.new('DUMMY', 0, 0, 12)

          # The type of file housed by the snft wrapper as a binary string. Two possible values are
          # 'true' or 0x00010000 for a TrueType font and 'OTTO' for an OpenType font.
          attr_reader :tag

          # Returns the directory entry for the given tag or +nil+ if no such table exists.
          def entry(tag)
            @tables[tag]
          end

          private

          def load_from_io #:nodoc:
            with_io_pos(0) do
              @tag, num_tables = read_formatted(12, "a4n".freeze) # ignore 3 fields
              @tables = {}
              num_tables.times do
                entry = Entry.new(*read_formatted(16, "a4NNN".freeze))
                @tables[entry.tag] = entry
              end
            end
          end

          def load_default #:nodoc:
            @tag = 'true'.b
            @tables = {}
          end

        end

      end
    end
  end
end
