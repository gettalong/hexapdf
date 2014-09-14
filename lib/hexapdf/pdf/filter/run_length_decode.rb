# -*- encoding: utf-8 -*-

require 'fiber'
require 'strscan'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Filter

      # Implements the run length filter.
      #
      # See: HexaPDF::PDF::Filter, PDF1.7 s7.4.5
      module RunLengthDecode

        EOD = 128.chr #:nodoc:

        # See HexaPDF::PDF::Filter
        def self.decoder(source, _ = nil)
          Fiber.new do
            i, result = 0, ''
            data = source.resume
            while data && i < data.length
              length = data.getbyte(i)
              if length < 128 && i + length + 1 < data.length # no byte run and enough bytes
                result << data[i + 1, length + 1]
                i += length + 2
              elsif length > 128 && i + 1 < data.length # byte run and enough bytes
                result << data[i + 1] * (257 - length)
                i += 2
              elsif length != 128 # not enough bytes in data
                Fiber.yield(result)
                if source.alive? && (new_data = source.resume)
                  data = data[i..-1] << new_data
                else
                  raise MalformedPDFError, "Missing data for run length encoded stream"
                end
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

        # See HexaPDF::PDF::Filter
        def self.encoder(source, _ = nil)
          Fiber.new do
            while source.alive? && (data = source.resume)
              result = ''
              strscan = StringScanner.new(data)
              while !strscan.eos?
                if strscan.scan(/(.)\1{1,127}/m) # a run of <= 128 same characters
                  result << (257 - strscan.matched_size).chr << strscan[1]
                else # a run of characters until two same characters or length > 128
                  match = strscan.scan(/.{1,128}?(?=(.)\1|\z)|.{128}/m)
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
