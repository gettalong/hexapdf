# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module Font
    module TrueType

      # Implementation of a generic table inside a sfnt-formatted font file.
      #
      # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6.html
      class Table

        autoload(:Directory, 'hexapdf/font/true_type/table/directory')
        autoload(:Head, 'hexapdf/font/true_type/table/head')
        autoload(:Cmap, 'hexapdf/font/true_type/table/cmap')
        autoload(:Hhea, 'hexapdf/font/true_type/table/hhea')
        autoload(:Hmtx, 'hexapdf/font/true_type/table/hmtx')
        autoload(:Loca, 'hexapdf/font/true_type/table/loca')
        autoload(:Maxp, 'hexapdf/font/true_type/table/maxp')
        autoload(:Name, 'hexapdf/font/true_type/table/name')
        autoload(:Post, 'hexapdf/font/true_type/table/post')
        autoload(:Glyf, 'hexapdf/font/true_type/table/glyf')
        autoload(:OS2,  'hexapdf/font/true_type/table/os2')


        # The time Epoch used in sfnt-formatted font files.
        TIME_EPOCH = Time.new(1904, 1, 1)

        # Calculates the checksum for the given data.
        def self.calculate_checksum(data)
          data.unpack('N*').inject(0) {|sum, long| sum + long} % 2**32
        end


        # The TrueType font object associated with this table.
        attr_reader :font

        # Creates a new Table object for the given font and initializes it by either reading the
        # data from the font's associated IO stream if +entry+ is given or by using default values.
        #
        # See: #parse_table, #load_default
        def initialize(font, entry = nil)
          @font = font
          @directory_entry = entry
          entry ? load_from_io : load_default
        end

        # Returns the directory entry for this table.
        #
        # See: Directory
        def directory_entry
          @directory_entry
        end

        # Returns +true+ if the checksum stored in the directory entry of the table matches the
        # tables data.
        def checksum_valid?
          unless directory_entry
            raise HexaPDF::Error, "Can't verify the checksum, no directory entry available"
          end

          data = with_io_pos(directory_entry.offset) { io.read(directory_entry.length) }
          directory_entry.checksum == self.class.calculate_checksum(data)
        end

        private

        # The IO stream of the associated font object.
        def io
          @font.io
        end

        # Loads the data for this table from the IO stream of the associated font object into this
        # object.
        #
        # See #parse_table for more information.
        def load_from_io
          with_io_pos(directory_entry.offset) { parse_table }
        end

        # Parses the table with the IO position already at the correct offset.
        #
        # This method does the actual work of parsing a table entry and must be implemented by
        # subclasses.
        #
        # See: #load_from_io
        def parse_table
          # noop for unsupported tables
        end

        # Uses default values to populate the table.
        #
        # This method must be implemented by subclasses.
        def load_default
          # noop for unsupported tables
        end

        # Sets the IO cursor to the given position while yielding to the block and returns the
        # block's return value.
        def with_io_pos(pos)
          old_pos = io.pos
          io.pos = pos
          yield
        ensure
          io.pos = old_pos
        end

        # Reads +count+ bytes from the current position of the font's associated IO stream, unpacks
        # them using the provided format specifier and returns the result.
        def read_formatted(count, format)
          io.read(count).unpack(format)
        end

        # Reads a 16.16-bit signed fixed-point integer and returns a Rational as result.
        def read_fixed
          Rational(io.read(4).unpack('N').first, 65536)
        end

      end

    end
  end
end
