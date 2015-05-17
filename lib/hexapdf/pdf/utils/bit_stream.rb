# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF
    module Utils

      # Helper class for reading variable length integers from a bit stream.
      #
      # This class allows one to read integers with a variable width of up to 16 bit from a bit
      # stream using the #read method. The data from where these bits are read, can be set on
      # intialization and additional data can later be appended.
      class BitStreamReader

        # Creates a new object, optionally providing the string from where the bits should be read.
        def initialize(data = '')
          @data = data.force_encoding(Encoding::BINARY)
          @pos = 0
          @bit_cache = 0
          @available_bits = 0
        end

        # Appends some data to the string from where bits are read.
        def append_data(str)
          @data = @data[@pos, @data.length - @pos] << str
          @pos = 0
        end

        # Returns +true+ if +bits+ number of bits can be read.
        def read?(bits)
          fill_bit_cache
          @available_bits >= bits
        end

        # Reads +bits+ number of bits.
        #
        # Raises an exception if not enough bits are available for reading.
        def read(bits)
          fill_bit_cache
          raise HexaPDF::Error, "Not enough bits available for reading" if @available_bits < bits

          @available_bits -= bits
          result = @bit_cache >> @available_bits
          @bit_cache &= (1 << @available_bits) - 1

          result
        end

        private

        LENGTH_TO_TYPE = {4 => 'N', 2 => 'n', 1 => 'C'} # :nodoc:
        FOUR_TO_INFINITY = 4..Float::INFINITY # :nodoc:

        # Fills the bit cache so that at least 16bit are available (if possible).
        def fill_bit_cache
          return unless @available_bits <= 16 && @pos != @data.size

          l = case @data.size - @pos
              when FOUR_TO_INFINITY then 4
              when 2, 3 then 2
              else 1
              end
          @bit_cache = (@bit_cache << 8 * l) | @data[@pos, l].unpack(LENGTH_TO_TYPE[l]).first
          @pos += l
          @available_bits += 8 * l
        end

      end

      # Helper class for writing out variable length integers one after another as bit stream.
      #
      # This class allows one to write integers with a variable width of up to 16 bit to a bit
      # stream using the #write method. Every time when at least 16 bits are available, the #write
      # method returns those 16 bits as string and removes them from the internal cache.
      #
      # Once all data has been written, the #finalize method must be called to get the last
      # remaining bits (again as a string).
      class BitStreamWriter

        def initialize # :nodoc:
          @bit_cache = 0
          @available_bits = 0
        end

        # Writes the integer +int+ with a width of +bits+ to the bit stream.
        #
        # Returns a 16bit binary string if enough bits are available or an empty binary string
        # otherwise.
        def write(int, bits)
          @available_bits += bits
          @bit_cache |= int << (32 - @available_bits)
          if @available_bits >= 16
            @available_bits -= 16
            result = [@bit_cache >> 16].pack('n'.freeze)
            @bit_cache = (@bit_cache & 0xFFFF) << 16
            result
          else
            ''.force_encoding(Encoding::BINARY)
          end
        end

        # Retrieves the final (zero padded) bits as a string.
        def finalize
          result = [@bit_cache].pack('N')[0...(@available_bits / 8.0).ceil]
          initialize
          result
        end

      end

    end
  end
end
