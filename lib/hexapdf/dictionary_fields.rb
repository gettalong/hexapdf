# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2018 Thomas Leitner
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
#++

require 'time'
require 'date'
require 'hexapdf/object'
require 'hexapdf/rectangle'
require 'hexapdf/configuration'
require 'hexapdf/utils/pdf_doc_encoding'

module HexaPDF

  # A mixin used by Dictionary that implements the infrastructure and classes for defining fields.
  #
  # The class responsible for holding the field information is the Field class. Additionally, each
  # field object is automatically assigned a stateless converter object that knows if data read
  # from a PDF file potentially needs to be converted into a standard format before use.
  #
  # The methods that need to be implemented by such stateless converter objects are:
  #
  # usable_for?(type)::
  #   Should return +true+ if the converter is usable for the given type.
  #
  # additional_types::
  #   Should return +nil+, a single type class or an array of type classes which will additionally
  #   be allowed for the field.
  #
  # convert?(data, type)::
  #   Should return +true+ if the given +data+ object can be converted. The +type+ argument is the
  #   result of the Field#type method call.
  #
  # convert(data, type, document)::
  #   Should return the +converted+ data. The +type+ argument is the result of the Field#type method
  #   call and +document+ is the HexaPDF::Document for which the data should be converted.
  module DictionaryFields

    # This constant should *always* be used for boolean fields.
    Boolean = [TrueClass, FalseClass].freeze

    # PDFByteString is used for defining fields with strings in binary encoding.
    PDFByteString = Class.new { private_class_method :new }

    # PDFDate is used for defining fields which store a date object as a string.
    PDFDate = Class.new { private_class_method :new }

    # A dictionary field contains information about one field of a structured PDF object and this
    # information comes directly from the PDF specification.
    #
    # By incorporating this field information into HexaPDF it is possible to do many things
    # automatically, like checking for the correct minimum PDF version to use or converting a date
    # from its string representation to a Time object.
    class Field

      # Returns the list of available converter objects.
      #
      # See ::converter_for for information on how this list is used.
      def self.converters
        @converters ||= []
      end

      # Returns the converter for the given +type+ specification.
      #
      # The converter list is checked for a suitable converter from the front to the back. So if
      # two converters could potentially be used for the same type, the one that appears earlier
      # is used.
      def self.converter_for(type)
        @converters.find {|converter| converter.usable_for?(type) }
      end

      # Returns +true+ if the value for this field needs to be an indirect object, +false+ if it
      # needs to be a direct object or +nil+ if it can be either.
      attr_reader :indirect

      # Returns the PDF version that is required for this field.
      attr_reader :version

      # Create a new Field object. See Dictionary::define_field for information on the arguments.
      #
      # Depending on the +type+ entry an appropriate field converter object is chosen from the
      # available converters.
      def initialize(type, required = false, default = nil, indirect = nil, version = nil)
        @type = [type].flatten
        @type_mapped = false
        @required, @default, @indirect, @version = required, default, indirect, version
        @converter = self.class.converter_for(type)
      end

      # Returns the array with valid types for this field.
      def type
        return @type if @type_mapped
        @type_mapped = true
        @type.concat(Array(@converter.additional_types))
        @type.map! do |type|
          if type.kind_of?(Symbol)
            HexaPDF::GlobalConfiguration.constantize('object.type_map', type)
          else
            type
          end
        end
        @type.uniq!
        @type
      end

      # Returns +true+ if this field is required.
      def required?
        @required
      end

      # Returns +true+ if a default value is available.
      def default?
        !@default.nil?
      end

      # Returns a duplicated default value, automatically taking unduplicatable classes into
      # account.
      def default
        duplicatable_default? ? @default.dup : @default
      end

      # Returns +true+ if the default value can safely be duplicated with #dup.
      def duplicatable_default?
        @cached_dupdefault ||= HexaPDF::Object::NOT_DUPLICATABLE_CLASSES.none? do |klass|
          @default.kind_of?(klass)
        end
      end
      private :duplicatable_default?

      # Returns +true+ if the given object is valid for this field.
      def valid_object?(obj)
        type.any? {|t| obj.kind_of?(t) } ||
          (obj.kind_of?(HexaPDF::Object) && type.any? {|t| obj.value.kind_of?(t) })
      end

      # If a converter was defined, it is used. Otherwise +false+ is returned.
      #
      # See: #convert
      def convert?(data)
        @converter.convert?(data, type)
      end

      # If a converter was defined, it is used for converting the data. Otherwise this is a Noop -
      # it just returns the data.
      #
      # See: #convert?
      def convert(data, document)
        @converter.convert(data, type, document)
      end

    end

    # Does nothing.
    module IdentityConverter

      def self.usable_for?(_type) #:nodoc:
        true
      end

      def self.additional_types #:nodoc:
      end

      def self.convert?(_data, _type) #:nodoc:
        false
      end

      def self.convert(data, _type, _document) #:nodoc:
        data
      end

    end

    # Converter module for fields of type Dictionary and its subclasses. The first class in the
    # type array of the field is used for the conversion.
    module DictionaryConverter

      # This converter is used when either a Symbol is provided as +type+ (for lazy loading) or
      # when the type is a class derived from the Dictionary class.
      def self.usable_for?(type)
        type.kind_of?(Symbol) ||
          (type.respond_to?(:ancestors) && type.ancestors.include?(HexaPDF::Dictionary))
      end

      # Dictionary fields can also contain simple hashes.
      def self.additional_types
        Hash
      end

      # Returns +true+ if the given data value can be converted to the Dictionary subclass
      # specified by type (see Field#type).
      def self.convert?(data, type)
        !data.kind_of?(type.first) && (data.kind_of?(Hash) ||
          data.kind_of?(HexaPDF::Dictionary))
      end

      # Wraps the given data value in the PDF specific type class.
      def self.convert(data, type, document)
        document.wrap(data, type: type.first)
      end

    end

    # Converter module for string fields to automatically convert a string into UTF-8 encoding.
    module StringConverter

      # This converter is usable if the +type+ is the String class.
      def self.usable_for?(type)
        type == String
      end

      # :nodoc:
      def self.additional_types
      end

      # Returns +true+ if the given data should be converted to a UTF-8 encoded string.
      def self.convert?(data, _type)
        data.kind_of?(String) && data.encoding == Encoding::BINARY
      end

      # Converts the string into UTF-8 encoding, assuming it is currently a binary string.
      def self.convert(str, _type, _document)
        if str.getbyte(0) == 254 && str.getbyte(1) == 255
          str[2..-1].force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
        else
          Utils::PDFDocEncoding.convert_to_utf8(str)
        end
      end

    end

    # Converter module for binary string fields to automatically convert a string into binary
    # encoding.
    module PDFByteStringConverter

      # This converter is usable if the +type+ is PDFByteString.
      def self.usable_for?(type)
        type == PDFByteString
      end

      # :nodoc:
      def self.additional_types
        String
      end

      # Returns +true+ if the given data should be converted to a UTF-8 encoded string.
      def self.convert?(data, _type)
        data.kind_of?(String) && data.encoding != Encoding::BINARY
      end

      # Converts the string into UTF-8 encoding, assuming it is currently a binary string.
      def self.convert(str, _type, _document)
        str.force_encoding(Encoding::BINARY)
      end

    end

    # Converter module for handling PDF date fields since they are stored as strings.
    #
    # The ISO PDF specification differs from Adobe's specification in respect to the supported
    # date format. When converting from a date string to a Time object, this is taken into
    # account.
    #
    # See: PDF1.7 s7.9.4, ADB1.7 3.8.3
    module DateConverter

      # This converter is usable if the +type+ is PDFDate.
      def self.usable_for?(type)
        type == PDFDate
      end

      # A date field may contain a string in PDF format, or a Time, Date or DateTime object.
      def self.additional_types
        [String, Time, Date, DateTime]
      end

      # :nodoc:
      DATE_RE = /\AD:(\d{4})(\d\d)?(\d\d)?(\d\d)?(\d\d)?(\d\d)?([Z+-])?(?:(\d\d)(?:'|'(\d\d)'?|\z)?)?\z/n

      # Returns +true+ if the given data should be converted to a Time object.
      def self.convert?(data, _type)
        data.kind_of?(String) && data.match?(DATE_RE)
      end

      # Converts the string into a Time object.
      def self.convert(str, _type, _document)
        m = DATE_RE.match(str)
        utc_offset = (m[7].nil? || m[7] == 'Z' ? 0 : "#{m[7]}#{m[8]}:#{m[9] || '00'}")
        Time.new(m[1].to_i, (m[2] ? m[2].to_i : 1), (m[3] ? m[3].to_i : 1),
                 m[4].to_i, m[5].to_i, m[6].to_i, utc_offset)
      end

    end

    # Converter module for file specification fields. A file specification in string format is
    # converted to the corresponding file specification dictionary.
    module FileSpecificationConverter

      # This converter is only used for the :Filespec type.
      def self.usable_for?(type)
        type == :Filespec
      end

      # Filespecs can also be simple hashes or strings.
      def self.additional_types
        [Hash, String]
      end

      # Returns +true+ if the given data is a string file specification.
      def self.convert?(data, type)
        !data.kind_of?(type.first) &&
          (data.kind_of?(Hash) || data.kind_of?(HexaPDF::Dictionary) || data.kind_of?(String))
      end

      # Converts a string file specification or a hash into a full file specification.
      def self.convert(data, type, document)
        data = {F: data} if data.kind_of?(String)
        document.wrap(data, type: type.first)
      end

    end

    # Converter module for fields of type Rectangle.
    module RectangleConverter

      # This converter is usable if the +type+ is Rectangle.
      def self.usable_for?(type)
        type == Rectangle
      end

      # Rectangle fields can also contain simple arrays.
      def self.additional_types
        Array
      end

      # Returns +true+ if the given data value is an Array.
      def self.convert?(data, _type)
        data.kind_of?(Array)
      end

      # Wraps the given data value in the Rectangle class.
      def self.convert(data, _type, document)
        document.wrap(data, type: Rectangle)
      end

    end

    Field.converters.replace([FileSpecificationConverter, DictionaryConverter, StringConverter,
                              PDFByteStringConverter, DateConverter, RectangleConverter,
                              IdentityConverter])

  end

end
