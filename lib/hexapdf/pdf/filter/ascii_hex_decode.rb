# -*- encoding: utf-8 -*-

require 'fiber'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Filter

      # This filter module implements the ASCII hex decode/encode filter which can encode arbitrary
      # data into the two byte ASCII hex format that expands the original data by a factor of 1:2.
      #
      # See: HexaPDF::PDF::Filter, PDF1.7 s7.4.2
      module ASCIIHexDecode

        # See HexaPDF::PDF::Filter
        def self.decoder(source, _ = nil)
          Fiber.new do
            rest = nil
            finished = false

            while !finished && source.alive? && (data = source.resume)
              data.tr!(HexaPDF::PDF::Tokenizer::WHITESPACE, '')
              finished = true if data.gsub!(/>.*?\z/m, '')
              if data.index(/[^A-Fa-f0-9]/)
                raise HexaPDF::MalformedPDFError, "Invalid characters in ASCII hex encoded stream found"
              end

              data = rest << data if rest

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

        # See HexaPDF::PDF::Filter
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
