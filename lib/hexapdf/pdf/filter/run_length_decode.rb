# -*- encoding: utf-8 -*-

require 'fiber'
require 'strscan'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.5
      module RunLengthDecode

        EOD = 128.chr

        def self.decoder(source, _ = nil)
          Fiber.new do
            i, result = 0, ''
            data = source.resume
            while data && i < data.length
              length = data.getbyte(i)
              if length < 128 && i + length + 1 < data.length # no byte run and enough bytes
                result << data[i+1, length + 1]
                i += length + 2
              elsif length > 128 && i + 1 < data.length # byte run and enough bytes
                result << data[i + 1] * (257 - length)
                i += 2
              elsif length != 128 # not enough bytes in data
                Fiber.yield(result)
                data = data[i..-1] << source.resume
                i, result = 0, ''
              else # EOD reached
                break
              end

              if i == data.length && source.alive? && data = source.resume
                Fiber.yield(result)
                i, result = 0, ''
              end
            end
            result unless result.empty?
          end
        end

        def self.encoder(source, _ = nil)
          Fiber.new do
            while source.alive? && data = source.resume
              result = ''
              strscan = StringScanner.new(data)
              while !strscan.eos?
                if strscan.scan(/(.)\1{1,127}/) # a run of <= 128 same characters
                  result << (257 - strscan.matched_size).chr << strscan[1]
                else # a run of characters until two same characters or length > 128
                  match = strscan.scan(/.{1,128}?(?=(.)\1|\z)/)
                  result << (match.length - 1).chr << match
                end
              end
              Fiber.yield(result)
            end
            EOD
          end
        end

      end

    end
  end
end
