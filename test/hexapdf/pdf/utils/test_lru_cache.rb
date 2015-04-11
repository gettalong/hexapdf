# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/utils/lru_cache'

describe HexaPDF::PDF::Utils::LRUCache do

  before do
    @cache = HexaPDF::PDF::Utils::LRUCache.new(5)
    5.times {|i| @cache[i] = i*2}
  end

  it "removes the LRU item when the size is reached" do
    assert([1, 2], @cache.instance_variable_get(:@cache).first)
    @cache[6] = 7
    assert([2, 4], @cache.instance_variable_get(:@cache).first)
  end

  it "freshes an item on access" do
    @cache[1]
    assert([2, 4], @cache.instance_variable_get(:@cache).first)
  end

end
