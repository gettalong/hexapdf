# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/ascii_hex_decode'
require 'stringio'

class PDFFilterAsciiHexDecodeTest < Minitest::Test

  include TestHelper

  def setup
    @obj = HexaPDF::PDF::Filter::ASCIIHexDecode
  end

  def test_decoder
    str = '4E6F762073 686D6F7A20	6B612070 6F702E'
    result = 'Nov shmoz ka pop.'
    assert_equal(result, collector(@obj.decoder(feeder(str.dup))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup, 1))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup + '>', 5))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup + '>4e6f76', 5))))

    str = '4E6F762073 686D6F7A20	6B612070 6F702E7'
    result = 'Nov shmoz ka pop.p'
    assert_equal(result, collector(@obj.decoder(feeder(str.dup))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup, 1))))

    assert_raises(RuntimeError) { @obj.decoder(feeder('f0f0z')).resume }
  end

  def test_encoder
    str = 'Nov shmoz ka pop.'
    result = '4e6f762073686d6f7a206b6120706f702e>'
    assert_equal(result, collector(@obj.encoder(feeder(str.dup))))
    assert_equal(result, collector(@obj.encoder(feeder(str.dup, 1))))
  end

end
