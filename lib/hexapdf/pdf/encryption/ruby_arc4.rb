# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/encryption/arc4'

module HexaPDF
  module PDF
    module Encryption

      # Pure Ruby implementation of the general encryption algorithm ARC4.
      #
      # Since this algorithm is implemented in pure Ruby, it is not very fast. Therefore the
      # FastARC4 class based on OpenSSL should be used when possible.
      #
      # For reference: This implementation is about 250 times slower than the FastARC4 version.
      #
      # See: PDF1.7 s7.6.2
      class RubyARC4

        prepend ARC4

        # Creates a new ARC4 object using the given encryption key.
        def initialize(key)
          initialize_state(key)
          @i = @j = 0
        end

        # Processes the given data.
        #
        # Since this is a symmetric algorithm, the same method can be used for encryption and
        # decryption.
        def process(data)
          result = data.dup.force_encoding(Encoding::BINARY)
          di = 0
          while di < result.length
            @i = (@i + 1) % 256
            @j = (@j + @state[@i]) % 256
            @state[@i], @state[@j] = @state[@j], @state[@i]
            result.setbyte(di, result.getbyte(di) ^ @state[(@state[@i] + @state[@j]) % 256])
            di += 1
          end
          result
        end
        alias :decrypt :process
        alias :encrypt :process

        private

        # The initial state which is then modified by the key-scheduling algorithm
        INITIAL_STATE = (0..255).to_a

        # Performs the key-scheduling algorithm to initialize the state.
        def initialize_state(key)
          i = j = 0
          @state = INITIAL_STATE.dup
          key_length = key.length
          while i < 256
            j = (j + @state[i] + key.getbyte(i % key_length)) % 256
            @state[i], @state[j] = @state[j], @state[i]
            i += 1
          end
        end

      end

    end
  end
end
