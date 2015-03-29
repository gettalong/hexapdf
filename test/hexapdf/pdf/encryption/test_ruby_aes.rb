# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/ruby_aes'
require 'hexapdf/pdf/encryption/fast_aes'
require_relative 'test_aes'

describe HexaPDF::PDF::Encryption::RubyAES do

  include AESEncryptionTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::RubyAES
  end

  it "is compatible with the OpenSSL based FastAES implementation" do
    sample = Random.new.bytes(1024)
    key = Random.new.bytes(16)
    iv = Random.new.bytes(16)
    assert_equal(sample, HexaPDF::PDF::Encryption::FastAES.new(key, iv, :encrypt).
                 process(HexaPDF::PDF::Encryption::RubyAES.new(key, iv, :decrypt).process(sample)))
    assert_equal(sample, HexaPDF::PDF::Encryption::FastAES.new(key, iv, :decrypt).
                 process(HexaPDF::PDF::Encryption::RubyAES.new(key, iv, :encrypt).process(sample)))
  end

end
