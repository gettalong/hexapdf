# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/lzw_decode'

class PDFFilterLZWDecodeTest < Minitest::Test

  include TestHelper
  include FilterHelper

  def setup
    @obj = HexaPDF::PDF::Filter::LZWDecode
  end

  # the first test case was not encoded by hexapdf
  TESTCASES = [["-----A---B", "\x80\x0b\x60\x50\x22\x0c\x0c\x85\x01"],
               ['abcabcaaaabbbcdeffffffagggggg', "\x80\x18LF8\x14\x10\xC3\a1BLfC)\x9A\x1D\x0F0\x99\xE2Q8\b"],
               ]
  TESTCASES.each {|a,b| a.force_encoding('BINARY'); b.force_encoding('BINARY')}

  def test_decoder
    TESTCASES.each_with_index do |(result, str), index|
      assert_equal(result, collector(@obj.decoder(feeder(str.dup))), "testcase #{index}")
    end

    str = TESTCASES[0][1]
    result = TESTCASES[0][0]
    assert_equal(result, collector(@obj.decoder(feeder(str.dup, 1))))

    assert_raises(HexaPDF::MalformedPDFError) { @obj.decoder(feeder("\xff\xff")).resume }
    assert_raises(HexaPDF::MalformedPDFError) { @obj.decoder(feeder("\x00\x7f\xff\xf0")).resume }
  end

  def test_encoder
    TESTCASES.each_with_index do |(str, result), index|
      assert_equal(result, collector(@obj.encoder(feeder(str.dup))), "testcase #{index}")
    end

    str = TESTCASES[0][0]
    result = TESTCASES[0][1]
    assert_equal(result, collector(@obj.encoder(feeder(str.dup, 1))))
  end

end
