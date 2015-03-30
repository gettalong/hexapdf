# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/ruby_arc4'
require 'hexapdf/pdf/encryption/fast_arc4'
require_relative 'test_arc4'

describe HexaPDF::PDF::Encryption::RubyARC4 do

  include ARC4EncryptionTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::RubyARC4
  end

  it "is compatible with the OpenSSL based FastARC4 implementation" do
    @keys.each_with_index do |key, i|
      assert_equal(@plain[i], HexaPDF::PDF::Encryption::FastARC4.new(key).
                   process(HexaPDF::PDF::Encryption::RubyARC4.new(key).process(@plain[i])))
    end
  end

end
