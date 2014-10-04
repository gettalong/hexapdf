# -*- encoding: utf-8 -*-

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

gem 'minitest'
require 'minitest/autorun'
require 'fiber'

module TestHelper

  def feeder(string, len = string.length)
    Fiber.new do
      while string.length > 0
        Fiber.yield string.slice!(0, len).force_encoding('BINARY')
      end
    end
  end

  def collector(source)
    str = ''.force_encoding('BINARY')
    while source.alive? && data = source.resume
      str << data
    end
    str
  end

end


module StandardFilterTests

  include TestHelper

  TEST_BIG_STR = ''.force_encoding('BINARY')
  TEST_BIG_STR << [rand(2**32)].pack('N') while TEST_BIG_STR.length < 2**16
  TEST_BIG_STR.freeze

  def test_decodes_correctly
    @all_test_cases.each_with_index do |(result, str), index|
      assert_equal(result, collector(@obj.decoder(feeder(str.dup))), "testcase #{index}")
    end
  end

  def test_encodes_correctly
    @all_test_cases.each_with_index do |(str, result), index|
      assert_equal(result, collector(@obj.encoder(feeder(str.dup))), "testcase #{index}")
    end
  end

  def test_works_with_big_data
    assert_equal(TEST_BIG_STR, collector(@obj.decoder(@obj.encoder(feeder(TEST_BIG_STR.dup)))))
  end

  def test_decoder_returns_strings_in_binary_encoding
    assert_encodings(@obj.decoder(@obj.encoder(feeder('some test data', 1))), "decoder")
  end

  def test_encoder_returns_strings_in_binary_encoding
    assert_encodings(@obj.encoder(feeder('some test data', 1)), "encoder")
  end

  def assert_encodings(source, type)
    while source.alive? && data = source.resume
      assert_equal(Encoding::BINARY, data.encoding, "encoding problem in #{type}")
    end
  end

  def test_decoder_works_with_single_byte_input
    assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded.dup, 1))))
  end

  def test_encoder_works_with_single_byte_input
    assert_equal(@encoded, collector(@obj.encoder(feeder(@decoded.dup, 1))))
  end

end
