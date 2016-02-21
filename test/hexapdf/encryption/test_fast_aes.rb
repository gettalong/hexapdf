# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/encryption/fast_aes'
require_relative 'test_aes'

describe HexaPDF::Encryption::FastAES do
  include AESEncryptionTests

  before do
    @algorithm_class = HexaPDF::Encryption::FastAES
  end

  it "uses a better random bytes generator" do
    assert_equal(@algorithm_class.singleton_class, @algorithm_class.method(:random_bytes).owner)
    assert_equal(16, @algorithm_class.random_bytes(16).length)
  end
end
