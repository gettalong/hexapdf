# -*- encoding: utf-8 -*-

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

gem 'minitest'
require 'minitest/autorun'

module TestHelper

  def feeder(string, len = string.length)
    Fiber.new do
      while string.length > 0
        Fiber.yield string.slice!(0, len)
      end
    end
  end

  def collector(source)
    str = ''
    while source.alive? && data = source.resume
      str << data
    end
    str
  end

end
