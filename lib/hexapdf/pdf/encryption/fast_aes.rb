# -*- encoding: utf-8 -*-

require 'openssl'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Encryption

      # Implementation of the general encryption algorithm AES using OpenSSL as backend.
      #
      # Since OpenSSL is a native Ruby extension (that comes bundled with Ruby) it is much faster
      # than the pure Ruby version and it can use the AES-NI instruction set on CPUs when available.
      #
      # This implementation is using AES in Cipher Block Chaining (CBC) mode.
      #
      # See: PDF1.7 s7.6.2
      class FastAES

        VALID_KEY_LENGTH = [16, 24, 32] #:nodoc:

        # Creates a new FastAES object using the given encryption key and initialization vector.
        #
        # The mode must either be :encrypt or :decrypt.
        def initialize(key, iv, mode)
          unless VALID_KEY_LENGTH.include?(key.length)
            raise HexaPDF::Error, "AES key length must be 128, 192 or 256 bit"
          end
          unless iv.length == 16
            raise HexaPDF::Error, "AES initialization vector length must be 128 bit"
          end
          @cipher = OpenSSL::Cipher.new("AES-#{key.length << 3}-CBC")
          @cipher.send(mode)
          @cipher.key = key
          @cipher.iv = iv
          @cipher.padding = 0
        end

        # Encrypts or decrypts the given data whose length must be a multiple of 16.
        def process(data)
          @cipher.update(data)
        end

      end

    end
  end
end
