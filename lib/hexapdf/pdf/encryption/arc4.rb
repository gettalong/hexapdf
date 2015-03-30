# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Encryption

      # Common interface for ARC4 algorithms
      #
      # This module defines the common interface that is used by the security handlers to encrypt or
      # decrypt data with ARC4. It has to be **prepended** by any ARC4 algorithm class.
      module ARC4

        # Convenience methods for decryption and encryption.
        #
        # These methods will be available on the class object that prepends the ARC4 module.
        module ClassMethods

          # Encrypts the given +data+ with the +key+.
          #
          # See: PDF1.7 s7.6.2.
          def encrypt(key, data)
            new(key).encrypt(data)
          end

          # Decrypts the given +data+ with the +key+.
          #
          # See: PDF1.7 s7.6.2.
          def decrypt(key, data)
            new(key).decrypt(data)
          end

        end

        # Automatically extends the klass with the necessary class level methods.
        def self.prepended(klass) # :nodoc:
          klass.extend(ClassMethods)
        end

      end

    end
  end
end
