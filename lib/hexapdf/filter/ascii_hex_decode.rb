# -*- encoding: utf-8 -*-

require 'fiber'
require 'hexapdf/tokenizer'
require 'hexapdf/error'

module HexaPDF
  module Filter

    # This filter module implements the ASCII hex decode/encode filter which can encode arbitrary
    # data into the two byte ASCII hex format that expands the original data by a factor of 1:2.
    #
    # See: HexaPDF::Filter, PDF1.7 s7.4.2
    module ASCIIHexDecode

      # See HexaPDF::Filter
      def self.decoder(source, _ = nil)
        Fiber.new do
          rest = nil
          finished = false

          while !finished && source.alive? && (data = source.resume)
            data.tr!(HexaPDF::Tokenizer::WHITESPACE, '')
            finished = true if data.gsub!(/>.*?\z/m, '')
            if data.index(/[^A-Fa-f0-9]/)
              raise HexaPDF::MalformedPDFError, "Invalid characters in ASCII hex stream"
            end

            data = rest << data if rest

            if data.size.odd?
              rest = data.slice!(-1, 1)
            else
              rest = nil
            end

            Fiber.yield([data].pack('H*'))
          end
          [rest].pack('H*') if rest
        end
      end

      # See HexaPDF::Filter
      def self.encoder(source, _ = nil)
        Fiber.new do
          while source.alive? && (data = source.resume)
            Fiber.yield(data.unpack('H*').first.force_encoding(Encoding::BINARY))
          end
          '>'.force_encoding(Encoding::BINARY)
        end
      end

    end

  end
end
