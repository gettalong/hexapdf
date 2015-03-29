# -*- encoding: utf-8 -*-

require 'openssl'
require 'hexapdf/error'

module HexaPDF
  module PDF
    module Encryption

      # Common interface for AES algorithms
      #
      # This module defines the common interface that is used by the security handlers to encrypt or
      # decrypt data with AES. It has to be **prepended** by any AES algorithm class.
      module AES

        # Valid AES key lengths
        VALID_KEY_LENGTH = [16, 24, 32]

        # The AES block size
        BLOCK_SIZE = 16

        # Convenience methods for decryption and encryption.
        #
        # These methods will be available on the class object that prepends the AES module.
        module ClassMethods

          # Encrypts the given +data+ using the +key+ and the initialization vector +iv+.
          def encrypt(key, iv, data)
            new(key, iv, :encrypt).process(data)
          end

          # Decrypts the given +data+ using the +key+ and the initialization vector +iv+.
          def decrypt(key, iv, data)
            new(key, iv, :decrypt).process(data)
          end

        end

        # Automatically extends the klass with the necessary class level methods.
        def self.prepended(klass) # :nodoc:
          klass.extend(ClassMethods)
        end

        # Creates a new AES object using the given encryption key and initialization vector.
        #
        # The mode must either be :encrypt or :decrypt.
        #
        # Classes prepending this module have to have their own initialization method as this method
        # just performs basic checks.
        def initialize(key, iv, mode)
          unless VALID_KEY_LENGTH.include?(key.length)
            raise HexaPDF::Error, "AES key length must be 128, 192 or 256 bit"
          end
          unless iv.length == BLOCK_SIZE
            raise HexaPDF::Error, "AES initialization vector length must be 128 bit"
          end
          mode = mode.intern
          super
        end

      end

    end
  end
end
