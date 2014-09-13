# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/ascii85_decode'
require 'stringio'

class PDFFilterAscii85DecodeTest < Minitest::Test

  include TestHelper
  include FilterHelper

  def setup
    @obj = HexaPDF::PDF::Filter::ASCII85Decode
  end

  TESTCASES = [['Nov shmoz ka pop.', ':2b:uF(fE/H6@!3+E27</c~>'],
               ['Nov shmoz ka pop.1', ':2b:uF(fE/H6@!3+E27</hm~>'],
               ['Nov shmoz ka pop.12', ':2b:uF(fE/H6@!3+E27</ho*~>'],
               ['Nov shmoz ka pop.123', ':2b:uF(fE/H6@!3+E27</ho+;~>'],
               ["\0\0\0\0Nov shmoz ka pop.", 'z:2b:uF(fE/H6@!3+E27</c~>'],
               ["Nov \x0\x0\x0\x0shmoz ka pop.", ':2b:uzF(fE/H6@!3+E27</c~>']
               ]

  def test_decoder
    TESTCASES.each_with_index do |(result, str), index|
      assert_equal(result, collector(@obj.decoder(feeder(str.dup))), "testcase #{index}")
    end

    str = TESTCASES[0][1]
    result = TESTCASES[0][0]
    assert_equal(result, collector(@obj.decoder(feeder(str.dup, 1))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup.sub!(/~>/, '')))))
    assert_equal(result, collector(@obj.decoder(feeder(str.dup + "~>abcdefg"))))

    assert_raises(RuntimeError) { @obj.decoder(feeder('uuuuu')).resume }
    assert_raises(RuntimeError) { @obj.decoder(feeder('uuzuu')).resume }
  end

  def test_encoder
    TESTCASES.each do |str, result|
      assert_equal(result, collector(@obj.encoder(feeder(str.dup))))
    end

    str = TESTCASES[0][0]
    result = TESTCASES[0][1]
    assert_equal(result, collector(@obj.encoder(feeder(str.dup))))
    assert_equal(result, collector(@obj.encoder(feeder(str.dup, 1))))
  end

end
