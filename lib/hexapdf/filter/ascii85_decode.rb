# -*- encoding: utf-8 -*-

require 'fiber'
require 'strscan'
require 'hexapdf/tokenizer'
require 'hexapdf/error'

module HexaPDF
  module Filter

    # This filter module implements the ASCII-85 filter which can encode arbitrary data into an
    # ASCII compatible format that expands the original data only by a factor of 4:5.
    #
    # See: HexaPDF::Filter, PDF1.7 s7.4.2
    module ASCII85Decode

      VALUE_TO_CHAR = {} #:nodoc:
      (0..84).each do |i|
        VALUE_TO_CHAR[i] = (i + 33).chr
      end

      POW85_1 = 85    #:nodoc:
      POW85_2 = 85**2 #:nodoc:
      POW85_3 = 85**3 #:nodoc:
      POW85_4 = 85**4 #:nodoc:

      MAX_VALUE = 0xffffffff  #:nodoc:
      FIXED_SUBTRAHEND = 33 * (POW85_4 + POW85_3 + POW85_2 + POW85_1 + 1) #:nodoc:

      # See HexaPDF::Filter
      def self.decoder(source, _ = nil)
        Fiber.new do
          rest = nil
          finished = false

          while !finished && source.alive? && (data = source.resume)
            data.tr!(HexaPDF::Tokenizer::WHITESPACE, '')
            if data.index(/[^!-uz~]/)
              raise FilterError, "Invalid characters in ASCII85 stream"
            end

            if rest
              data = rest << data
              rest = nil
            end

            result = []
            scanner = StringScanner.new(data)
            until scanner.eos?
              if (m = scanner.scan(/[!-u]{5}/))
                num = (m.getbyte(0) * POW85_4 + m.getbyte(1) * POW85_3 +
                  m.getbyte(2) * POW85_2 + m.getbyte(3) * POW85_1 +
                  m.getbyte(4)) - FIXED_SUBTRAHEND
                if num > MAX_VALUE
                  raise FilterError, "Value outside range in ASCII85 stream"
                end
                result << num
              elsif scanner.scan(/z/)
                result << 0
              elsif scanner.scan(/([!-u]{0,4})~>/)
                rest = scanner[1] unless scanner[1].empty?
                finished = true
                break
              else
                rest = scanner.scan(/.+/)
              end
            end
            Fiber.yield(result.pack('N*')) unless result.empty?
          end

          if rest
            if rest.index('z') || rest.index('~')
              raise FilterError, "End of ASCII85 encoded stream is invalid"
            end

            rlen = rest.length
            rest << "u" * (5 - rlen)
            num = (rest.getbyte(0) * POW85_4 + rest.getbyte(1) * POW85_3 +
              rest.getbyte(2) * POW85_2 + rest.getbyte(3) * POW85_1 +
              rest.getbyte(4)) - FIXED_SUBTRAHEND
            if num > MAX_VALUE
              raise FilterError, "Value outside base-85 range in ASCII85 stream"
            end
            [num].pack('N')[0, rlen - 1]
          end
        end
      end

      # See HexaPDF::Filter
      def self.encoder(source, _ = nil)
        Fiber.new do
          rest = nil

          while source.alive? && (data = source.resume)
            data = rest << data if rest

            rlen = data.length % 4
            rest = (rlen != 0 ? data.slice!(-rlen, rlen) : nil)
            next if data.length < 4

            data = data.unpack('N*').inject(''.b) do |memo, num|
              memo << if num == 0
                        'z'
                      else
                        VALUE_TO_CHAR[num / POW85_4 % 85] + VALUE_TO_CHAR[num / POW85_3 % 85] <<
                          VALUE_TO_CHAR[num / POW85_2 % 85] << VALUE_TO_CHAR[num / POW85_1 % 85] <<
                          VALUE_TO_CHAR[num % 85]
                      end
            end

            Fiber.yield(data)
          end

          if rest
            rlen = rest.length
            num = (rest + "\0" * (4 - rlen)).unpack('N').first
            ((VALUE_TO_CHAR[num / POW85_4 % 85] + VALUE_TO_CHAR[num / POW85_3 % 85] <<
              VALUE_TO_CHAR[num / POW85_2 % 85] << VALUE_TO_CHAR[num / POW85_1 % 85] <<
              VALUE_TO_CHAR[num % 85])[0, rlen + 1] << "~>").force_encoding(Encoding::BINARY)
          else
            "~>".force_encoding(Encoding::BINARY)
          end
        end
      end

    end

  end
end
