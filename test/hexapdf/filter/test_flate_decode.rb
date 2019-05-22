# -*- encoding: utf-8 -*-

require_relative 'common'
require 'hexapdf/filter/flate_decode'

describe HexaPDF::Filter::FlateDecode do
  include CommonFilterTests

  before do
    @obj = HexaPDF::Filter::FlateDecode
    @all_test_cases = [["abcdefg".force_encoding(Encoding::BINARY),
                        "x\xDAKLJNIMK\a\x00\n\xDB\x02\xBD".force_encoding(Encoding::BINARY)]]
    @decoded = @all_test_cases[0][0]
    @encoded = @all_test_cases[0][1]
    @encoded_predictor = "x\xDAcJdbD@\x00\x05\x8F\x00v".force_encoding(Encoding::BINARY)
    @predictor_opts = {Predictor: 12}
  end

  describe "decoder" do
    it "works for empty input" do
      assert_equal('', collector(@obj.decoder(Fiber.new { "" })))
      assert_equal('', collector(@obj.decoder(Fiber.new {})))
    end

    it "applies the Predictor after decoding" do
      assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded_predictor), @predictor_opts)))
    end

    it "fails on invalid input" do
      assert_raises(HexaPDF::FilterError) do
        collector(@obj.decoder(feeder(@encoded[0..-2], @encoded.length - 3)))
      end
      assert_raises(HexaPDF::FilterError) do
        collector(@obj.decoder(feeder("some data")))
      end
    end
  end

  describe "encoder" do
    it "applies the Predictor before encoding" do
      assert_equal(@encoded_predictor, collector(@obj.encoder(feeder(@decoded), @predictor_opts)))
    end
  end
end
