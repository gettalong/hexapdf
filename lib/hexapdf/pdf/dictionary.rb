# -*- encoding: utf-8 -*-

require 'time'
require 'date'
require 'hexapdf/error'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/utils/pdf_doc_encoding'

module HexaPDF
  module PDF

    # Implementation of the PDF dictionary type.
    #
    # Subclasses should use the available class method ::define_field to create fields according to
    # the PDF specification. This allows, among other things, automatic type checking and
    # basic validation.
    #
    # Fields defined in superclasses are inherited by their subclasses. This avoids duplicating
    # basic field information.
    #
    # See: PDF1.7 s7.3.7
    class Dictionary < HexaPDF::PDF::Object

      # For easier defining boolean fields.
      Boolean = [TrueClass, FalseClass]

      # PDFByteString is used for defining fields with strings in binary encoding.
      PDFByteString = Class.new

      # PDFDate is used for defining fields which store a date object as a string.
      PDFDate = Class.new

      # A dictionary field entry. For information on the available accessor fields see
      # Dictionary.define_field.
      class Field

        # Returns +true+ if the value for this field needs to be an indirect object, +false+ if it
        # needs to be a direct object or +nil+ if it can be either.
        attr_reader :indirect

        # Returns the PDF version that is required for this field.
        attr_reader :version

        # Create a new Field object.
        def initialize(type, required, default, indirect, version)
          @type = [type].flatten
          @type_mapped = false
          @required, @default, @indirect, @version = required, default, indirect, version.to_sym
        end

        # Returns the array with valid types for this field.
        def type
          return @type if @type_mapped
          @type_mapped = true
          @type.map! {|type| type.kind_of?(String) ? ::Object.const_get(type) : type}
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

        # Always returns +false+.
        #
        # Can be used by subclasses to specify if the data value can be converted to a more specific
        # object.
        #
        # See: #convert
        def convert?(data)
          false
        end

        # Noop - just returns the data.
        #
        # Can be used by subclasses to convert the data to a more specific object.
        #
        # See: #convert?
        def convert(data, document)
          data
        end

      end

      # Special handling of fields of type Dictionary and its subclasses.
      class DictionaryField < Field

        # :nodoc:
        def initialize(*args)
          super
          @type << Hash
        end

        # Returns +true+ if the given data value can be converted to the Dictionary subclass
        # specified as the type of this field.
        def convert?(data)
          !data.kind_of?(type.first) && (data.nil? || data.kind_of?(Hash) ||
                                         data.kind_of?(HexaPDF::PDF::Dictionary))
        end

        # Wraps the given data value in the PDF specific type class of this field.
        def convert(data, document)
          document.wrap(data, type: type.first)
        end

      end

      # Special handling for string fields to automatically convert a string into UTF-8 encoding on
      # access.
      class StringField < Field

        # :nodoc:
        def initialize(*args)
          super
          @type << String unless @type.include?(String)
        end

        # Returns +true+ if the given data should be converted to a UTF-8 encoded string.
        def convert?(data)
          data.kind_of?(String) && data.encoding == Encoding::BINARY && type[0] != PDFByteString
        end

        # Converts the string into UTF-8 encoding, assuming it is currently a binary string.
        def convert(str, document)
          if str.getbyte(0) == 254 && str.getbyte(1) == 255
            str[2..-1].force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
          else
            Utils::PDFDocEncoding.convert_to_utf8(str)
          end
        end

      end

      # Special handling for PDF date fields since they are stored as strings.
      #
      # The ISO PDF specification differs in respect to the supported date format. When converting
      # from a date string to a Time object, this is taken into account.
      #
      # See: PDF1.7 s7.9.4, ADB1.7 3.8.3
      class DateField < Field

        # :nodoc:
        def initialize(*args)
          super
          @type << String << Time << Date << DateTime
        end

        # :nodoc:
        DATE_RE = /\AD:(\d{4})(\d\d)?(\d\d)?(\d\d)?(\d\d)?(\d\d)?([Z+-])?(?:(\d\d)')?(\d\d)?'?\z/n

        # Returns +true+ if the given data should be converted to a Time object.
        def convert?(data)
          data.kind_of?(String) && data.encoding == Encoding::BINARY &&
            data =~ DATE_RE
        end

        # Converts the string into a Time object.
        def convert(str, document)
          match = DATE_RE.match(str)
          utc_offset = (match[7].nil? || match[7] == 'Z' ? 0 : "#{match[7]}#{match[8]}:#{match[9]}")
          Time.new(match[1].to_i, (match[2] ? match[2].to_i : 1), (match[3] ? match[3].to_i : 1),
                   match[4].to_i, match[5].to_i, match[6].to_i, utc_offset)
        end

      end

      # Defines an entry for the field +name+.
      #
      # Options:
      #
      # type:: The class (or an array of classes) that a value of this field must have. Here is a
      #        mapping from PDF object types to classes:
      #
      #        Boolean::    [TrueClass, FalseClass] (or use the Boolean constant)
      #        Integer::    Integer
      #        Real::       Float
      #        String::     String (for text strings), PDFByteString (for binary strings)
      #        Date::       PDFDate
      #        Name::       Symbol
      #        Array::      Array
      #        Dictionary:: Dictionary (or any subclass) or Hash
      #        Stream::     Stream (or any subclass)
      #        Null::       NilClass
      #
      #        If an array of classes is provided, the value can be an instance of any of these
      #        classes.
      #
      #        If a String object instead of a class is provided, the class is looked up when
      #        necessary to support lazy loading. This should only be done for Dictionary
      #        subclasses.
      #
      # required:: Specifies whether this field is required.
      #
      # default:: Specifies the default value for the field, if any.
      #
      # indirect:: Specifies whether the value (or the values in the array value) of this field has
      #            to be an indirect object (+true+), a direct object (+false+) or if it doesn't
      #            matter (unspecified or +nil+).
      #
      # version:: Specifies the minimum version of the PDF specification needed for this value.
      def self.define_field(name, type:, required: false, default: nil, indirect: nil,
                            version: '1.2')
        @fields ||= {}
        klass = if type.kind_of?(String) ||
                    (type.respond_to?(:ancestors) && type.ancestors.include?(HexaPDF::PDF::Dictionary))
                  DictionaryField
                elsif type == String || type == PDFByteString
                  StringField
                elsif type == PDFDate
                  DateField
                else
                  Field
                end
        @fields[name] = klass.new(type, required, default, indirect, version)
      end

      # Returns the field entry for the given field name.
      #
      # The ancestor classes are also searched for such a field entry if none is found for the
      # current class.
      def self.field(name)
        if defined?(@fields) && @fields.key?(name)
          @fields[name]
        elsif superclass.respond_to?(:field)
          superclass.field(name)
        end
      end

      # :call-seq:
      #   class.each_field {|name, data| block }   -> class
      #   class.each_field                         -> Enumerator
      #
      # Calls the block once for each field defined either in this class or in one of the ancestor
      # classes.
      def self.each_field(&block) # :yields: name, data
        return to_enum(__method__) unless block_given?
        superclass.each_field(&block) if self != Dictionary && superclass != Dictionary
        @fields.each(&block) if defined?(@fields)
      end


      define_validator(:validate_fields)


      # Sets the value and makes sure that it is a Hash.
      def value=(value) # :nodoc:
        super(value || {})
        unless self.value.kind_of?(Hash)
          raise HexaPDF::Error, "A PDF dictionary object needs a hash value, not a #{value.class}"
        end
      end

      # Returns the value for the given dictionary entry.
      #
      # This method should be used instead of direct access to the value because it provides
      # numerous advantages:
      #
      # * References are automatically resolved.
      #
      # * Returns the native Ruby object for values with class HexaPDF::PDF::Object. However, all
      #   subclasses of HexaPDF::PDF::Object are returned as is (it makes no sense, for example, to
      #   return the hash that describes the Catalog instead of the Catalog object).
      #
      # * Automatically wraps unset or hash values in specific subclasses of this class if field
      #   information is available (see ::define_field).
      #
      # * Returns the default value if one is specified and no value is available.
      def [](name)
        field = self.class.field(name)
        data = if value.key?(name)
                 document.deref(value[name])
               elsif field && field.default?
                 value[name] = field.default
               end

        if field && field.convert?(data)
          value[name] = data = field.convert(data, document)
        elsif data.class == HexaPDF::PDF::Object
          data = data.value
        end

        data
      end

      # Stores the data under name in the dictionary. Name has to be a Symbol object.
      #
      # If the current value for this name has the class HexaPDF::PDF::Object (and only this, no
      # subclasses) and the given value has not (including subclasses), the value is stored inside
      # the HexaPDF::PDF::Object.
      def []=(name, data)
        unless name.kind_of?(Symbol)
          raise HexaPDF::Error, "Only Symbol (Name) keys are allowed to be used in PDF dictionaries"
        end

        if value[name].class == HexaPDF::PDF::Object && !data.kind_of?(HexaPDF::PDF::Object)
          value[name].value = data
        else
          value[name] = data
        end
      end

      # Deletes the name-value pair from the dictionary and returns the value. If such a pair does
      # not exist, +nil+ is returned.
      def delete(name)
        value.delete(name) { nil }
      end

      # Returns a dup of the underlying hash.
      def to_hash
        value.dup
      end
      alias :to_h :to_hash


      private


      # Performs validation tasks based on the defined fields.
      #
      # See: Object#validate for information on the available arguments.
      def validate_fields
        if (type_field = self.class.field(:Type)) && type_field.required? && type_field.default?
          self[:Type] = type_field.default
        end

        self.class.each_field do |name, field|
          obj = value.key?(name) && document.deref(value[name]) || nil

          # Check that required fields are set
          if field.required? && obj.nil?
            yield("Required field #{name} is not set", field.default?)
            self[name] = obj = field.default
          end

          # Check the type of the field
          if !obj.nil? && !field.valid_object?(obj)
            yield("Type of field #{name} is invalid", false)
          end

          # Check if field value needs to be (in)direct
          if !obj.nil? && !field.indirect.nil?
            if field.indirect && (!obj.kind_of?(HexaPDF::PDF::Object) || obj.oid == 0)
              yield("Field #{name} needs to be an indirect object", true)
              value[name] = obj = document.add(obj)
            elsif !field.indirect && obj.kind_of?(HexaPDF::PDF::Object) && obj.oid != 0
              yield("Field #{name} needs to be an direct object", true)
              document.delete(obj)
              value[name] = obj = obj.value
            end
          end
        end

        true
      end

    end

  end
end
