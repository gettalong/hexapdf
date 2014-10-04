# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/filter/run_length_decode'

describe HexaPDF::PDF::Filter::RunLengthDecode do

  include StandardFilterTests

  before do
    @obj = HexaPDF::PDF::Filter::RunLengthDecode
    @all_test_cases ||= [['abcabcaaaabbbcdeffffffagggggg', "\x05abcabc\xFDa\xFEb\x02cde\xFBf\x00a\xFBg\x80"]].
      each {|a,b| a.force_encoding(Encoding::BINARY); b.force_encoding(Encoding::BINARY)}
    @decoded = @all_test_cases[0][0]
    @encoded = @all_test_cases[0][1]
  end

  describe "decoder" do
    it "fails if data is missing from the source stream" do
      assert_raises(HexaPDF::MalformedPDFError) { collector(@obj.decoder(feeder(@encoded.chop.chop))) }
    end
  end

  # Won't work because the encoding is dependent on the length of the data that is passed in
  undef_method :test_encoder_works_with_single_byte_input

  describe "encoder" do
    it "works with single byte input" do
      assert_equal(@encoded.chars.map {|a| "\0#{a}"}.join << "\x80".force_encoding(Encoding::BINARY),
                   collector(@obj.encoder(feeder(@encoded.dup, 1))))
    end
  end

end
