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
require 'hexapdf/error'
require 'stringio'

module HexaPDF
  module DigitalSignature
    module Signing

      # This is the default signing handler which provides the ability to sign a document with the
      # adbe.pkcs7.detached or ETSI.CAdES.detached algorithms. It is registered under the :default
      # name.
      #
      # == Usage
      #
      # The signing handler is used by default by all methods that need a signing handler. Therefore
      # it is usually only necessary to provide the actual attribute values.
      #
      # This handler provides two ways to create the PKCS#7/CMS signed-data structure required by
      # Signatures#add:
      #
      # * By providing the signing certificate together with the signing key and the certificate
      #   chain. This way HexaPDF itself does the signing. It is the preferred way if all the needed
      #   information is available.
      #
      #   Assign the respective data to the #certificate, #key and #certificate_chain attributes.
      #
      # * By using an external signing mechanism. Here the actual signing happens "outside" of
      #   HexaPDF, for example, in custom code or even asynchronously. This is needed in case the
      #   signing certificate plus key are not directly available but only an interface to them
      #   (e.g. when dealing with a HSM).
      #
      #   Assign a callable object to #external_signing. If the signing process needs to be
      #   asynchronous, make sure to set the #signature_size appropriately, return an empty string
      #   during signing and later use Signatures.embed_signature to embed the actual signature.
      #
      # Additional functionality:
      #
      # * Optionally setting the reason, location and contact information.
      # * Making the signature a certification signature by applying the DocMDP transform method.
      #
      # Example:
      #
      #   # Signing using certificate + key
      #   document.sign("output.pdf", certificate: my_cert, key: my_key,
      #                 certificate_chain: my_chain)
      #
      #   # Signing using an external mechanism:
      #   signing_proc = lambda do |io, byte_range|
      #     io.pos = byte_range[0]
      #     data = io.read(byte_range[1])
      #     io.pos = byte_range[2]
      #     data << io.read(byte_range[3])
      #     signing_service.pkcs7_sign(data)
      #   end
      #   document.sign("output.pdf", signature_size: 10_000, external_signing: signing_proc)
      #
      # == Implementing a Signing Handler
      #
      # This class also serves as an example on how to create a custom handler: The public methods
      # #signature_size, #finalize_objects and #sign are used by the digital signature algorithm.
      # See their descriptions for details.
      #
      # Once a custom signing handler has been created, it can be registered under the
      # 'signature.signing_handler' configuration option for easy use. It has to take keyword
      # arguments in its initialize method to be compatible with the Signatures#handler method.
      class DefaultHandler

        # The certificate with which to sign the PDF.
        attr_accessor :certificate

        # The private key for the #certificate.
        attr_accessor :key

        # The certificate chain that should be embedded in the PDF; normally contains all
        # certificates up to the root certificate.
        attr_accessor :certificate_chain

        # A callable object fulfilling the same role as the #sign method that is used instead of the
        # default mechanism for signing.
        #
        # If this attribute is set, the attributes #certificate, #key and #certificate_chain are not
        # used.
        attr_accessor :external_signing

        # The reason for signing. If used, will be set on the signature object.
        attr_accessor :reason

        # The signing location. If used, will be set on the signature object.
        attr_accessor :location

        # The contact information. If used, will be set on the signature object.
        attr_accessor :contact_info

        # The size of the serialized signature that should be reserved.
        #
        # If this attribute has not been set, an empty string will be signed using #sign to
        # determine the signature size.
        #
        # The size needs to be at least as big as the final signature, otherwise signing results in
        # an error.
        attr_writer :signature_size

        # The type of signature to be written (i.e. the value of the /SubFilter key).
        #
        # The value can either be :adobe (the default; uses a detached PKCS7 signature) or :etsi
        # (uses an ETSI CAdES compatible signature).
        attr_accessor :signature_type

        # The DocMDP permissions that should be set on the document.
        #
        # See #doc_mdp_permissions=
        attr_reader :doc_mdp_permissions

        # Creates a new DefaultHandler with the given attributes.
        def initialize(**arguments)
          @signature_size = nil
          arguments.each {|name, value| send("#{name}=", value) }
        end

        # Sets the DocMDP permissions that should be applied to the document.
        #
        # Valid values for +permissions+ are:
        #
        # +nil+::
        #     Don't set any DocMDP permissions (default).
        #
        # +:no_changes+ or 1::
        #     No changes whatsoever are allowed.
        #
        # +:form_filling+ or 2::
        #     Only filling in forms and signing are allowed.
        #
        # +:form_filling_and_annotations+ or 3::
        #     Only filling in forms, signing and annotation creation/deletion/modification are
        #     allowed.
        def doc_mdp_permissions=(permissions)
          case permissions
          when :no_changes, 1 then @doc_mdp_permissions = 1
          when :form_filling, 2 then @doc_mdp_permissions = 2
          when :form_filling_and_annotations, 3 then @doc_mdp_permissions = 3
          when nil then @doc_mdp_permissions = nil
          else
            raise ArgumentError, "Invalid permissions value '#{permissions.inspect}'"
          end
        end

        # Returns the size of the serialized signature that should be reserved.
        #
        # If a custom size is set using #signature_size=, it used. Otherwise the size is determined
        # by using #sign to sign an empty string.
        def signature_size
          @signature_size || sign(StringIO.new, [0, 0, 0, 0]).size
        end

        # Finalizes the signature field as well as the signature dictionary before writing.
        def finalize_objects(_signature_field, signature)
          signature[:SubFilter] = :'ETSI.CAdES.detached' if signature_type == :etsi
          signature[:Reason] = reason if reason
          signature[:Location] = location if location
          signature[:ContactInfo] = contact_info if contact_info

          if doc_mdp_permissions
            doc = signature.document
            if doc.signatures.count > 1
              raise HexaPDF::Error, "Can set DocMDP access permissions only on first signature"
            end
            params = doc.add({Type: :TransformParams, V: :'1.2', P: doc_mdp_permissions})
            sigref = doc.add({Type: :SigRef, TransformMethod: :DocMDP, DigestMethod: :SHA1,
                              TransformParams: params})
            signature[:Reference] = [sigref]
            (doc.catalog[:Perms] ||= {})[:DocMDP] = signature
          end
        end

        # Returns the DER serialized OpenSSL::PKCS7 structure containing the signature for the given
        # IO byte ranges.
        #
        # The +byte_range+ argument is an array containing four numbers [offset1, length1, offset2,
        # length2]. The offset numbers are byte positions in the +io+ argument and the to-be-signed
        # data can be determined by reading length bytes at the offsets.
        def sign(io, byte_range)
          if external_signing
            external_signing.call(io, byte_range)
          else
            io.pos = byte_range[0]
            data = io.read(byte_range[1])
            io.pos = byte_range[2]
            data << io.read(byte_range[3])
            OpenSSL::PKCS7.sign(@certificate, @key, data, @certificate_chain,
                                OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY).to_der
          end
        end

      end

    end
  end
end
