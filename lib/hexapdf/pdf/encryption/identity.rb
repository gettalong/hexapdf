# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Encryption

      # The identity encryption/decryption algorithm.
      #
      # This "algorithm" does nothing, i.e. it returns the given data as is without encrypting or
      # decrypting it.
      #
      # See: PDF1.7 s7.6.5
      module Identity

        # Just returns the given +data+.
        def self.encrypt(key, data)
          data
        end

        # Just returns the given +data+.
        def self.decrypt(key, data)
          data
        end

      end

    end
  end
end
