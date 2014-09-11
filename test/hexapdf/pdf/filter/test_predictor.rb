# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/predictor'

class PDFFilterPredictorTest < Minitest::Test

  include TestHelper

  def setup
    @obj = HexaPDF::PDF::Filter::Predictor
  end

  PNG_TESTCASES = {
    'none' => {
      source: [110, 96].pack('C*'),
      result: [0, 110, 96].pack('C*'),
      Predictor: 10,
      Colors: 1,
      BitsPerComponent: 1,
      Columns: 14,
    },
    'sub' => {
      source: [10, 20, 30, 40, 50, 10, 20, 30, 40, 50].pack('C*'),
      result: [1, 10, 10, 10, 10, 10, 1, 10, 10, 10, 10, 10].pack('C*'),
      Predictor: 11,
      Colors: 2,
      BitsPerComponent: 2,
      Columns: 9,
    },
    'up' => {
      source: [10, 20, 30, 40, 50, 20, 30, 40, 50, 60].pack('C*'),
      result: [2, 10, 20, 30, 40, 50, 2, 10, 10, 10, 10, 10].pack('C*'),
      Predictor: 12,
      Colors: 3,
      BitsPerComponent: 4,
      Columns: 3,
    },
    'average' => {
      source: [10, 20, 30, 40, 50, 60, 70, 80, 20, 30, 40, 50, 60, 70, 80, 90].pack('C*'),
      result: [3, 10, 20, 25, 30, 35, 40, 45, 50, 3, 15, 20, 15, 15, 15, 15, 15, 15].pack('C*'),
      Predictor: 13,
      Colors: 4,
      BitsPerComponent: 4,
      Columns: 4,
    },
    'paeth' => {
      source: [10, 20, 30, 40, 50, 60, 70, 80, 20, 30, 40, 50, 60, 70, 80, 90].pack('C*'),
      result: [4, 10, 20, 20, 20, 20, 20, 20, 20, 4, 10, 10, 10, 10, 10, 10, 10, 10].pack('C*'),
      Predictor: 15,
      Colors: 4,
      BitsPerComponent: 4,
      Columns: 4,
    },
  }

  def test_png_encoder
    PNG_TESTCASES.each do |name, data|
      encoder = @obj.png_execute(:encoder, feeder(data[:source].dup), data[:Predictor], data[:Colors], data[:BitsPerComponent], data[:Columns])
      assert_equal(data[:result], collector(encoder), "testcase #{name}")
    end

    assert_raises(HexaPDF::Error) do
      data = PNG_TESTCASES['up']
      encoder = @obj.png_execute(:encoder, feeder(data[:source][0..-2], 1), data[:Predictor], data[:Colors],
                                 data[:BitsPerComponent], data[:Columns])
      collector(encoder)
    end
  end

  def test_png_decoder
    PNG_TESTCASES.each do |name, data|
      encoder = @obj.png_execute(:decoder, feeder(data[:result].dup), data[:Predictor], data[:Colors], data[:BitsPerComponent], data[:Columns])
      assert_equal(data[:source], collector(encoder), "testcase #{name}")
    end

    assert_raises(HexaPDF::Error) do
      data = PNG_TESTCASES['up']
      encoder = @obj.png_execute(:decoder, feeder(data[:result][0..-2], 1), data[:Predictor], data[:Colors],
                                 data[:BitsPerComponent], data[:Columns])
      collector(encoder)
    end
  end

  TIFF_TESTCASES = {
    'simple' => {
      source: [0b10101010, 0b11111100].pack('C*'),
      result: [0b11111111, 0b10000000].pack('C*'),
      Predictor: 2,
      Colors: 1,
      BitsPerComponent: 1,
      Columns: 14,
    },
    'complex' => {
      source: [0b10101010, 0b11110000, 0b10010100, 0b11010000].pack('C*'),
      result: [0b10101000, 0b01010000, 0b10010110, 0b10000000].pack('C*'),
      Predictor: 2,
      Colors: 3,
      BitsPerComponent: 2,
      Columns: 2,
    },
  }

  def test_tiff_encoder
    TIFF_TESTCASES.each do |name, data|
      encoder = @obj.tiff_execute(:encoder, feeder(data[:source].dup), data[:Colors],
                                  data[:BitsPerComponent], data[:Columns])
      assert_equal(data[:result], collector(encoder), "testcase #{name}")
    end

    assert_raises(HexaPDF::Error) do
      data = TIFF_TESTCASES['simple']
      encoder = @obj.tiff_execute(:encoder, feeder(data[:source][0..-2], 1), data[:Colors],
                                  data[:BitsPerComponent], data[:Columns])
      collector(encoder)
    end
  end

  def test_tiff_decoder
    TIFF_TESTCASES.each do |name, data|
      decoder = @obj.tiff_execute(:decoder, feeder(data[:result].dup), data[:Colors],
                                  data[:BitsPerComponent], data[:Columns])
      assert_equal(data[:source], collector(decoder), "testcase #{name}")
    end

    assert_raises(HexaPDF::Error) do
      data = TIFF_TESTCASES['simple']
      decoder = @obj.tiff_execute(:decoder, feeder(data[:result][0..-2], 1), data[:Colors],
                                  data[:BitsPerComponent], data[:Columns])
      collector(decoder)
    end
  end

  def test_encoder
    (PNG_TESTCASES.merge(TIFF_TESTCASES)).each do |name, data|
      assert_equal(data[:result], collector(@obj.encoder(feeder(data[:source].dup), data)), "test case: #{name}")
    end

    data = PNG_TESTCASES['none'].dup
    data[:Predictor] = 5
    assert_raises(HexaPDF::InvalidPDFObjectError) do
      @obj.encoder(feeder(data[:source].dup), data)
    end
  end

  def test_decoder
    (PNG_TESTCASES.merge(TIFF_TESTCASES)).each do |name, data|
      assert_equal(data[:source], collector(@obj.decoder(feeder(data[:result].dup), data)), "test case: #{name}")
    end
  end

end
