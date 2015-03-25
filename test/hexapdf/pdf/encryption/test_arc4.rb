# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/arc4'
require 'hexapdf/pdf/encryption/fast_arc4'

describe HexaPDF::PDF::Encryption::ARC4 do

  include CommonARC4EncryptionTests

  before do
    @algorithm_klass = HexaPDF::PDF::Encryption::ARC4
  end

  it "is compatible with the OpenSSL based FastARC4 implementation" do
    @keys.each_with_index do |key, i|
      assert_equal(@plain[i], HexaPDF::PDF::Encryption::FastARC4.new(key).
                   process(HexaPDF::PDF::Encryption::ARC4.new(key).process(@plain[i])))
    end
  end

end
