# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Encryption

      autoload(:FastARC4, "hexapdf/pdf/encryption/fast_arc4")
      autoload(:RubyARC4, "hexapdf/pdf/encryption/ruby_arc4")
      autoload(:FastAES, "hexapdf/pdf/encryption/fast_aes")
      autoload(:RubyAES, "hexapdf/pdf/encryption/ruby_aes")

    end
  end
end
