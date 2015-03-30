# -*- encoding: utf-8 -*-

require 'securerandom'
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

          # Encrypts the given +data+ using the +key+ and a randomly generated initialization
          # vector.
          #
          # The data is padded using the PKCS#5 padding scheme and the initialization vector is
          # prepended to the encrypted data,
          #
          # See: PDF1.7 s7.6.2.
          def encrypt(key, data)
            iv = random_bytes(BLOCK_SIZE)
            padding_length = BLOCK_SIZE - data.size % BLOCK_SIZE
            data << padding_length.chr * padding_length
            iv << new(key, iv, :encrypt).process(data)
          end

          # Decrypts the given +data+ using the +key+.
          #
          # It is assumed that the initialization vector is included in the first BLOCK_SIZE bytes
          # of the data. After the decryption the PKCS#5 padding is removed.
          #
          # See: PDF1.7 s7.6.2.
          def decrypt(key, data)
            if data.length % 16 != 0 || data.length < 32
              raise HexaPDF::Error, "Invalid data for decryption, need 32 + 16*n bytes"
            end
            result = new(key, data.slice!(0, BLOCK_SIZE), :decrypt).process(data)
            padding_length = result.getbyte(-1)
            if padding_length > 16 || padding_length == 0
              raise HexaPDF::Error, "Invalid AES padding length #{padding_length}"
            end
            result.slice!(-padding_length, padding_length)
            result
          end

          # Returns a string of n random bytes.
          #
          # The specific AES algorithm class can override this class method to provide another
          # method for generating random bytes.
          def random_bytes(n)
            SecureRandom.random_bytes(n)
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
