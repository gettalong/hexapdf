# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/aes'
require 'hexapdf/pdf/encryption/fast_aes'

describe HexaPDF::PDF::Encryption::AES do

  include CommonAESEncryptionTests

  before do
    @algorithm_klass = HexaPDF::PDF::Encryption::AES
  end

  it "is compatible with the OpenSSL based FastAES implementation" do
    sample = Random.new.bytes(1024)
    key = Random.new.bytes(16)
    iv = Random.new.bytes(16)
    assert_equal(sample, HexaPDF::PDF::Encryption::FastAES.new(key, iv, :encrypt).
                 process(HexaPDF::PDF::Encryption::AES.new(key, iv, :decrypt).process(sample)))
    assert_equal(sample, HexaPDF::PDF::Encryption::FastAES.new(key, iv, :decrypt).
                 process(HexaPDF::PDF::Encryption::AES.new(key, iv, :encrypt).process(sample)))
  end

end
