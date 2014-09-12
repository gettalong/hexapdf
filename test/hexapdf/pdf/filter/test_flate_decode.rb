# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/flate_decode'

class PDFFilterFlateDecodeTest < Minitest::Test

  include TestHelper

  def setup
    @obj = HexaPDF::PDF::Filter::FlateDecode
  end

  def test_decoder
    assert_raises(HexaPDF::Error) do
      collector(@obj.decoder(feeder("some test")))
    end
  end

  def test_decoder_and_encoder
    str = ''.force_encoding('BINARY')
    str << [rand(2**32)].pack('N') while str.length < 2**12
    str *= 16
    assert_equal(str, collector(@obj.decoder(@obj.encoder(feeder(str.dup)))))
  end

end
