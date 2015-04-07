# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/identity'

describe HexaPDF::PDF::Encryption::Identity do

  include EncryptionAlgorithmInterfaceTests

  before do
    @algorithm_class = HexaPDF::PDF::Encryption::Identity
  end

end
