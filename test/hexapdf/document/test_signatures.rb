# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'tempfile'
require 'hexapdf/document'
require_relative '../type/signature/common'

describe HexaPDF::Document::Signatures do
  before do
    @doc = HexaPDF::Document.new
    @form = @doc.acro_form(create: true)
    @sig1 = @form.create_signature_field("test1")
    @sig2 = @form.create_signature_field("test2")
    @handler = HexaPDF::Document::Signatures::DefaultHandler.new(
      certificate: CERTIFICATES.signer_certificate,
      key: CERTIFICATES.signer_key,
      certificate_chain: [CERTIFICATES.ca_certificate]
    )
  end

  describe "DefaultHandler" do
    it "returns the size of serialized signature" do
      assert_equal(1310, @handler.signature_size)
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

    describe "finalize_objects" do
      before do
        @field = @doc.wrap({})
        @obj = @doc.wrap({})
      end

      it "does nothing if no finalization tasks need to be done" do
        @handler.finalize_objects(@field, @obj)
        assert(@field.empty?)
        assert(@obj.empty?)
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
        assert_equal({Reason: 'Reason', Location: 'Location', ContactInfo: 'Contact'}, @obj.value)
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

  describe "TimestampHandler" do
    before do
      @handler = HexaPDF::Document::Signatures::TimestampHandler.new
    end

    after do
      @tsa_server&.shutdown
    end

    it "allows setting the attributes in the constructor" do
      handler = HexaPDF::Document::Signatures::TimestampHandler.new(
        tsa_url: "url", tsa_hash_algorithm: "MD5", tsa_policy_id: "5",
        reason: "Reason", location: "Location", contact_info: "Contact",
        signature_size: 1_000
      )
      assert_equal("url", handler.tsa_url)
      assert_equal("MD5", handler.tsa_hash_algorithm)
      assert_equal("5", handler.tsa_policy_id)
      assert_equal("Reason", handler.reason)
      assert_equal("Location", handler.location)
      assert_equal("Contact", handler.contact_info)
      assert_equal(1_000, handler.signature_size)
    end

    it "finalizes the signature field and signature objects" do
      @field = @doc.wrap({})
      @sig = @doc.wrap({})
      @handler.reason = 'Reason'
      @handler.location = 'Location'
      @handler.contact_info = 'Contact'

      @handler.finalize_objects(@field, @sig)
      assert_equal('2.0', @doc.version)
      assert_equal(:DocTimeStamp, @sig[:Type])
      assert_equal(:'ETSI.RFC3161', @sig[:SubFilter])
      assert_equal('Reason', @sig[:Reason])
      assert_equal('Location', @sig[:Location])
      assert_equal('Contact', @sig[:ContactInfo])
    end

    it "returns the size of serialized signature" do
      @handler.tsa_url = "http://127.0.0.1:34567"
      CERTIFICATES.start_tsa_server
      assert_equal(1420, @handler.signature_size)
    end

    describe "sign" do
      before do
        @data = StringIO.new("data")
        @range = [0, 4, 0, 0]
        @handler.tsa_url = "http://127.0.0.1:34567"
        CERTIFICATES.start_tsa_server
      end

      it "respects the set hash algorithm and policy id" do
        @handler.tsa_hash_algorithm = 'SHA256'
        @handler.tsa_policy_id = '1.2.3.4.2'
        token = OpenSSL::ASN1.decode(@handler.sign(@data, @range))
        content = OpenSSL::ASN1.decode(token.value[1].value[0].value[2].value[1].value[0].value)
        policy_id = content.value[1].value
        digest_algorithm = content.value[2].value[0].value[0].value
        assert_equal('SHA256', digest_algorithm)
        assert_equal("1.2.3.4.2", policy_id)
      end

      it "returns the serialized timestamp token" do
        token = OpenSSL::PKCS7.new(@handler.sign(@data, @range))
        assert_equal(CERTIFICATES.ca_certificate.subject, token.signers[0].issuer)
        assert_equal(CERTIFICATES.timestamp_certificate.serial, token.signers[0].serial)
      end

      it "fails if the timestamp token could not be created" do
        @handler.tsa_hash_algorithm = 'SHA1'
        msg = assert_raises(HexaPDF::Error) { @handler.sign(@data, @range) }
        assert_match(/BAD_ALG/, msg.message)
      end

      it "fails if the timestamp server couldn't process the request" do
        @handler.tsa_policy_id = '1.2.3.4.1'
        msg = assert_raises(HexaPDF::Error) { @handler.sign(@data, @range) }
        assert_match(/Invalid TSA server response/, msg.message)
      end
    end
  end

  it "iterates over all signature dictionaries" do
    assert_equal([], @doc.signatures.to_a)
    @sig1.field_value = :sig1
    @sig2.field_value = :sig2
    assert_equal([:sig1, :sig2], @doc.signatures.to_a)
  end

  it "returns the number of signature dictionaries" do
    @sig1.field_value = :sig1
    assert_equal(1, @doc.signatures.count)
  end

  describe "handler" do
    it "return the initialized handler" do
      handler = @doc.signatures.handler(certificate: 'cert', reason: 'reason')
      assert_equal('cert', handler.certificate)
      assert_equal('reason', handler.reason)
    end

    it "fails if the given task is not available" do
      assert_raises(HexaPDF::Error) { @doc.signatures.handler(name: :unknown) }
    end
  end

  describe "add" do
    before do
      @doc = HexaPDF::Document.new(io: StringIO.new(MINIMAL_PDF))
      @io = StringIO.new(''.b)
    end

    it "uses the provided signature dictionary" do
      sig = @doc.add({Type: :Sig, Key: :value})
      @doc.signatures.add(@io, @handler, signature: sig)
      assert_equal(1, @doc.signatures.to_a.compact.size)
      assert_equal(:value, @doc.signatures.to_a[0][:Key])
      refute_equal(:value, @doc.acro_form.each_field.first[:Key])
    end

    it "creates the signature dictionary if none is provided" do
      @doc.signatures.add(@io, @handler)
      assert_equal(1, @doc.signatures.to_a.compact.size)
      refute(@doc.acro_form.each_field.first.key?(:Contents))
    end

    it "sets the needed information on the signature dictionary" do
      def @handler.finalize_objects(sigfield, sig)
        sig[:key] = :sig
        sigfield[:key] = :sig_field
      end
      @doc.signatures.add(@io, @handler, write_options: {update_fields: false})
      sig = @doc.signatures.first
      assert_equal(:'Adobe.PPKLite', sig[:Filter])
      assert_equal(:'adbe.pkcs7.detached', sig[:SubFilter])
      assert_equal([0, 996, 3618, 2501], sig[:ByteRange].value)
      assert_equal(:sig, sig[:key])
      assert_equal(:sig_field, @doc.acro_form.each_field.first[:key])
      assert(sig.key?(:Contents))
      assert(sig.key?(:M))
    end

    it "creates the main form dictionary if necessary" do
      @doc.signatures.add(@io, @handler)
      assert(@doc.acro_form)
      assert_equal([:signatures_exist, :append_only], @doc.acro_form.signature_flags)
    end

    it "uses the provided signature field" do
      field = @doc.acro_form(create: true).create_signature_field('Signature2')
      @doc.signatures.add(@io, @handler, signature: field)
      assert_nil(@doc.acro_form.field_by_name("Signature3"))
      refute_nil(field.field_value)
      assert_nil(@doc.signatures.first[:T])
    end

    it "uses an existing signature field if possible" do
      field = @doc.acro_form(create: true).create_signature_field('Signature2')
      field.field_value = sig = @doc.add({Type: :Sig, key: :value})
      @doc.signatures.add(@io, @handler, signature: sig)
      assert_nil(@doc.acro_form.field_by_name("Signature3"))
      assert_same(sig, @doc.signatures.first)
    end

    it "creates the signature field if necessary" do
      @doc.acro_form(create: true).create_text_field('Signature2')
      @doc.signatures.add(@io, @handler)
      field = @doc.acro_form.field_by_name("Signature3")
      assert_equal(:Sig, field.field_type)
      refute_nil(field.field_value)
      assert_equal(1, field.each_widget.count)
    end

    it "handles different xref section types correctly when determing the offsets" do
      @doc.delete(7)
      sig = @doc.signatures.add(@io, @handler, write_options: {update_fields: false})
      assert_equal([0, 988, 3610, 2483], sig[:ByteRange].value)
    end

    it "works if the signature object is the last object of the xref section" do
      field = @doc.acro_form(create: true).create_signature_field('Signature2')
      field.create_widget(@doc.pages[0], Rect: [0, 0, 0, 0])
      sig = @doc.signatures.add(@io, @handler, signature: field, write_options: {update_fields: false})
      assert_equal([0, 3095, 5717, 380], sig[:ByteRange].value)
    end

    it "allows writing to a file in addition to writing to an IO" do
      tempfile = Tempfile.new('hexapdf-signature')
      tempfile.close
      @doc.signatures.add(tempfile.path, @handler)
      doc = HexaPDF::Document.open(tempfile.path)
      assert(doc.signatures.first.verify(allow_self_signed: true).success?)
    end

    it "adds a new revision with the signature" do
      @doc.signatures.add(@io, @handler)
      signed_doc = HexaPDF::Document.new(io: @io)
      assert(signed_doc.signatures.first.verify)
    end
  end
end
