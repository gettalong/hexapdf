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
require 'net/http'
require 'hexapdf/error'
require 'stringio'

module HexaPDF
  class Document

    # This class provides methods for interacting with digital signatures of a PDF file.
    class Signatures

      # This is the default signing handler which provides the ability to sign a document with the
      # adbe.pkcs7.detached or ETSI.CAdES.detached algorithms.
      #
      # There are two ways to create the necessary PKCS#7 structure:
      #
      # * By providing the signing certificate together with the signing key and the certificate
      #   chain. This way HexaPDF itself does the signing. It is the preferred way if all the needed
      #   information is available.
      #
      #   Assign the respective data to the #certificate, #key and #certificate_chain attributes.
      #
      # * By using an external signing mechanism. Here the actual signing happens "outside" of
      #   HexaPDF, for example, in custom code or even asynchronously. This is needed in case the
      #   signing certificate plus key are not available but only an interface to them (e.g. when
      #   dealing with a HSM).
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
      # == Implementing a Signing Handler
      #
      # This class also serves as an example on how to create a custom handler: The public methods
      # #signature_size, #finalize_objects and #sign are used by the digital signature algorithm.
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

        # The binary size of the signature.
        #
        # If this attribute has not been set, an empty string will be signed using #sign to
        # determine the signature size.
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

        # Returns the size of the signature that would be created.
        #
        # The size is determined by using #sign to sign an empty string.
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
        def sign(io, byte_range)
          if @external_signing
            @external_signing.call(io, byte_range)
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

      # This is a signing handler for adding a timestamp signature (a PDF2.0 feature) to a PDF
      # document.
      #
      # The timestamp is provided by a timestamp authority and establishes the document contents at
      # the time indicated in the timestamp. Timestamping a PDF document is usually done in context
      # of long term validation but can also be done standalone.
      #
      # One has to provide at least the URL of the timestamp authority server (TSA), everything else
      # is optional and uses default values. The TSA server must not use authentication to be
      # usable.
      class TimestampHandler

        # The URL of the timestamp authority server.
        attr_accessor :tsa_url

        # The hash algorithm to use for timestamping. Defaults to SHA512.
        attr_accessor :tsa_hash_algorithm

        # The policy OID to use for timestamping. Defaults to +nil+.
        attr_accessor :tsa_policy_id

        # The binary size of the signature.
        #
        # If this attribute has not been set, an empty string will be signed using #sign to
        # determine the signature size which will contact the TSA server.
        attr_writer :signature_size

        # The reason for timestamping. If used, will be set on the signature object.
        attr_accessor :reason

        # The timestamping location. If used, will be set on the signature object.
        attr_accessor :location

        # The contact information. If used, will be set on the signature object.
        attr_accessor :contact_info

        # Creates a new TimestampHandler with the given attributes.
        def initialize(**arguments)
          arguments.each {|name, value| send("#{name}=", value) }
        end

        # Returns the size of the signature that would be created.
        def signature_size
          @signature_size || (sign(StringIO.new, [0, 0, 0, 0]).size * 1.5).to_i
        end

        # Finalizes the signature field as well as the signature dictionary before writing.
        def finalize_objects(_signature_field, signature)
          signature.document.version = '2.0'
          signature[:Type] = :DocTimeStamp
          signature[:SubFilter] = :'ETSI.RFC3161'
          signature[:Reason] = reason if reason
          signature[:Location] = location if location
          signature[:ContactInfo] = contact_info if contact_info
        end

        # Returns the DER serialized OpenSSL::PKCS7 structure containing the timestamp token for the
        # given IO byte ranges.
        def sign(io, byte_range)
          hash_algorithm = tsa_hash_algorithm || 'SHA512'
          digest = OpenSSL::Digest.new(hash_algorithm)
          io.pos = byte_range[0]
          digest << io.read(byte_range[1])
          io.pos = byte_range[2]
          digest << io.read(byte_range[3])

          req = OpenSSL::Timestamp::Request.new
          req.algorithm = hash_algorithm
          req.message_imprint = digest.digest
          req.policy_id = tsa_policy_id if tsa_policy_id

          http_response = Net::HTTP.post(URI(tsa_url), req.to_der,
                                         'content-type' => 'application/timestamp-query')
          if http_response.kind_of?(Net::HTTPOK)
            response = OpenSSL::Timestamp::Response.new(http_response.body)
            if response.status == 0
              response.token.to_der
            else
              raise HexaPDF::Error, "Timestamp token could not be created: #{response.failure_info}"
            end
          else
            raise HexaPDF::Error, "Invalid TSA server response: #{http_response.body}"
          end
        end

      end

      include Enumerable

      # Creates a new Signatures object for the given PDF document.
      def initialize(document)
        @document = document
      end

      # Creates a signing handler with the given options and returns it.
      #
      # A signing handler name is mapped to a class via the 'signature.signing_handler'
      # configuration option. The default signing handler is DefaultHandler.
      def handler(name: :default, **options)
        handler = @document.config.constantize('signature.signing_handler', name) do
          raise HexaPDF::Error, "No signing handler named '#{name}' is available"
        end
        handler.new(**options)
      end

      # Adds a signature to the document and returns the corresponding signature object.
      #
      # This method will add a new signature to the document and write the updated document to the
      # given file or IO stream. Afterwards the document can't be modified anymore and still retain
      # a correct digital signature. To modify the signed document (e.g. for adding another
      # signature) create a new document based on the given file or IO stream instead.
      #
      # +signature+::
      #     Can either be a signature object (determined via the /Type key), a signature field or
      #     +nil+. Providing a signature object or signature field provides for more control, e.g.:
      #
      #     * Setting values for optional signature object fields like /Reason and /Location.
      #     * (In)directly specifying which signature field should be used.
      #
      #     If a signature object is provided and it is not associated with an AcroForm signature
      #     field, a new signature field is created and added to the main AcroForm object, creating
      #     that if necessary.
      #
      #     If a signature field is provided and it already has a signature object as field value,
      #     that signature object is discarded.
      #
      #     If the signature field doesn't have a widget, a non-visible one is created on the first
      #     page.
      #
      # +handler+::
      #     The signing handler that provides the necessary methods for signing and adjusting the
      #     signature and signature field objects to one's liking, see #handler and DefaultHandler.
      #
      # +write_options+::
      #     The key-value pairs of this hash will be passed on to the HexaPDF::Document#write
      #     command. Note that +incremental+ will be automatically set if signing an already
      #     existing file.
      #
      # The used signature object will have the following default values set:
      #
      # /Filter::    /Adobe.PPKLite
      # /SubFilter:: /adbe.pkcs7.detached
      # /M::         The current time.
      #
      # These values can be overridden in the #finalize_objects method of the signature handler.
      def add(file_or_io, handler, signature: nil, write_options: {})
        if signature && signature.type != :Sig
          signature_field = signature
          signature = signature_field.field_value
        end
        signature ||= @document.add({Type: :Sig})

        # Prepare AcroForm
        form = @document.acro_form(create: true)
        form.signature_flag(:signatures_exist, :append_only)

        # Prepare signature field
        signature_field ||= form.each_field.find {|field| field.field_value == signature } ||
          form.create_signature_field(generate_field_name)
        signature_field.field_value = signature

        if signature_field.each_widget.to_a.empty?
          signature_field.create_widget(@document.pages[0], Rect: [0, 0, 0, 0])
        end

        # Prepare signature object
        signature[:Filter] = :'Adobe.PPKLite'
        signature[:SubFilter] = :'adbe.pkcs7.detached'
        signature[:M] = Time.now
        handler.finalize_objects(signature_field, signature)
        signature[:ByteRange] = [0, 1_000_000_000_000, 1_000_000_000_000, 1_000_000_000_000]
        signature[:Contents] = '00' * handler.signature_size # twice the size due to hex encoding

        io = if file_or_io.kind_of?(String)
               File.open(file_or_io, 'wb+')
             else
               file_or_io
             end

        # Save the current state so that we can determine the correct /ByteRange value and set the
        # values
        start_xref_position, section = @document.write(io, incremental: true, **write_options)
        data = section.map {|oid, _gen, entry| [entry.pos, oid] if entry.in_use? }.compact.sort <<
          [start_xref_position, nil]
        index = data.index {|_pos, oid| oid == signature.oid }
        signature_offset = data[index][0]
        signature_length = data[index + 1][0] - data[index][0]
        io.pos = signature_offset
        signature_data = io.read(signature_length)

        io.seek(0, IO::SEEK_END)
        file_size = io.pos

        # Calculate the offsets for the /ByteRange
        contents_offset = signature_offset + signature_data.index('Contents(') + 8
        offset2 = contents_offset + signature[:Contents].size + 2 # +2 because of the needed < and >
        length2 = file_size - offset2
        signature[:ByteRange] = [0, contents_offset, offset2, length2]

        # Set the correct /ByteRange value
        signature_data.sub!(/ByteRange\[0 1000000000000 1000000000000 1000000000000\]/) do |match|
          length = match.size
          result = "ByteRange[0 #{contents_offset} #{offset2} #{length2}]"
          result.ljust(length)
        end

        # Now everything besides the /Contents value is correct, so we can read the contents for
        # signing
        io.pos = signature_offset
        io.write(signature_data)
        signature[:Contents] = handler.sign(io, signature[:ByteRange].value)

        # Set the correct /Contents value as hexstring
        signature_data.sub!(/Contents\(0+\)/) do |match|
          length = match.size
          result = "Contents<#{signature[:Contents].unpack1('H*')}"
          if length < result.size
            raise HexaPDF::Error, "The reserved space for the signature was too small " \
              "(#{(length - 10) / 2} vs #{(result.size - 10) / 2}) - use the handlers " \
              "#signature_size method to increase the reserved space"
          end
          "#{result.ljust(length - 1, '0')}>"
        end

        io.pos = signature_offset
        io.write(signature_data)

        signature
      ensure
        io.close if io && io != file_or_io
      end

      # :call-seq:
      #   signatures.each {|signature| block }   -> signatures
      #   signatures.each                        -> Enumerator
      #
      # Iterates over all signatures in the order they are found.
      def each
        return to_enum(__method__) unless block_given?

        return [] unless (form = @document.acro_form)
        form.each_field do |field|
          yield(field.field_value) if field.field_type == :Sig && field.field_value
        end
      end

      # Returns the number of signatures in the PDF document. May be zero if the document has no
      # signatures.
      def count
        each.to_a.size
      end

      private

      # Generates a field name for a signature field.
      def generate_field_name
        index = (@document.acro_form.each_field.
                 map {|field| field.full_field_name.scan(/\ASignature(\d+)/).first&.first.to_i }.
                 max || 0) + 1
        "Signature#{index}"
      end

    end

  end
end
