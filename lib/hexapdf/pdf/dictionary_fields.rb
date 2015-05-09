# -*- encoding: utf-8 -*-

require 'time'
require 'date'
require 'hexapdf/pdf/utils/pdf_doc_encoding'

module HexaPDF
  module PDF

    # A mixin used by Dictionary that implements the infrastructure and classes for defining fields.
    module DictionaryFields

      # For easier defining boolean fields.
      Boolean = [TrueClass, FalseClass]

      # PDFByteString is used for defining fields with strings in binary encoding.
      PDFByteString = Class.new

      # PDFDate is used for defining fields which store a date object as a string.
      PDFDate = Class.new

      # A dictionary field entry.
      class Field

        # Returns +true+ if the value for this field needs to be an indirect object, +false+ if it
        # needs to be a direct object or +nil+ if it can be either.
        attr_reader :indirect

        # Returns the PDF version that is required for this field.
        attr_reader :version

        # Associates a converter module with the field.
        attr_accessor :converter

        # Create a new Field object. See Dictionary::define_field for information on the arguments.
        def initialize(type, required, default, indirect, version)
          @type = [type].flatten
          @type_mapped = false
          @required, @default, @indirect, @version = required, default, indirect, version
          @converter = IdentityConverter
        end

        # Returns the array with valid types for this field.
        def type
          return @type if @type_mapped
          @type_mapped = true
          @type.concat(Array(converter.additional_types)) if converter
          @type.map! {|type| type.kind_of?(String) ? ::Object.const_get(type) : type}
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

        # A list of classes whose objects cannot be duplicated
        NOT_DUPLICATABLE_CLASSES = [NilClass, FalseClass, TrueClass, Symbol, Integer, Fixnum, Float]

        # Returns +true+ if the default value can safely be duplicated with #dup.
        def duplicatable_default?
          @cached_dupdefault ||= NOT_DUPLICATABLE_CLASSES.none? do |klass|
            @default.kind_of?(klass)
          end
        end
        private :duplicatable_default?

        # Returns +true+ if the given object is valid for this field.
        def valid_object?(obj)
          type.any? {|t| obj.kind_of?(t)} ||
            (obj.kind_of?(HexaPDF::PDF::Object) && type.any? {|t| obj.value.kind_of?(t)})
        end

        # If a converter was defined, it is used. Otherwise +false+ is returned.
        #
        # See: #convert
        def convert?(data)
          converter.convert?(data, type)
        end

        # If a converter was defined, it is used for converting the data. Otherwise this is a Noop -
        # it just returns the data.
        #
        # See: #convert?
        def convert(data, document)
          converter.convert(data, type, document)
        end

      end

      # Does nothing.
      module IdentityConverter

        def self.additional_types #:nodoc:
          []
        end

        def self.convert?(data, type) #:nodoc:
          false
        end

        def self.convert(data, type, document) #:nodoc:
          data
        end

      end

      # Converter module for fields of type Dictionary and its subclasses. The first class in the
      # type array of the field is used for the conversion.
      module DictionaryConverter

        # Dictionary fields can also contain simple hashes.
        def self.additional_types
          Hash
        end

        # Returns +true+ if the given data value can be converted to the Dictionary subclass
        # specified by type (see Field#type).
        def self.convert?(data, type)
          !data.kind_of?(type.first) && (data.nil? || data.kind_of?(Hash) ||
                                         data.kind_of?(HexaPDF::PDF::Dictionary))
        end

        # Wraps the given data value in the PDF specific type class.
        def self.convert(data, type, document)
          document.wrap(data, type: type.first)
        end

      end

      # Converter module for string fields to automatically convert a string into UTF-8 encoding on
      # access. This is only done if the first class in the type array of the field is not
      # PDFByteString which represents a binary string.
      module StringConverter

        # :nodoc:
        def self.additional_types
          String
        end

        # Returns +true+ if the given data should be converted to a UTF-8 encoded string.
        def self.convert?(data, type)
          data.kind_of?(String) && data.encoding == Encoding::BINARY && type[0] != PDFByteString
        end

        # Converts the string into UTF-8 encoding, assuming it is currently a binary string.
        def self.convert(str, type, document)
          if str.getbyte(0) == 254 && str.getbyte(1) == 255
            str[2..-1].force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
          else
            Utils::PDFDocEncoding.convert_to_utf8(str)
          end
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

        # A date field may contain a string in PDF format, or a Time, Date or DateTime object.
        def self.additional_types
          [String, Time, Date, DateTime]
        end

        # :nodoc:
        DATE_RE = /\AD:(\d{4})(\d\d)?(\d\d)?(\d\d)?(\d\d)?(\d\d)?([Z+-])?(?:(\d\d)')?(\d\d)?'?\z/n

        # Returns +true+ if the given data should be converted to a Time object.
        def self.convert?(data, type)
          data.kind_of?(String) && data.encoding == Encoding::BINARY &&
            data =~ DATE_RE
        end

        # Converts the string into a Time object.
        def self.convert(str, type, document)
          match = DATE_RE.match(str)
          utc_offset = (match[7].nil? || match[7] == 'Z' ? 0 : "#{match[7]}#{match[8]}:#{match[9]}")
          Time.new(match[1].to_i, (match[2] ? match[2].to_i : 1), (match[3] ? match[3].to_i : 1),
                   match[4].to_i, match[5].to_i, match[6].to_i, utc_offset)
        end

      end

    end

  end
end
