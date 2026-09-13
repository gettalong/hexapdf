# -*- encoding: utf-8 -*-

begin
  require 'simplecov'
  SimpleCov.start do
    enable_coverage(:method)
    unless ENV['NO_SIMPLECOV']
      coverage(:line) { minimum 100 }
      coverage(:method) { minimum 100 }
    end
    skip '/test/'
    skip '/fast_arc4.rb'
  end
rescue LoadError
end

gem 'minitest'
begin
  gem 'minitest-mock'
  require 'minitest/mock'
rescue Gem::MissingSpecError
  # Assume Minitest < 6 is in use for older Rubies
end
gem 'strscan'
require 'minitest/autorun'
require 'fiber'
require 'zlib'
require 'hexapdf/test_utils'

TEST_DATA_DIR = File.join(__dir__, 'data')
MINIMAL_PDF = File.binread(File.join(TEST_DATA_DIR, 'minimal.pdf')).freeze

Minitest::Test.make_my_diffs_pretty!

ENV['TZ'] = 'UTC'
