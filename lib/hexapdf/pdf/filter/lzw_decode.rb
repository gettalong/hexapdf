# -*- encoding: utf-8 -*-

require 'fiber'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.4
      module LZWDecode

        CLEAR_TABLE = 256
        EOD = 257

        INITIAL_ENCODER_TABLE = {}
        0.upto(255) {|i| INITIAL_ENCODER_TABLE[i.chr] = i}
        INITIAL_ENCODER_TABLE[CLEAR_TABLE] = CLEAR_TABLE
        INITIAL_ENCODER_TABLE[EOD] = EOD

        INITIAL_DECODER_TABLE = {}
        0.upto(255) {|i| INITIAL_DECODER_TABLE[i] = i.chr}
        INITIAL_DECODER_TABLE[CLEAR_TABLE] = CLEAR_TABLE
        INITIAL_DECODER_TABLE[EOD] = EOD

        #TODO: implement predictor for lzw/flate

        def self.decoder(source, options = nil)
          Fiber.new do
            # initialize decoder state
            code_length = 9
            table = INITIAL_DECODER_TABLE.dup
            next_code_length_jump = 512

            stream = BitStreamReader.new
            result = ''.force_encoding('BINARY')
            finished = false
            last_code = CLEAR_TABLE

            while !finished && source.alive? && data = source.resume
              stream.append_data(data)

              while stream.read?(code_length)
                code = stream.read(code_length)

                if code == EOD
                  finished = true
                  break
                elsif code == CLEAR_TABLE
                  # reset decoder state
                  code_length = 9
                  table = INITIAL_DECODER_TABLE.dup
                  next_code_length_jump = 512
                elsif last_code == CLEAR_TABLE
                  raise "Unknown code found" unless table.has_key?(code)
                  result << table[code]
                else
                  raise "Unknown code found" unless table.has_key?(last_code)
                  last_str = table[last_code]

                  str = if table.has_key?(code)
                          table[code]
                        else
                          last_str + last_str[0]
                        end
                  result << str
                  table[table.size] = last_str + str[0]
                end

                if table.size >= next_code_length_jump - 1 # decoder is one step behind => - 1 !
                  code_length += 1
                  if code_length > 12
                    raise "Maximum of 12bit for codes exceeded"
                  else
                    next_code_length_jump <<= 1
                  end
                end

                last_code = code
              end

              Fiber.yield(result)
              result = ''.force_encoding('BINARY')
            end

          end
        end

        def self.encoder(source, options = nil)
          Fiber.new do
            # initialize encoder state
            code_length = 9
            table = INITIAL_ENCODER_TABLE.dup
            next_code_length_jump = 512

            # initialize the bit stream with the clear-table marker
            stream = BitStreamWriter.new
            result = stream.write(CLEAR_TABLE, 9)
            str = ''.force_encoding('BINARY')

            while source.alive? && data = source.resume
              data.each_char do |char|
                newstr = str + char
                if table.has_key?(newstr)
                  str = newstr
                else
                  result << stream.write(table[str], code_length)
                  table[newstr] = table.size
                  str = char
                end

                if table.size == next_code_length_jump
                  if table.size == 4096
                    result << stream.write(CLEAR_TABLE, code_length)
                    # reset encoder state
                    code_length = 9
                    table = INITIAL_ENCODER_TABLE.dup
                    next_code_length_jump = 512
                  else
                    code_length += 1
                    next_code_length_jump <<= 1
                  end
                end
              end

              Fiber.yield(result)
              result = ''.force_encoding('BINARY')
            end

            result = stream.write(table[str], code_length)
            result << stream.write(EOD, code_length)
            result << stream.finalize

            result
          end
        end


        # Helper class for reading variable length integers from a bit stream.
        #
        # This class allows one to read integers with a variable width of up to 16 bit from a bit
        # stream using the #read method. The data from where these bits are read, can be set on
        # intialization and additional data can later be appended.
        class BitStreamReader

          # Create a new object, optionally providing the string from where the bits should be read.
          def initialize(data = '')
            @data = data.force_encoding('BINARY')
            @pos = 0
            @bit_cache = 0
            @available_bits = 0
          end

          # Append some data to the string from where bits are read.
          def append_data(str)
            @data = @data[@pos, @data.length - @pos] << str
            @data.force_encoding('BINARY')
            @pos = 0
          end

          # Return +true+ if +bits+ number of bits can be read.
          def read?(bits)
            fill_bit_cache
            @available_bits >= bits
          end

          # Read +bits+ number of bits.
          #
          # Raises an exception if not enough bits are available for reading.
          def read(bits)
            fill_bit_cache
            raise "Not enough bits available for reading" if @available_bits < bits

            @available_bits -= bits
            result = @bit_cache >> @available_bits
            @bit_cache &= (1 << @available_bits) - 1

            result
          end

          private

          LENGTH_TO_TYPE = {4 => 'N', 2 => 'n', 1 => 'C'} # :nodoc:
          FOUR_TO_INFINITY = 4..Float::INFINITY # :nodoc:

          # Fill the bit cache so that at least 16bit are available (if possible).
          def fill_bit_cache
            if @pos != @data.size && @available_bits <= 16
              l = case @data.size - @pos
                  when FOUR_TO_INFINITY then 4
                  when 2, 3 then 2
                  else 1
                  end
              @bit_cache = (@bit_cache << 8*l ) | @data[@pos, l].unpack(LENGTH_TO_TYPE[l]).first
              @pos += l
              @available_bits += 8*l
            end
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

          # Write the integer +int+ with a width of +bits+ to the bit stream.
          #
          # Returns a 16bit string if enough bits are available or an empty string otherwise.
          def write(int, bits)
            @available_bits += bits
            @bit_cache |= int << (32 - @available_bits)
            if @available_bits >= 16
              @available_bits -= 16
              result = [@bit_cache >> 16].pack('n')
              @bit_cache = (@bit_cache & 0xFFFF) << 16
              result
            else
              ''
            end
          end

          # Retrieve the final (zero padded) bits as a string.
          def finalize
            result = [@bit_cache].pack('N')[0...(@available_bits / 8.0).ceil]
            initialize
            result
          end

        end

      end

    end
  end
end
