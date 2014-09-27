# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter'
require 'stringio'

class PDFFilterTest < Minitest::Test

  include TestHelper

  def setup
    @str = ''
    40.times { @str << [rand(2**32)].pack('N') }
  end

  def test_source_from_string
    assert_equal(@str, collector(HexaPDF::PDF::Filter.source_from_string(@str)))
  end

  def test_source_from_io
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

end
