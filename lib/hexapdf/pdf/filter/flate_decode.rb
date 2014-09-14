# -*- encoding: utf-8 -*-

require 'fiber'
require 'zlib'
require 'hexapdf/pdf/filter/predictor'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Filter

      # Implements the Deflate filter using the Zlib library.
      #
      # See: HexaPDF::PDF::Filter, PDF1.7 s7.4.4
      module FlateDecode

        # See HexaPDF::PDF::Filter
        def self.decoder(source, options = nil)
          fib = Fiber.new do
            inflater = Zlib::Inflate.new
            while source.alive? && (data = source.resume)
              begin
                data = inflater.inflate(data)
              rescue
                raise HexaPDF::Error, $!
              end
              Fiber.yield(data)
            end
            inflater.finish
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
          fib = Fiber.new do
            deflater = Zlib::Deflate.new(Zlib::BEST_COMPRESSION)
            while source.alive? && (data = source.resume)
              begin
                data = deflater.deflate(data)
              rescue
                raise HexaPDF::Error, $!
              end
              Fiber.yield(data)
            end
            deflater.finish
          end
        end

      end

    end
  end
end
