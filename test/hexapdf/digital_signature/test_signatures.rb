# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'tempfile'
require 'hexapdf/document'
require_relative 'common'

describe HexaPDF::DigitalSignature::Signatures do
  before do
    @doc = HexaPDF::Document.new
    @form = @doc.acro_form(create: true)
    @sig1 = @form.create_signature_field("test1")
    @sig2 = @form.create_signature_field("test2")
  end

  it "iterates over all signature dictionaries" do
    assert_equal([], @doc.signatures.to_a)
    @sig1.field_value = {k: :sig1}
    @sig2.field_value = {k: :sig2}
    assert_equal([{k: :sig1}, {k: :sig2}], @doc.signatures.to_a)
  end

  it "returns the number of signature dictionaries" do
    @sig1.field_value = {k: :sig1}
    assert_equal(1, @doc.signatures.count)
  end

  describe "signing_handler" do
    it "return the initialized handler" do
      handler = @doc.signatures.signing_handler(certificate: 'cert', reason: 'reason')
      assert_equal('cert', handler.certificate)
      assert_equal('reason', handler.reason)
    end

    it "fails if the given task is not available" do
      assert_raises(HexaPDF::Error) { @doc.signatures.signing_handler(name: :unknown) }
    end
  end

  describe "add" do
    before do
      @doc = HexaPDF::Document.new(io: StringIO.new(MINIMAL_PDF))
      @io = StringIO.new(''.b)
      @handler = @doc.signatures.signing_handler(
        certificate: CERTIFICATES.signer_certificate,
        key: CERTIFICATES.signer_key,
        certificate_chain: [CERTIFICATES.ca_certificate]
      )
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
      assert_equal([0, 925, 925 + (sig[:Contents].size + 5) * 2 + 2, 2455 + HexaPDF::VERSION.length],
                   sig[:ByteRange].value)
      assert_equal(:sig, sig[:key])
      assert_equal(:sig_field, @doc.acro_form.each_field.first[:key])
      assert(sig.key?(:Contents))
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

    it "creates an empty widget on the first page for the signature field if necessary" do
      @doc.pages.add
      field = @doc.acro_form(create: true).create_signature_field('Signature2')
      field.field_value = sig = @doc.add({Type: :Sig, key: :value})
      @doc.signatures.add(@io, @handler, signature: sig)
      widgets = field.each_widget.to_a
      assert_equal(1, widgets.size)
      assert_equal(@doc.pages[0], widgets[0][:P])
      assert_equal([0, 0, 0, 0], widgets[0][:Rect])
    end

    it "handles a bug in Adobe Acrobat related to images not showing without a /Resources entry" do
      field = @doc.acro_form(create: true).create_signature_field('Signature')
      image = @doc.add({Type: :XObject, Subtype: :Image, Width: 1, Height: 1, ColorSpace: :DeviceGray,
                        BitsPerComponent: 8}, stream: 'A')
      field.create_widget(@doc.pages[0], Rect: [0, 0, 100, 100]).create_appearance.
        canvas.xobject(image, at: [0, 0])
      @doc.signatures.add(@io, @handler, signature: field)
      assert(image.key?(:Resources))
      assert_equal({}, image[:Resources])
    end

    it "handles different xref section types correctly when determing the offsets" do
      @doc.delete(7)
      sig = @doc.signatures.add(@io, @handler, write_options: {update_fields: false})
      l1 = 1030 + HexaPDF::VERSION.length
      assert_equal([0, l1, l1 + (sig[:Contents].size + 5) * 2 + 2, 2437 + HexaPDF::VERSION.length],
                   sig[:ByteRange].value)
    end

    it "works if the signature object is the last object of the xref section" do
      field = @doc.acro_form(create: true).create_signature_field('Signature2')
      field.create_widget(@doc.pages[0], Rect: [0, 0, 0, 0])
      sig = @doc.signatures.add(@io, @handler, signature: field, write_options: {update_fields: false})
      l1 = 3097 + HexaPDF::VERSION.length
      assert_equal([0, l1, l1 + (sig[:Contents].size + 5) * 2 + 2, 374 + HexaPDF::VERSION.length],
                   sig[:ByteRange].value)
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

  describe "add_ltv_information" do
    before do
      CERTIFICATES.start_ocsp_crl_server
      @doc = HexaPDF::Document.new(io: StringIO.new(MINIMAL_PDF))
      @io = StringIO.new(''.b)
    end

    # Signs @doc and returns a new HexaPDF::Document instance for the signed document.
    def sign_with(certificate, key: CERTIFICATES.signer_key, certificate_chain: [CERTIFICATES.ca_certificate])
      io = StringIO.new(''.b)
      @doc.sign(io, certificate: certificate, key: key, certificate_chain: certificate_chain)
      HexaPDF::Document.new(io: io)
    end

    it "adds all certificates to the DSS" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_ocsp)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      assert_equal([CERTIFICATES.signer_certificate_with_ocsp, CERTIFICATES.ca_certificate],
                   dss.certificates)
    end

    it "fails if one of the certificates has no OCSP or CRL URL" do
      doc = sign_with(CERTIFICATES.signer_certificate)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "adds a VRI entry for all non-root certificates" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_ocsp)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      assert_equal(1, dss[:VRI].value.length)
      assert(dss.vri_for(doc.signatures.first))
    end

    it "embeds OCSP validation data for a certificate that has an AIA OCSP URL" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_ocsp)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      vri = dss.vri_for(doc.signatures.first)
      assert_equal(dss[:OCSPs].value, vri[:OCSP].value)
      assert_equal(dss[:Certs].value, vri[:Cert].value)
      assert_nil(dss[:CRLs])
      assert_nil(vri[:CRL])
    end

    it "handles a connection failure to the OCSP server" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_bad_ocsp)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "handles unsuccessful OCSP validation" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_unsuccessful_ocsp)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "handles successful OCSP validation but with a non-good certificate status" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_revoked_ocsp)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/OCSP response.*not valid/, e.message)
    end

    it "handles non-OK HTTP response codes when fetching the OCSP response" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_http_error_ocsp)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "doesn't use the OCSP information if the issuer certificate is not embedded" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_ocsp, certificate_chain: [])
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "embeds CRL validation data when no OCSP URL is present in the certificate" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_crl)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      vri = dss.vri_for(doc.signatures.first)
      assert_equal(dss[:CRLs].value, vri[:CRL].value)
      assert_equal(dss[:Certs].value, vri[:Cert].value)
      assert_nil(dss[:OCSPs])
      assert_nil(vri[:OCSP])
    end

    it "handles a connection failure to the CRL server" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_bad_crl)
      # CRL URL available but bad endpoint
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "handles a certificate that is revoked via CRL" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_revoked_crl)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/CRL.*certificate is revoked/, e.message)
    end

    it "handles non-OK HTTP response codes when fetching the CRL response" do
      doc = sign_with(CERTIFICATES.signer_certificate_with_http_error_crl)
      e = assert_raises(HexaPDF::Error) { doc.signatures.add_ltv_information }
      assert_match(/No OCSP and CRL/, e.message)
    end

    it "embeds validation data for an embedded timestamp signature" do
      CERTIFICATES.start_tsa_server
      ts_handler = @doc.signatures.signing_handler(name: :timestamp, signature_size: 20_000,
                                                   tsa_url: "http://127.0.0.1:34567")
      io = StringIO.new(''.b)
      @doc.sign(io, certificate: CERTIFICATES.signer_certificate_with_ocsp,
                key: CERTIFICATES.signer_key, certificate_chain: [CERTIFICATES.ca_certificate],
                timestamp_handler: ts_handler)
      doc = HexaPDF::Document.new(io: io)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      vri = dss.vri_for(doc.signatures.first)
      assert_equal(3, vri[:Cert].value.size)
    end

    it "creates VRI entries for all signatures" do
      @doc = sign_with(CERTIFICATES.signer_certificate_with_ocsp)
      doc = sign_with(CERTIFICATES.signer_certificate_with_crl)
      doc.signatures.add_ltv_information
      dss = doc.catalog.dss
      assert_equal(2, dss[:VRI].value.size)
    end
  end
end
