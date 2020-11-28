# -*- encoding: utf-8 -*-

begin
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
rescue LoadError
end

gem 'minitest'
require 'minitest/autorun'
require 'fiber'
require 'zlib'

TEST_DATA_DIR = File.join(__dir__, 'data')
MINIMAL_PDF = File.read(File.join(TEST_DATA_DIR, 'minimal.pdf')).freeze

Minitest::Test.make_my_diffs_pretty!

module TestHelper

  # Asserts that the method +name+ of +object+ gets invoked with the +expected_values+ when
  # executing the block. +expected_values+ should contain arrays of arguments, one array for each
  # invocation of the method.
  def assert_method_invoked(object, name, *expected_values, check_block: false)
    args = []
    block = []
    object.define_singleton_method(name) {|*la, &lb| args << la; block << lb }
    yield
    assert_equal(expected_values, args, "Incorrect arguments for #{object.class}##{name}")
    block.each do |block_arg|
      assert_kind_of(Proc, block_arg, "Missing block for #{object.class}##{name}") if check_block
    end
  ensure
    object.singleton_class.send(:remove_method, name)
  end

  module_function

  def feeder(string, len = string.length)
    Fiber.new do
      until string.empty?
        Fiber.yield(string.slice!(0, len).force_encoding('BINARY'))
      end
    end
  end

  def collector(source)
    str = ''.force_encoding('BINARY')
    while source.alive? && (data = source.resume)
      str << data
    end
    str
  end
end

Minitest::Spec.include(TestHelper)
