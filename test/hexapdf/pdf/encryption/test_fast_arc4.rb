# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/fast_arc4'

describe HexaPDF::PDF::Encryption::FastARC4 do

  include CommonARC4EncryptionTests

  before do
    @algorithm_klass = HexaPDF::PDF::Encryption::FastARC4
  end

end
