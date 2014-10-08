# -*- encoding: utf-8 -*-

require 'test_helper'
require 'ostruct'
require 'stringio'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/stream'


describe HexaPDF::PDF::StreamData do

  it "sets the attributes correctly on initialization" do
    s = HexaPDF::PDF::StreamData.new(:source, offset: 5, length: 10, filter: :a, decode_parms: [:b])
    assert_equal(:source, s.source)
    assert_equal(5, s.offset)
    assert_equal(10, s.length)
    assert_equal([:a], s.filter)
    assert_equal([:b], s.decode_parms)
  end

  it "normalizes the filter value" do
    s = HexaPDF::PDF::StreamData.new(:source)
    s.filter = :test
    assert_equal([:test], s.filter)
    s.filter = [:a, nil, :b]
    assert_equal([:a, :b], s.filter)
    s.filter = nil
    assert_equal([], s.filter)
  end

  it "normalizes the decode_parms value" do
    s = HexaPDF::PDF::StreamData.new(:source)
    s.decode_parms = :test
    assert_equal([:test], s.decode_parms)
    s.decode_parms = [:a, nil, :b]
    assert_equal([:a, :b], s.decode_parms)
    s.decode_parms = nil
    assert_equal([], s.decode_parms)
  end

end


describe HexaPDF::PDF::Stream do

  include TestHelper

  before do
    @document = OpenStruct.new
    @document.config = HexaPDF::PDF::Document.default_config
    def (@document).unwrap(obj); obj; end

    @stm = HexaPDF::PDF::Stream.new({}, document: @document)
  end

  describe "initialization" do
    it "accepts the stream keyword" do
      stm = HexaPDF::PDF::Stream.new({}, document: @document, stream: 'other')
      assert_equal('other', stm.stream)
    end

    it "fails if the value is not a PDF dictionary" do
      assert_raises(HexaPDF::Error) { HexaPDF::PDF::Stream.new(:Name) }
    end
  end

  describe "stream=" do
    it "allows assigning nil" do
      @stm.stream = nil
      assert_equal('', @stm.raw_stream)
      assert_equal('', @stm.stream)
      assert_equal(Encoding::BINARY, @stm.stream.encoding)
    end

    it "allows assigning a string" do
      @stm.stream = 'hallo'
      assert_equal('hallo', @stm.raw_stream)
      assert_equal('hallo', @stm.stream)
    end

    it "retains the encoding if a String is assigned" do
      @stm.stream = 'hallo'
      assert_equal(Encoding::UTF_8, @stm.stream.encoding)
      @stm.stream = 'hallo'.encode('ISO-8859-1')
      assert_equal(Encoding::ISO_8859_1, @stm.stream.encoding)
    end

    it "allows assigning a StreamData object" do
      @stmdata = HexaPDF::PDF::StreamData.new(StringIO.new('testing'))
      @stm.stream = @stmdata
      assert_equal(@stmdata, @stm.raw_stream)
      assert_equal('testing', @stm.stream)
      assert_equal(Encoding::BINARY, @stm.stream.encoding)
    end

    it "fails on any object class other than String, StreamData, NilClass" do
      assert_raises(HexaPDF::Error) { @stm.stream = 5 }
    end
  end

  def encoded_data(str, encoders = [])
    map = HexaPDF::PDF::Document.default_config['filter.map']
    tmp = feeder(str)
    encoders.each {|e| tmp = ::Object.const_get(map[e]).encoder(tmp)}
    tmp
  end

  describe "stream_decoder" do
    it "works with a string stream" do
      @stm.stream = 'testing'
      result = collector(@stm.stream_decoder)
      assert_equal('testing', result)
      assert_equal(Encoding::BINARY, result.encoding)
    end

    it "works with an IO object inside StreamData" do
      io = StringIO.new(collector(encoded_data('testing', [:A85, :AHx])))
      @stm.stream = HexaPDF::PDF::StreamData.new(io, filter: [:AHx, :A85])
      assert_equal('testing', collector(@stm.stream_decoder))
    end

    it "works with a Fiber object inside StreamData" do
      @stm.stream = HexaPDF::PDF::StreamData.new(encoded_data('testing', [:A85, :AHx]), filter: [:AHx, :A85])
      assert_equal('testing', collector(@stm.stream_decoder))
    end

    it "fails if an unknown filter name is used" do
      @stm.stream = HexaPDF::PDF::StreamData.new(feeder('testing'), filter: [:Unknown])
      assert_raises(HexaPDF::Error) { @stm.stream_decoder }
    end
  end

  describe "stream_encoder" do
    it "uses the :Filter and :DecodeParms entries of the value attribute correctly" do
      @stm.value[:Filter] = nil
      @stm.stream = 'test'
      assert_equal('test', collector(@stm.stream_encoder))

      @stm.value[:Filter] = :AHx
      @stm.stream = 'test'
      assert_equal('74657374>', collector(@stm.stream_encoder))

      @stm.value[:Filter] = [:AHx, :Fl]
      @stm.value[:DecodeParms] = nil
      @stm.stream = 'abcdefg'
      assert_equal("78da4b4c4a4e494d4b07000adb02bd>", collector(@stm.stream_encoder))

      @stm.value[:Filter] = [:AHx, :Fl]
      @stm.value[:DecodeParms] = [nil, {Predictor: 12}]
      @stm.stream = 'abcdefg'
      assert_equal("78da634a6462444000058f0076>", collector(@stm.stream_encoder))

      @stm.value[:Filter] = [:AHx, :Fl]
      @stm.value[:DecodeParms] = [nil, {Predictor: 10}]
      @stm.stream = 'abcdefg'
      assert_equal("78da6348644862486648614865486348070012fa02bd>", collector(@stm.stream_encoder))
    end

    it "decodes a StreamData stream before encoding" do
      @stm.value[:Filter] = :AHx
      @stm.stream = HexaPDF::PDF::StreamData.new(encoded_data('test', [:A85, :AHx]), filter: [:AHx, :A85])
      assert_equal('74657374>', collector(@stm.stream_encoder))
    end

    it "decodes only what is necessary of a StreamData stream on encoding" do
      @document.config['filter.map'][:AHx] = nil

      @stm.value[:Filter] = :AHx
      @stm.stream = HexaPDF::PDF::StreamData.new(encoded_data('test', [:AHx, :A85]), filter: [:A85, :AHx])
      assert_equal('74657374>', collector(@stm.stream_encoder))

      @stm.value[:Filter] = [:AHx, :AHx]
      fiber = encoded_data('test', [:AHx, :AHx])
      @stm.stream = HexaPDF::PDF::StreamData.new(fiber, filter: [:AHx, :AHx])
      assert_equal(fiber, @stm.stream_encoder)
    end
  end

end
