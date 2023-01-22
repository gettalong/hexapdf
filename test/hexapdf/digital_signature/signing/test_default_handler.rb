# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require_relative '../common'

describe HexaPDF::DigitalSignature::Signing::DefaultHandler do
  before do
    @doc = HexaPDF::Document.new
    @handler = HexaPDF::DigitalSignature::Signing::DefaultHandler.new(
      certificate: CERTIFICATES.signer_certificate,
      key: CERTIFICATES.signer_key,
      certificate_chain: [CERTIFICATES.ca_certificate]
    )
  end

  it "returns the size of serialized signature" do
    assert(@handler.signature_size > 1000)
    @handler.signature_size = 100
    assert_equal(100, @handler.signature_size)
  end

  it "allows setting the DocMDP permissions" do
    assert_nil(@handler.doc_mdp_permissions)

    @handler.doc_mdp_permissions = :no_changes
    assert_equal(1, @handler.doc_mdp_permissions)
    @handler.doc_mdp_permissions = 1
    assert_equal(1, @handler.doc_mdp_permissions)

    @handler.doc_mdp_permissions = :form_filling
    assert_equal(2, @handler.doc_mdp_permissions)
    @handler.doc_mdp_permissions = 2
    assert_equal(2, @handler.doc_mdp_permissions)

    @handler.doc_mdp_permissions = :form_filling_and_annotations
    assert_equal(3, @handler.doc_mdp_permissions)
    @handler.doc_mdp_permissions = 3
    assert_equal(3, @handler.doc_mdp_permissions)

    @handler.doc_mdp_permissions = nil
    assert_nil(@handler.doc_mdp_permissions)

    assert_raises(ArgumentError) { @handler.doc_mdp_permissions = :other }
  end

  describe "sign" do
    it "can sign the data using PKCS7" do
      data = StringIO.new("data")
      store = OpenSSL::X509::Store.new
      store.add_cert(CERTIFICATES.ca_certificate)

      pkcs7 = OpenSSL::PKCS7.new(@handler.sign(data, [0, 4, 0, 0]))
      assert(pkcs7.detached?)
      assert_equal([CERTIFICATES.signer_certificate, CERTIFICATES.ca_certificate],
                   pkcs7.certificates)
      assert(pkcs7.verify([], store, data.string, OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY))
    end

    it "can use external signing" do
      @handler.external_signing = proc { "hallo" }
      assert_equal("hallo", @handler.sign(StringIO.new, [0, 0, 0, 0]))
    end
  end

  describe "finalize_objects" do
    before do
      @field = @doc.wrap({})
      @obj = @doc.wrap({})
    end

    it "only sets the mandatory values if no concrete finalization tasks need to be done" do
      @handler.finalize_objects(@field, @obj)
      assert(@field.empty?)
      assert_equal(:'Adobe.PPKLite', @obj[:Filter])
      assert_equal(:'adbe.pkcs7.detached', @obj[:SubFilter])
      assert_kind_of(Time, @obj[:M])
    end

    it "adjust the /SubFilter if signature type is etsi" do
      @handler.signature_type = :etsi
      @handler.finalize_objects(@field, @obj)
      assert_equal(:'ETSI.CAdES.detached', @obj[:SubFilter])
    end

    it "sets the reason, location and contact info fields" do
      @handler.reason = 'Reason'
      @handler.location = 'Location'
      @handler.contact_info = 'Contact'
      @handler.finalize_objects(@field, @obj)
      assert(@field.empty?)
      assert_equal(['Reason', 'Location', 'Contact'], @obj.value.values_at(:Reason, :Location, :ContactInfo))
    end

    it "applies the specified DocMDP permissions" do
      @handler.doc_mdp_permissions = :no_changes
      @handler.finalize_objects(@field, @obj)
      ref = @obj[:Reference][0]
      assert_equal(:DocMDP, ref[:TransformMethod])
      assert_equal(:SHA1, ref[:DigestMethod])
      assert_equal(1, ref[:TransformParams][:P])
      assert_equal(:'1.2', ref[:TransformParams][:V])
      assert_same(@obj, @doc.catalog[:Perms][:DocMDP])
    end

    it "fails if DocMDP should be set but there is already a signature" do
      @handler.doc_mdp_permissions = :no_changes
      2.times do
        field = @doc.acro_form(create: true).create_signature_field('test')
        field.field_value = :something
      end
      assert_raises(HexaPDF::Error) { @handler.finalize_objects(@field, @obj) }
    end
  end
end
