# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2022 Thomas Leitner
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
require 'hexapdf/type/signature'

module HexaPDF
  module Type
    class Signature

      # The signature handler for the adbe.pkcs7.detached sub-filter.
      class AdbePkcs7Detached < Handler

        # Creates a new signature handler for the given signature dictionary.
        def initialize(signature_dict)
          super
          @pkcs7 = OpenSSL::PKCS7.new(signature_dict.contents)
        end

        # Returns the common name of the signer.
        def signer_name
          signer_certificate.subject.to_a.assoc("CN")&.[](1) || super
        end

        # Returns the time of signing.
        def signing_time
          signer_info.signed_time rescue super
        end

        # Returns the certificate chain.
        def certificate_chain
          @pkcs7.certificates
        end

        # Returns the signer certificate (an instance of OpenSSL::X509::Certificate).
        def signer_certificate
          info = signer_info
          certificate_chain.find {|cert| cert.issuer == info.issuer && cert.serial == info.serial }
        end

        # Returns the signer information object (an instance of OpenSSL::PKCS7::SignerInfo).
        def signer_info
          @pkcs7.signers.first
        end

        # Verifies the signature using the provided OpenSSL::X509::Store object.
        def verify(store, allow_self_signed: false)
          result = super

          signer_info = self.signer_info
          signer_certificate = self.signer_certificate
          certificate_chain = self.certificate_chain

          if certificate_chain.empty?
            result.log(:error, "No certificates found in signature")
            return result
          end

          if @pkcs7.signers.size != 1
            result.log(:error, "Exactly one signer needed, found #{@pkcs7.signers.size}")
          end

          unless signer_certificate
            result.log(:error, "Signer serial=#{signer_info.serial} issuer=#{signer_info.issuer} " \
                       "not found in certificates stored in PKCS7 object")
            return result
          end

          key_usage = signer_certificate.extensions.find {|ext| ext.oid == 'keyUsage' }
          unless key_usage && key_usage.value.split(', ').include?("Digital Signature")
            result.log(:error, "Certificate key usage is missing 'Digital Signature'")
          end

          if signature_dict.signature_type == 'ETSI.RFC3161'
            # Getting the needed values is not directly supported by Ruby OpenSSL
            p7 = OpenSSL::ASN1.decode(signature_dict.contents.sub(/\x00*\z/, ''))
            signed_data = p7.value[1].value[0]
            content_info = signed_data.value[2]
            content = OpenSSL::ASN1.decode(content_info.value[1].value[0].value)
            digest_algorithm = content.value[2].value[0].value[0].value
            original_hash = content.value[2].value[1].value
            recomputed_hash = OpenSSL::Digest.digest(digest_algorithm, signature_dict.signed_data)
            hash_valid = (original_hash == recomputed_hash)
          else
            data = signature_dict.signed_data
            hash_valid = true # hash will be checked by @pkcs7.verify
          end
          if hash_valid && @pkcs7.verify(certificate_chain, store, data,
                                         OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY)
            result.log(:info, "Signature valid")
          else
            result.log(:error, "Signature verification failed")
          end

          result
        end

      end

    end
  end
end
