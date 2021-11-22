# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/type/signature'
require 'time'
require 'ostruct'

describe HexaPDF::Type::Signature::Handler do
  before do
    @time = Time.parse("2021-11-14 7:00")
    @dict = {Name: "handler", M: @time}
    @handler = HexaPDF::Type::Signature::Handler.new(@dict)
  end

  it "returns the signer name" do
    assert_equal("handler", @handler.signer_name)
  end

  it "returns the signing time" do
    assert_equal(@time, @handler.signing_time)
  end

  it "needs an implementation of certificate_chain" do
    assert_raises(RuntimeError) { @handler.certificate_chain }
  end

  it "needs an implementation of signer_certificate" do
    assert_raises(RuntimeError) { @handler.signer_certificate }
  end

  describe "store_verification_callback" do
    before do
      @result = HexaPDF::Type::Signature::VerificationResult.new
      @context = OpenStruct.new
    end

    it "can allow self-signed certificates" do
      [OpenSSL::X509::V_ERR_SELF_SIGNED_CERT_IN_CHAIN,
       OpenSSL::X509::V_ERR_SELF_SIGNED_CERT_IN_CHAIN].each do |error|
        [true, false].each do |allow_self_signed|
          @result.messages.clear
          @context.error = error
          @handler.store_verification_callback(@result, allow_self_signed: allow_self_signed).
            call(false, @context)
          assert_equal(1, @result.messages.size)
          assert_match(/self-signed certificate/i, @result.messages[0].content)
          assert_equal(allow_self_signed ? :info : :error, @result.messages[0].type)
        end
      end
    end
  end

  it "verifies the signing time" do
    result = HexaPDF::Type::Signature::VerificationResult.new
    [
      [true, '6:00', '8:00'],
      [false, '7:30', '8:00'],
      [false, '5:00', '6:00'],
    ].each do |success, not_before, not_after|
      result.messages.clear
      @handler.define_singleton_method(:signer_certificate) do
        OpenStruct.new.tap do |struct|
          struct.not_before = Time.parse("2021-11-14 #{not_before}")
          struct.not_after = Time.parse("2021-11-14 #{not_after}")
        end
      end
      @handler.send(:verify_signing_time, result)
      if success
        assert(result.messages.empty?)
      else
        assert_equal(1, result.messages.size)
      end
      @handler.singleton_class.remove_method(:signer_certificate)
    end
  end
end
