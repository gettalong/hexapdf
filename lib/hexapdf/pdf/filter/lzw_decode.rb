# -*- encoding: utf-8 -*-

require 'fiber'
require 'hexapdf/pdf/utils/bit_stream'
require 'hexapdf/pdf/filter/predictor'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Filter

      # Implements the LZW filter.
      #
      # Since LZW uses a tightly packed bit stream in which codes are of varying bit lengths and are
      # not aligned to byte boundaries, this filter is not as fast as the other filters. If speed is
      # a concern, the FlateDecode filter should be used instead.
      #
      # See: HexaPDF::PDF::Filter, PDF1.7 s7.4.4
      module LZWDecode

        CLEAR_TABLE = 256 # :nodoc:
        EOD = 257 # :nodoc:

        INITIAL_ENCODER_TABLE = {} #:nodoc:
        0.upto(255) {|i| INITIAL_ENCODER_TABLE[i.chr] = i}
        INITIAL_ENCODER_TABLE[CLEAR_TABLE] = CLEAR_TABLE
        INITIAL_ENCODER_TABLE[EOD] = EOD

        INITIAL_DECODER_TABLE = {} #:nodoc:
        0.upto(255) {|i| INITIAL_DECODER_TABLE[i] = i.chr.force_encoding(Encoding::BINARY)}
        INITIAL_DECODER_TABLE[CLEAR_TABLE] = CLEAR_TABLE
        INITIAL_DECODER_TABLE[EOD] = EOD

        # See HexaPDF::PDF::Filter
        def self.decoder(source, options = nil)
          fib = Fiber.new do
            # initialize decoder state
            code_length = 9
            table = INITIAL_DECODER_TABLE.dup

            stream = HexaPDF::PDF::Utils::BitStreamReader.new
            result = ''.force_encoding(Encoding::BINARY)
            finished = false
            last_code = CLEAR_TABLE

            while !finished && source.alive? && (data = source.resume)
              stream.append_data(data)

              while stream.read?(code_length)
                code = stream.read(code_length)

                # Decoder is one step behind => subtract 1!
                # We check the table size before entering the next code into it => subtract 1, but
                # there is one exception: After table entry 4095 is written, the clear table code
                # also gets written with code length 12,
                case table.size
                when 510, 1022, 2046
                  code_length += 1
                when 4095
                  if code != CLEAR_TABLE
                    raise HexaPDF::MalformedPDFError, "Maximum of 12bit for codes in LZW stream exceeded"
                  end
                end

                if code == EOD
                  finished = true
                  break
                elsif code == CLEAR_TABLE
                  # reset decoder state
                  code_length = 9
                  table = INITIAL_DECODER_TABLE.dup
                elsif last_code == CLEAR_TABLE
                  unless table.key?(code)
                    raise HexaPDF::MalformedPDFError, "Unknown code in LZW encoded stream found"
                  end
                  result << table[code]
                else
                  unless table.key?(last_code)
                    raise HexaPDF::MalformedPDFError, "Unknown code in LZW encoded stream found"
                  end
                  last_str = table[last_code]

                  str = if table.key?(code)
                          table[code]
                        else
                          last_str + last_str[0]
                        end
                  result << str
                  table[table.size] = last_str + str[0]
                end

                last_code = code
              end

              Fiber.yield(result)
              result = ''.force_encoding(Encoding::BINARY)
            end
          end

          if options && options[:Predictor]
            Predictor.decoder(fib, options)
          else
            fib
          end
        end

        # See HexaPDF::PDF::Filter
        def self.encoder(source, options = nil)
          if options && options[:Predictor]
            source = Predictor.encoder(source, options)
          end

          Fiber.new do
            # initialize encoder state
            code_length = 9
            table = INITIAL_ENCODER_TABLE.dup

            # initialize the bit stream with the clear-table marker
            stream = HexaPDF::PDF::Utils::BitStreamWriter.new
            result = stream.write(CLEAR_TABLE, 9)
            str = ''.force_encoding(Encoding::BINARY)

            while source.alive? && (data = source.resume)
              data.each_char do |char|
                newstr = str + char
                if table.key?(newstr)
                  str = newstr
                else
                  result << stream.write(table[str], code_length)
                  table[newstr] = table.size
                  str = char
                end

                case table.size
                when 512 then code_length = 10
                when 1024 then code_length = 11
                when 2048 then code_length = 12
                when 4096
                  result << stream.write(CLEAR_TABLE, code_length)
                  # reset encoder state
                  code_length = 9
                  table = INITIAL_ENCODER_TABLE.dup
                end
              end

              Fiber.yield(result)
              result = ''.force_encoding(Encoding::BINARY)
            end

            result = stream.write(table[str], code_length)
            result << stream.write(EOD, code_length)
            result << stream.finalize

            result
          end
        end

      end

    end
  end
end
