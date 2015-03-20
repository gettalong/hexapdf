# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/object'

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
          @types_mapped = false
          @required, @default, @indirect, @version = required, default, indirect, version.to_sym
        end

        # Returns the array with possible types for this field.
        def type
          return @type if @types_mapped
          @types_mapped = true
          @type.map! {|type| type.kind_of?(String) ? ::Object.const_get(type) : type}
          @type << Hash if @type.any? {|type| type.ancestors.include?(Dictionary)}
          @type
        end

        # Returns +true+ if this field is required.
        def required?
          @required
        end

        # Returns +true+ if a default value is set.
        def default?
          !@default.nil?
        end

        # Returns the duplicated default value, automatically taking unduplicatable classes into
        # account.
        def dupped_default
          duplicatable_default? ? @default.dup : @default
        end

        # Returns +true+ if the default value can safely be duplicated with #dup.
        def duplicatable_default?
          @cached_dupdefault ||= [NilClass, FalseClass, TrueClass, Symbol, Integer, Fixnum, Float].none? do |klass|
            @default.kind_of?(klass)
          end
        end
        private :duplicatable_default?

        # Returns +true+ if the given data value should be wrapped in the PDF specific type class of
        # this field entry.
        def wrap_data_with_type?(data)
          @cached_wrapable ||= (type.size == 2 && type[1] == Hash && type[0].ancestors.include?(HexaPDF::PDF::Dictionary))
          @cached_wrapable && (data.nil? || data.kind_of?(Hash))
        end

        # Wraps the given data value in the PDF specific type class of this field entry.
        def wrap_data_with_type(data, document)
          type.first.new(data, document: document)
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
      #        String::     String
      #        Name::       Symbol
      #        Array::      Array
      #        Dictionary:: Dictionary (or any subclass)
      #        Stream::     Stream (or any subclass)
      #        Null::       NilClass
      #
      #        If an array of classes is provided, the value can be an instance of any of these
      #        classes.
      #
      #        For the automatic mapping of a raw value to a specific Dictionary subclass, this
      #        subclass must be the only item or the first item in an array.
      #
      #        If a String object is provided, the class is looked up when necessary to support lazy
      #        loading.
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
      def self.define_field(name, type:, required: false, default: nil, indirect: nil, version: '1.2')
        @fields ||= {}
        @fields[name] = Field.new([type].flatten, required, default, indirect, version)
      end

      # Returns the field entry for the given field name.
      #
      # The ancestor classes are also searched for such a field entry if none is found for the
      # current class.
      def self.field(name)
        if defined?(@fields) && @fields.key?(name)
          @fields[name]
        elsif superclass != Dictionary
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
        superclass.each_field(&block) if superclass != Dictionary
        @fields.each(&block) if defined?(@fields)
      end

      # Creates a new Dictionary object.
      def initialize(value, **kwargs)
        value ||= {}
        unless value.kind_of?(Hash)
          raise HexaPDF::Error, "A PDF dictionary object needs a hash value, not a #{value.class}"
        end
        super
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
                 value[name] = field.dupped_default
               end

        if field && field.wrap_data_with_type?(data)
          value[name] = data = field.wrap_data_with_type(data, document)
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

      # Returns a dup of the underlying hash.
      def to_hash
        value.dup
      end
      alias :to_h :to_hash

    end

  end
end
