# -*- encoding: utf-8 -*-

require 'openssl'
require 'hexapdf/error'
require 'hexapdf/encryption/aes'

module HexaPDF
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

      prepend AES

      # Uses OpenSSL to generate the requested random bytes.
      #
      # See AES::ClassMethods#random_bytes for more information.
      def self.random_bytes(n)
        OpenSSL::Random.random_bytes(n)
      end

      # Creates a new FastAES object using the given encryption key and initialization vector.
      #
      # The mode must either be :encrypt or :decrypt.
      def initialize(key, iv, mode)
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
