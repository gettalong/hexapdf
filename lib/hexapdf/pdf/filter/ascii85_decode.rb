# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/tokenizer'
require 'fiber'
require 'strscan'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.2
      module ASCII85Decode

        VALUE_TO_CHAR = {}
        CHAR_TO_VALUE = {}
        (0..84).each do |i|
          VALUE_TO_CHAR[i] = (i + 33).chr
          CHAR_TO_VALUE[VALUE_TO_CHAR[i]] = i
        end

        POW85_1 = 85
        POW85_2 = 85**2
        POW85_3 = 85**3
        POW85_4 = 85**4
        MAX_VALUE = 0xffffffff

        def self.decoder(source, _ = nil)
          Fiber.new do
            rest = nil
            finished = false

            while !finished && source.alive? && data = source.resume
              data.tr!(HexaPDF::PDF::Tokenizer::WHITESPACE, '')
              raise "malformed pdf" if data.index(/[^!-uz~]/)

              if rest
                data = rest << data
                rest = nil
              end

              result = []
              scanner = StringScanner.new(data)
              while !scanner.eos?
                if m = scanner.scan(/[!-u]{5}/)
                  num = (CHAR_TO_VALUE[m[0]] * POW85_4 + CHAR_TO_VALUE[m[1]] * POW85_3 +
                         CHAR_TO_VALUE[m[2]] * POW85_2 + CHAR_TO_VALUE[m[3]] * POW85_1 +
                         CHAR_TO_VALUE[m[4]])
                  raise "malformed pdf" if num > MAX_VALUE
                  result << num
                elsif scanner.scan(/z/)
                  result << 0
                elsif scanner.scan(/([!-u]{0,4})~>/)
                  rest = scanner[1] unless scanner[1].empty?
                  finished = true
                  break
                else
                  rest = scanner.scan(/.+/)
                  raise "malformed pdf" if rest.index('z') || rest.length > 4
                end
              end
              Fiber.yield(result.pack('N*'))
            end

            if rest
              rlen = rest.length
              rest << "u"*(5-rlen)
              num = (CHAR_TO_VALUE[rest[0]] * POW85_4 + CHAR_TO_VALUE[rest[1]] * POW85_3 +
                     CHAR_TO_VALUE[rest[2]] * POW85_2 + CHAR_TO_VALUE[rest[3]] * POW85_1 +
                     CHAR_TO_VALUE[rest[4]])
              raise "malformed pdf" if num > MAX_VALUE
              [num].pack('N')[0,rlen-1]
            end
          end
        end

        def self.encoder(source, _ = nil)
          Fiber.new do
            rest = nil

            while source.alive? && data = source.resume
              data = rest << data if rest

              rlen = data.length % 4
              rest = (rlen != 0 ? data.slice!(-rlen, rlen) : nil)
              next if data.length < 4

              data = data.unpack('N*').map do |num|
                if num == 0
                  'z'
                else
                  VALUE_TO_CHAR[num / POW85_4 % 85] + VALUE_TO_CHAR[num / POW85_3 % 85] <<
                    VALUE_TO_CHAR[num / POW85_2 % 85] << VALUE_TO_CHAR[num / POW85_1 % 85] <<
                    VALUE_TO_CHAR[num % 85]
                end
              end.join("")

              Fiber.yield(data)
            end

            if rest
              rlen = rest.length
              num = (rest + "\0"*(4-rlen)).unpack('N').first
              (VALUE_TO_CHAR[num / POW85_4 % 85] + VALUE_TO_CHAR[num / POW85_3 % 85] <<
               VALUE_TO_CHAR[num / POW85_2 % 85] << VALUE_TO_CHAR[num / POW85_1 % 85] <<
               VALUE_TO_CHAR[num % 85])[0, rlen + 1] << "~>"
            else
              "~>"
            end
          end
        end

      end

    end
  end
end
