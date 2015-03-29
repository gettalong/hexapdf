# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/fast_aes'
require_relative 'test_aes'

describe HexaPDF::PDF::Encryption::FastAES do

  include AESEncryptionTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::FastAES
  end

end
