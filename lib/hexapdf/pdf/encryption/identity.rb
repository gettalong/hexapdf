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

        class << self

          # Just returns the given +data+.
          def encrypt(key, data)
            data
          end
          alias :decrypt :encrypt

          # Just returns the given +source+ fiber.
          def encryption_fiber(key, source)
            source
          end
          alias :decryption_fiber :encryption_fiber
        end

      end

    end
  end
end
