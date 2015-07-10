# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/identity'

describe HexaPDF::PDF::Encryption::Identity do
  include EncryptionAlgorithmInterfaceTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::Identity
  end

  it "returns the data unmodified for encrypt/decrypt" do
    assert_equal('data', @algorithm_class.encrypt('key', 'data'))
  end

  it "returns the source Fiber unmodified for encryption_fiber/decryption_fiber" do
    f = Fiber.new {'data'}
    assert_equal(f, @algorithm_class.encryption_fiber('key', f))
  end
end
