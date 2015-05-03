# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/reference'
require 'hexapdf/error'

module HexaPDF
  module PDF

    # Objects of the PDF object system.
    #
    # == Overview
    #
    # A PDF object is like a normal object but with an additional *object identifier* consisting of
    # an object number and a generation number. If the object number is zero, then the PDF object
    # represents a direct object. Otherwise the object identifier uniquely identifies this object as
    # an indirect object and can be used for referencing it (from possibly multiple places).
    #
    # A PDF object *should* be connected to a PDF document, otherwise some methods may not work.
    #
    # Most PDF objects in a PDF document are represented by subclasses of this class that provide
    # additional functionality.
    #
    # See: Dictionary, Stream, Reference, Document
    # See: PDF1.7 s7.3.10, s7.3.8
    class Object

      include ReferenceBehavior

      # :call-seq:
      #   define_validator(method_name)
      #   define_validator {|obj, &callback| block }
      #
      # Defines a validator that checks whether some property of an object is valid or invalid.
      #
      # If a method name is given, the instance method with this name is used for validation.
      # Otherwise a block that takes the object for validation needs to be specified. Regardless of
      # how the validator is defined, it needs to accept a block.
      #
      # When the validator finds that the object is invalid, it has to yield a problem description
      # and whether the problem can be corrected. After yielding the problem has to be corrected
      # which poses no problem because the #validate method makes sure that the yield only returns
      # if the problem is actually correctable and if it should be corrected.
      #
      # Here is a sample validator for stream objects:
      #
      #   define_validator(:sample_validation)
      #
      #   def sample_validation
      #     unless value.kind_of?(Hash)
      #       yield("A stream object needs a Hash as value")
      #       self.value = {}
      #     end
      #   end
      #
      # And the same validator implemented using a block:
      #
      #   define_validator do |obj, &block|
      #     unless obj.value.kind_of?(Hash)
      #       block.call("A stream object needs a Hash as value")
      #       obj.value = {}
      #     end
      #   end
      #
      # See #validate for more information.
      def self.define_validator(method_name = nil, &block)
        @validators ||= []
        @validators << (method_name || block)
      end

      # :call-seq:
      #   class.each_validator {|validator| block }   -> class
      #   class.each_validator                        -> Enumerator
      #
      # Calls the block once for all validators registered for this PDF type or one of its
      # superclasses.
      def self.each_validator(&block) # :yields: method_name or block
        return to_enum(__method__) unless block_given?
        superclass.each_validator(&block) if superclass != ::Object
        @validators.each(&block) if defined?(@validators)
      end

      define_validator(:validate_must_be_indirect)

      # The wrapped object.
      attr_reader :value

      # Sets the associated PDF document.
      attr_writer :document

      # Sets whether the object has to be an indirect object once it is written.
      attr_writer :must_be_indirect

      # Creates a new PDF object for +value+.
      def initialize(value, document: nil, oid: 0, gen: 0)
        self.document = document
        self.oid = oid
        self.gen = gen
        self.must_be_indirect = false
        self.value = value
      end

      # Sets the value for this PDF object.
      #
      # If the value is a PDF object itself, uses the value of the PDF object instead of the PDF
      # object.
      def value=(value)
        @value = (value.kind_of?(Object) ? value.value : value)
      end

      # Returns the associated PDF document.
      #
      # If no document is associated, an error is raised.
      def document
        @document || raise(HexaPDF::Error, "No document associated with this object (#{inspect})")
      end

      # Returns +true+ if a PDF document is associated.
      def document?
        !@document.nil?
      end

      # Returns +true+ if the object is an indirect object (i.e. has an object number unequal to
      # zero).
      def indirect?
        oid != 0
      end

      # Returns +true+ if the object must be an indirect object once it is written.
      def must_be_indirect?
        @must_be_indirect
      end

      # Returns the type (symbol) of the object.
      #
      # Since the type system is implemented in such a way as to allow exchanging implementations of
      # specific types, the class of an object can't be reliably used for determining the actual
      # type. However, the Type field can easily be used for this.
      #
      # For basic objects this always returns :Unknown.
      def type
        :Unknown
      end

      # Returns +true+ if the object represents an empty object, i.e. a PDF null object or an empty
      # value.
      def empty?
        @value.nil? || (@value.respond_to?(:empty?) && @value.empty?)
      end

      # :call-seq:
      #   obj.validate(auto_correct: true)                               -> true or false
      #   obj.validate(auto_correct: true) {|msg, correctable| block }   -> true or false
      #
      # Validates the object and, optionally, corrects problems when the option +auto_correct+ is
      # set.
      #
      # If a block is given, it is called on validation problems with a problem description and
      # whether the problem is correctable.
      #
      # Returns +true+ if the object is deemed valid and +false+ otherwise.
      #
      # Validators from the superclass come before validators from the class itself and they are
      # used in the order they are defined. As soon as one validator returns +false+ the other
      # validators are not called anymore!
      #
      # *Important note*: Even if the return value is +true+ there may be problems since HexaPDF
      # doesn't currently implement the full PDF spec. However, if the return value is +false+,
      # there is certainly a problem!
      def validate(auto_correct: true, &block)
        catch_tag = ::Object.new
        validator_block = lambda do |msg, correctable|
          block.call(msg, correctable) if block
          throw(catch_tag, false) unless auto_correct && correctable
        end
        catch(catch_tag) do
          self.class.each_validator do |validator|
            if validator.respond_to?(:call)
              validator.call(self, &validator_block)
            else
              __send__(validator, &validator_block)
            end
          end
          true
        end
      end

      # Returns +true+ if the other object has the same oid, gen and value.
      def ==(other)
        super && value == other.value
      end

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}] value=#{value.inspect}>"
      end

      private

      # Returns the configuration object of the PDF document.
      def config
        document.config
      end

      # Validates that the object is indirect if #must_be_indirect? is +true+.
      def validate_must_be_indirect
        if must_be_indirect? && !indirect?
          yield("Object must be an indirect object", true)
          document.add(self)
        end
      end

    end

  end
end
