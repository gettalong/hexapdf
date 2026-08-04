# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/type/document_security_store'

describe HexaPDF::Type::DocumentSecurityStore do
  before do
    @doc = HexaPDF::Document.new
    @dss = @doc.add({Type: :DSS})
  end

  [[:add_cert, :Certs], [:add_ocsp, :OCSPs], [:add_crl, :CRLs]].each do |method, field|
    describe method do
      it "adds a #{field[0..-2]} as an indirect stream object" do
        result = @dss.send(method, "der_data")
        assert_kind_of(HexaPDF::Stream, result)
        assert_equal(:FlateDecode, result[:Filter])
        assert_equal("der_data", result.stream)
        assert_equal(1, @dss[field].size)
      end

      it "returns the same stream object for duplicate #{field[0..-2]} data" do
        result1 = @dss.send(method, "der_data")
        result2 = @dss.send(method, "der_data")
        assert_same(result1, result2)
        assert_equal(1, @dss[field].size)
      end

      it "adds distinct stream objects for different #{field[0..-2]} data" do
        @dss.send(method, "data_one")
        @dss.send(method, "data_two")
        assert_equal(2, @dss[field].size)
      end
    end
  end

  describe "add_vri" do
    before do
      @signature_contents = 'signature bytes'
      @signature = @doc.add({Type: :Sig, Contents: @signature_contents})
      @vri_key = OpenSSL::Digest::SHA1.hexdigest(@signature_contents).upcase.to_sym
    end

    it "returns the VRI entry" do
      vri = @dss.add_vri(@signature)
      assert_equal(:VRI, vri.type)
    end

    it "creates the /VRI dictionary with an entry for the signature" do
      vri = @dss.add_vri(@signature)
      assert(@dss.key?(:VRI))
      assert_same(vri, @dss[:VRI][@vri_key])
    end

    it "populates /Cert in the VRI entry and the DSS /Certs array" do
      @dss.add_vri(@signature, certs: ["cert1", "cert2"])
      assert_equal(2, @dss[:VRI][@vri_key][:Cert].size)
      assert_equal(2, @dss[:Certs].size)
    end

    it "populates /OCSP in the VRI entry and the DSS /OCSPs array" do
      @dss.add_vri(@signature, ocsps: ["ocsp1", "ocsp2"])
      assert_equal(2, @dss[:VRI][@vri_key][:OCSP].size)
      assert_equal(2, @dss[:OCSPs].size)
    end

    it "populates /CRL in the VRI entry and the DSS /CRLs array" do
      @dss.add_vri(@signature, crls: ["crl1"])
      assert_equal(1, @dss[:VRI][@vri_key][:CRL].size)
      assert_equal(1, @dss[:CRLs].size)
    end

    it "de-duplicates DER streams shared across multiple VRI entries" do
      @dss.add_vri(@signature, certs: ["shared_cert", "cert_a"])
      @dss.add_vri(@doc.add({Type: :Sig, Contents: 'new'}), certs: ["shared_cert", "cert_b"])
      # shared_cert added once despite appearing in both VRI entries
      assert_equal(2, @dss[:VRI].value.size)
      assert_equal(3, @dss[:Certs].size)
    end

    it "creates a VRI entry with no optional arrays when all inputs are empty" do
      @dss.add_vri(@signature)
      vri = @dss[:VRI][@vri_key]
      refute(vri.key?(:Cert))
      refute(vri.key?(:OCSP))
      refute(vri.key?(:CRL))
    end
  end
end
