# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Filter

      # This filter module allows access to the standard encryption and decryption routines
      # implemented by the SecurityHandler using the standard Filter interface.
      #
      # The +options+ hash for ::decoder and ::encoder must contain two keys: :key (the
      # encryption/decryption key) and :algorithm (the class used for encrypting/decrypting).
      #
      # This module must not be confused with the Crypt filter specified in the PDF specification!
      module Encryption

        # See HexaPDF::PDF::Filter
        def self.decoder(source, options)
          options[:algorithm].decryption_fiber(options[:key], source)
        end

        # See HexaPDF::PDF::Filter
        def self.encoder(source, options)
          options[:algorithm].encryption_fiber(options[:key], source)
        end

      end

    end
  end
end
