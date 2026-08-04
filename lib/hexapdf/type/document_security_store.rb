# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2026 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'openssl'
require 'hexapdf/dictionary'

module HexaPDF
  module Type

    # The document security store (DSS) dictionary contains data needed for verifying digital
    # signatures.
    #
    # See: PDF2.0 s12.8.4.3
    class DocumentSecurityStore < Dictionary

      # The validation-related information (VRI) dictionary contains validation information for one
      # signature. It signifies that the signature has been validated using this information.
      #
      # See: PDF2.0 s12.8.4.4
      class ValidationRelatedInformation < Dictionary

        define_type :VRI

        define_field :Type, type: Symbol, default: type
        define_field :Cert, type: PDFArray, version: '2.0'
        define_field :CRL,  type: PDFArray, version: '2.0'
        define_field :OCSP, type: PDFArray, version: '2.0'
        define_field :TU,   type: PDFDate, version: '2.0'
        define_field :TS,   type: Stream, version: '2.0'

      end

      define_type :DSS

      define_field :Type,  type: Symbol, default: type
      define_field :VRI,   type: Dictionary, version: '2.0'
      define_field :Certs, type: PDFArray, version: '2.0'
      define_field :OCSPs, type: PDFArray, version: '2.0'
      define_field :CRLs,  type: PDFArray, version: '2.0'

      # Adds validation data for a single signature to the /VRI dictionary and to the various
      # arrays, and returns the new VRI entry.
      #
      # +signature+::
      #     The signature for which the validation data should be added.
      #
      # +certs+::
      #     Array of DER-encoded certificates.
      #
      # +ocsps+::
      #     Array of DER-encoded OCSP responses.
      #
      # +crls+::
      #     Array of DER-encoded CRLs.
      def add_vri(signature, certs: [], ocsps: [], crls: [])
        key = OpenSSL::Digest::SHA1.hexdigest(signature.contents).upcase.to_sym
        vri = {Type: :VRI}
        vri[:Cert] = certs.map {|der| add_cert(der) } unless certs.empty?
        vri[:OCSP] = ocsps.map {|der| add_ocsp(der) } unless ocsps.empty?
        vri[:CRL]  = crls.map  {|der| add_crl(der)  } unless crls.empty?
        (self[:VRI] ||= {})[key] = document.add(vri)
      end

      # Adds the DER-encoded certificate to the /Certs array if not already present and returns
      # the stream object containing it.
      def add_cert(cert_der)
        add_data_as_stream_to_field(cert_der, :Certs)
      end

      # Adds the DER-encoded OCSP response to the /OCSPs array if not already present and returns
      # the stream object containing it.
      def add_ocsp(ocsp_der)
        add_data_as_stream_to_field(ocsp_der, :OCSPs)
      end

      # Adds the DER-encoded CRL to the /CRLs array if not already present and returns the stream
      # object containing it.
      def add_crl(crl_der)
        add_data_as_stream_to_field(crl_der, :CRLs)
      end

      private

      # Adds the given string +data+ to the +field+ array as stream object and returns the resulting
      # stream.
      #
      # If the field already contains a stream with the same data, this existing stream is returned.
      def add_data_as_stream_to_field(data, field)
        self[field] ||= []
        existing_stream = self[field].find {|stream| stream.stream == data }
        return existing_stream if existing_stream

        stream = document.add({Filter: :FlateDecode}, stream: data)
        self[field] << stream
        stream
      end

    end

  end
end
