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
        Fiber.yield string.slice!(0, len)
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


module FilterHelper

  TEST_BIG_STR = ''.force_encoding('BINARY')
  TEST_BIG_STR << [rand(2**32)].pack('N') while TEST_BIG_STR.length < 2**16
  TEST_BIG_STR.freeze

  def test_big_data
    assert_equal(TEST_BIG_STR, collector(@obj.decoder(@obj.encoder(feeder(TEST_BIG_STR.dup)))))
  end

end
