# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/fast_arc4'
require_relative 'test_arc4'

describe HexaPDF::PDF::Encryption::FastARC4 do
  include ARC4EncryptionTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::FastARC4
  end
end
