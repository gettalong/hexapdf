# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/fast_aes'

describe HexaPDF::PDF::Encryption::FastAES do

  include CommonAESEncryptionTests

  before do
    @algorithm_klass = HexaPDF::PDF::Encryption::FastAES
  end

end
