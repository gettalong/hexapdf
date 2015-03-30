# -*- encoding: utf-8 -*-

require 'openssl'
require 'hexapdf/pdf/encryption/arc4'

module HexaPDF
  module PDF
    module Encryption

      # Implementation of the general encryption algorithm ARC4 using OpenSSL as backend.
      #
      # See: PDF1.7 s7.6.2
      class FastARC4

        prepend ARC4

        # Creates a new FastARC4 object using the given encryption key.
        def initialize(key)
          @cipher = OpenSSL::Cipher::RC4.new
          @cipher.key_len = key.length
          @cipher.key = key
        end

        # Processes the given data.
        #
        # Since this is a symmetric algorithm, the same method can be used for encryption and
        # decryption.
        def process(data)
          @cipher.update(data)
        end
        alias :decrypt :process
        alias :encrypt :process

      end

    end
  end
end
