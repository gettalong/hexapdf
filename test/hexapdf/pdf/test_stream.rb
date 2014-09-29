# -*- encoding: utf-8 -*-

require 'test_helper'
require 'ostruct'
require 'stringio'
require 'hexapdf/document'
require 'hexapdf/pdf/stream'

class PDFStreamTest < Minitest::Test

  include TestHelper

  def setup
    @document = OpenStruct.new
    @document.config = HexaPDF::Document.initial_config
    @document.store = Object.new
    def (@document.store).deref!(obj); obj; end
  end

  def test_stream_data
    s = HexaPDF::PDF::StreamData.new(:source, offset: 5, length: 10)
    assert_equal(:source, s.source)
    assert_equal(5, s.offset)
    assert_equal(10, s.length)
    assert_equal([], s.filter)
    assert_equal([], s.decode_parms)

    s.source = :other
    s.filter = :test
    s.decode_parms = [:test, :test2]
    assert_equal(:other, s.source)
    assert_equal([:test], s.filter)
    assert_equal([:test, :test2], s.decode_parms)
  end

  def test_initialize
    assert_raises(HexaPDF::Error) { HexaPDF::PDF::Stream.new(@document, :Name) }

    stm = HexaPDF::PDF::Stream.new(@document, {}, stream: 'other')
    assert_equal('other', stm.stream)
  end

  def test_stream_and_stream_assignment
    stm = HexaPDF::PDF::Stream.new(@document, {})

    stm.stream = nil
    assert_equal('', stm.stream)

    stm.stream = 'hallo'
    assert_equal('hallo', stm.stream)
    assert_equal(Encoding::UTF_8, stm.stream.encoding)

    stmdata = HexaPDF::PDF::StreamData.new(StringIO.new('testing'))
    stm.stream = stmdata
    assert_equal('testing', stm.stream)
    assert_equal(Encoding::BINARY, stm.stream.encoding)

    assert_raises(HexaPDF::Error) { stm.stream = 5 }
  end

  def decoder_data(str)
    tmp = feeder(str)
    tmp = HexaPDF::PDF::Filter::ASCII85Decode.encoder(tmp)
    HexaPDF::PDF::Filter::ASCIIHexDecode.encoder(tmp)
  end

  def test_stream_decoder
    stm = HexaPDF::PDF::Stream.new(@document, {})

    stm.stream = 'testing'
    assert_equal('testing', collector(stm.stream_decoder))

    stm.stream = HexaPDF::PDF::StreamData.new(StringIO.new(collector(decoder_data('testing'))), filter: [:AHx, :A85])
    assert_equal('testing', collector(stm.stream_decoder))

    stm.stream = HexaPDF::PDF::StreamData.new(decoder_data('testing'), filter: [:AHx, :A85])
    assert_equal('testing', collector(stm.stream_decoder))

    stm.stream = HexaPDF::PDF::StreamData.new(feeder('testing'), filter: [:Unknown])
    assert_raises(HexaPDF::Error) { stm.stream_decoder }
  end

  def test_stream_encoder
    stm = HexaPDF::PDF::Stream.new(@document, {Filter: [:AHx]})
    stm.stream = 'test'
    assert_equal('74657374>', collector(stm.stream_encoder))

    stm = HexaPDF::PDF::Stream.new(@document, {Filter: [:AHx]})
    stm.stream = HexaPDF::PDF::StreamData.new(decoder_data('test'), filter: [:AHx, :A85])
    assert_equal('74657374>', collector(stm.stream_encoder))

    @document.config['filter.map'][:A85] = self.class.name
    stm = HexaPDF::PDF::Stream.new(@document, {Filter: [:A85]})
    stm.stream = HexaPDF::PDF::StreamData.new(decoder_data('test'), filter: [:AHx, :A85])
    assert_equal(collector(HexaPDF::PDF::Filter::ASCII85Decode.encoder(feeder('test'))),
                 collector(stm.stream_encoder))
  end

end
