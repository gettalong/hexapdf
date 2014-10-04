# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter'
require 'stringio'

describe HexaPDF::PDF::Filter do

  include TestHelper

  before do
    @str = ''
    40.times { @str << [rand(2**32)].pack('N') }
  end

  describe "source_from_string" do

    it "doesn't modify the given string" do
      str = @str.dup
      HexaPDF::PDF::Filter.source_from_string(@str).resume.slice!(0, 10)
      assert_equal(str, @str)
    end

    it "returns the whole string" do
      assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_string(@str)))
    end

  end

  it "converts an IO into a source via #source_from_io" do
    io = StringIO.new(@str.dup)

    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io)))

    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, pos: -10)))
    assert_equal(@str[10..-1], collector(HexaPDF::PDF::Filter.source_from_io(io, pos: 10)))
    assert_equal("", collector(HexaPDF::PDF::Filter.source_from_io(io, pos: 200)))

    assert_equal("", collector(HexaPDF::PDF::Filter.source_from_io(io, length: 0)))
    assert_equal(@str[0...100], collector(HexaPDF::PDF::Filter.source_from_io(io, length: 100)))
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, length: 200)))
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, length: -15)))

    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, chunk_size: -15)))
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, chunk_size: 0)))
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, chunk_size: 100)))
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_io(io, chunk_size: 200)))

    assert_equal(@str[0...20], collector(HexaPDF::PDF::Filter.source_from_io(io, length: 20, chunk_size: 100)))
    assert_equal(@str[20...40], collector(HexaPDF::PDF::Filter.source_from_io(io, pos: 20, length: 20, chunk_size: 100)))
    assert_equal(@str[20...40], collector(HexaPDF::PDF::Filter.source_from_io(io, pos: 20, length: 20, chunk_size: 5)))
  end

  it "collects the binary string from a source via #string_from_source" do
    result = HexaPDF::PDF::Filter.string_from_source(HexaPDF::PDF::Filter.source_from_io(StringIO.new(@str), chunk_size: 50))
    assert_equal(@str, result)
    assert_equal(Encoding::BINARY, result.encoding)
  end

end
