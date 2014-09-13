# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/tokenizer'
require 'fiber'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.2
      module ASCIIHexDecode

        def self.decoder(source, _ = nil)
          Fiber.new do
            rest = nil
            finished = false

            while !finished && source.alive? && (data = source.resume)
              data.tr!(HexaPDF::PDF::Tokenizer::WHITESPACE, '')
              raise "malformed pdf" if data.index(/[^A-Fa-f0-9>]/)

              data = rest << data if rest
              finished = true if data.gsub!(/>.*?\z/m, '')

              if data.bytesize.odd?
                rest = data.slice!(-1, 1)
              else
                rest = nil
              end

              Fiber.yield([data].pack('H*'))
            end
            [rest].pack('H*') if rest
          end
        end

        def self.encoder(source, _ = nil)
          Fiber.new do
            while source.alive? && (data = source.resume)
              Fiber.yield(data.unpack('H*').first)
            end
            '>'
          end
        end

      end

    end
  end
end
