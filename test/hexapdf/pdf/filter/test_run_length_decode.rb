# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/run_length_decode'
require 'stringio'

class PDFFilterRunLengthDecodeTest < Minitest::Test

  include TestHelper

  def setup
    @obj = HexaPDF::PDF::Filter::RunLengthDecode
  end

  # the first test case was not encoded by hexapdf
  TESTCASES = [['abcabcaaaabbbcdeffffffagggggg', "\x06abcabca\xFEa\xFEb\x03cdef\xFCf\x01ag\xFCg\x80"],
               ['abcabcaaaabbbcdeffffffagggggg', "\x05abcabc\xFDa\xFEb\x02cde\xFBf\x00a\xFBg\x80"]]
  TESTCASES.each {|a,b| a.force_encoding('BINARY'); b.force_encoding('BINARY')}

  def test_decoder
    TESTCASES.each_with_index do |(result, str), index|
      assert_equal(result, collector(@obj.decoder(feeder(str.dup))), "testcase #{index}")
    end

    str = TESTCASES[0][1]
    result = TESTCASES[0][0]
    assert_equal(result, collector(@obj.decoder(feeder(str.dup, 1))))
    assert_equal(result, collector(@obj.decoder(feeder(str.chop))))
  end

  def test_encoder
    str = TESTCASES[1][0]
    result = TESTCASES[1][1]
    assert_equal(result, collector(@obj.encoder(feeder(str.dup))))
    assert_equal((str.chars.map {|a| "\0#{a}"}.join << "\x80").force_encoding('BINARY'),
                 collector(@obj.encoder(feeder(str.dup, 1))))
  end

end
