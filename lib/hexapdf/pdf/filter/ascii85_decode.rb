# -*- encoding: utf-8 -*-

require 'fiber'
require 'strscan'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Filter

      # This filter module implements the ASCII-85 filter which can encode arbitrary data into an
      # ASCII compatible format that expands the original data only by a factor of 4:5.
      #
      # See: HexaPDF::PDF::Filter, PDF1.7 s7.4.2
      module ASCII85Decode

        VALUE_TO_CHAR = {} #:nodoc:
        CHAR_TO_VALUE = {} #:nodoc:
        (0..84).each do |i|
          VALUE_TO_CHAR[i] = (i + 33).chr
          CHAR_TO_VALUE[VALUE_TO_CHAR[i]] = i
        end

        POW85_1 = 85    #:nodoc:
        POW85_2 = 85**2 #:nodoc:
        POW85_3 = 85**3 #:nodoc:
        POW85_4 = 85**4 #:nodoc:
        MAX_VALUE = 0xffffffff  #:nodoc:

        # See HexaPDF::PDF::Filter
        def self.decoder(source, _ = nil)
          Fiber.new do
            rest = nil
            finished = false

            while !finished && source.alive? && (data = source.resume)
              data.tr!(HexaPDF::PDF::Tokenizer::WHITESPACE, '')
              if data.index(/[^!-uz~]/)
                raise HexaPDF::MalformedPDFError, "Invalid characters in ASCII85 stream"
              end

              if rest
                data = rest << data
                rest = nil
              end

              result = []
              scanner = StringScanner.new(data)
              until scanner.eos?
                if (m = scanner.scan(/[!-u]{5}/))
                  num = (CHAR_TO_VALUE[m[0]] * POW85_4 + CHAR_TO_VALUE[m[1]] * POW85_3 +
                         CHAR_TO_VALUE[m[2]] * POW85_2 + CHAR_TO_VALUE[m[3]] * POW85_1 +
                         CHAR_TO_VALUE[m[4]])
                  if num > MAX_VALUE
                    raise HexaPDF::MalformedPDFError, "Value outside base-85 range in ASCII85 stream"
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
                raise HexaPDF::MalformedPDFError, "End of ASCII85 encoded stream is invalid"
              end

              rlen = rest.length
              rest << "u" * (5 - rlen)
              num = (CHAR_TO_VALUE[rest[0]] * POW85_4 + CHAR_TO_VALUE[rest[1]] * POW85_3 +
                     CHAR_TO_VALUE[rest[2]] * POW85_2 + CHAR_TO_VALUE[rest[3]] * POW85_1 +
                     CHAR_TO_VALUE[rest[4]])
              if num > MAX_VALUE
                raise HexaPDF::MalformedPDFError, "Value outside base-85 range in ASCII85 stream"
              end
              [num].pack('N')[0, rlen - 1]
            end
          end
        end

        # See HexaPDF::PDF::Filter
        def self.encoder(source, _ = nil)
          Fiber.new do
            rest = nil

            while source.alive? && (data = source.resume)
              data = rest << data if rest

              rlen = data.length % 4
              rest = (rlen != 0 ? data.slice!(-rlen, rlen) : nil)
              next if data.length < 4

              data = data.unpack('N*').inject(''.force_encoding(Encoding::BINARY)) do |memo, num|
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
end
