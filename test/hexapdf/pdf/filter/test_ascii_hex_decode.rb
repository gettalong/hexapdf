# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/ascii_hex_decode'

describe HexaPDF::PDF::Filter::ASCIIHexDecode do
  include StandardFilterTests

  before do
    @obj = HexaPDF::PDF::Filter::ASCIIHexDecode
    @all_test_cases = [['Nov shmoz ka pop.', '4e6f762073686d6f7a206b6120706f702e>']]
    @decoded = @all_test_cases[0][0]
    @encoded = @all_test_cases[0][1]
  end

  describe "decoder" do
    it "ignores whitespace in the input" do
      assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded.scan(/./).map {|a| "#{a} \r\t"}.join("\n"), 1))))
    end

    it "works without the EOD marker" do
      assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded.chop, 5))))
    end

    it "ignores data after the EOD marker" do
      assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded + '4e6f7gzz'))))
    end

    it "fails on invalid characters" do
      assert_raises(HexaPDF::MalformedPDFError) { @obj.decoder(feeder('f0f0z')).resume }
    end
  end
end
