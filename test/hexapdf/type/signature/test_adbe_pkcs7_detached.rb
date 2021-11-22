# -*- encoding: utf-8 -*-

require 'test_helper'
require_relative 'common'
require 'hexapdf/type/signature'
require 'ostruct'

describe HexaPDF::Type::Signature::AdbePkcs7Detached do
  before do
    @data = 'Some data'
    @dict = OpenStruct.new
    @pkcs7 = OpenSSL::PKCS7.sign(CERTIFICATES.signer_certificate, CERTIFICATES.signer_key,
                                 @data, [CERTIFICATES.ca_certificate],
                                 OpenSSL::PKCS7::DETACHED)
    @dict.contents = @pkcs7.to_der
    @dict.signed_data = @data
    @handler = HexaPDF::Type::Signature::AdbePkcs7Detached.new(@dict)
  end

  it "returns the signer name" do
    assert_equal("signer", @handler.signer_name)
  end

  it "returns the signing time" do
    assert_equal(@pkcs7.signers.first.signed_time, @handler.signing_time)
  end

  it "returns the certificate chain" do
    assert_equal([CERTIFICATES.signer_certificate, CERTIFICATES.ca_certificate],
                 @handler.certificate_chain)
  end

  it "returns the signer certificate" do
    assert_equal(CERTIFICATES.signer_certificate, @handler.signer_certificate)
  end

  it "allows access to the signer information" do
    info = @handler.signer_info
    assert(info)
    assert_equal(2, info.serial)
    assert_equal(CERTIFICATES.signer_certificate.issuer, info.issuer)
  end

  describe "verify" do
    before do
      @store = OpenSSL::X509::Store.new
      @store.add_cert(CERTIFICATES.ca_certificate)
    end

    it "logs an error if there are no certificates" do
      def @handler.certificate_chain; []; end
      result = @handler.verify(@store)
      assert_equal(1, result.messages.size)
      assert_equal(:error, result.messages.first.type)
      assert_match(/No certificates/, result.messages.first.content)
    end

    it "logs an error if there is more than one signer" do
      @pkcs7.add_signer(OpenSSL::PKCS7::SignerInfo.new(CERTIFICATES.signer_certificate,
                                                       CERTIFICATES.signer_key, 'SHA1'))
      @dict.contents = @pkcs7.to_der
      @handler = HexaPDF::Type::Signature::AdbePkcs7Detached.new(@dict)
      result = @handler.verify(@store)
      assert_equal(2, result.messages.size)
      assert_equal(:error, result.messages.first.type)
      assert_match(/Exactly one signer needed/, result.messages.first.content)
    end

    it "logs an error if the signer certificate is not found" do
      def @handler.signer_certificate; nil end
      result = @handler.verify(@store)
      assert_equal(1, result.messages.size)
      assert_equal(:error, result.messages.first.type)
      assert_match(/Signer.*not found/, result.messages.first.content)
    end

    it "logs an error if the signer certificate is not usable for digital signatures" do
      @pkcs7 = OpenSSL::PKCS7.sign(CERTIFICATES.ca_certificate, CERTIFICATES.ca_key,
                                   @data, [CERTIFICATES.ca_certificate],
                                   OpenSSL::PKCS7::DETACHED)
      @dict.contents = @pkcs7.to_der
      @handler = HexaPDF::Type::Signature::AdbePkcs7Detached.new(@dict)
      result = @handler.verify(@store)
      assert_equal(:error, result.messages.first.type)
      assert_match(/key usage is missing 'Digital Signature'/, result.messages.first.content)
    end

    it "verifies the signature itself" do
      result = @handler.verify(@store)
      assert_equal(:info, result.messages.last.type)
      assert_match(/Signature valid/, result.messages.last.content)

      @dict.signed_data = 'other data'
      result = @handler.verify(@store)
      assert_equal(:error, result.messages.last.type)
      assert_match(/Signature verification failed/, result.messages.last.content)
    end
  end
end
