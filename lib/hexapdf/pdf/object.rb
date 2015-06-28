# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # Internal value object for storing object number, generation number, object value and a
    # possible stream together. Such objects are not used directly but wrapped by Object or one of
    # its subclasses.
    class PDFData

      #:nodoc:
      attr_reader :oid, :gen

      #:nodoc:
      attr_accessor :stream, :value

      def initialize(value, oid = nil, gen = nil, stream = nil) #:nodoc:
        self.value = value
        self.oid = oid
        self.gen = gen
        self.stream = stream
      end

      def oid=(oid) #:nodoc:
        @oid = Integer(oid || 0)
      end

      def gen=(gen) #:nodoc
        @gen = Integer(gen || 0)
      end

    end


    # Objects of the PDF object system.
    #
    # == Overview
    #
    # A PDF object is like a normal object but with an additional *object identifier* consisting of
    # an object number and a generation number. If the object number is zero, then the PDF object
    # represents a direct object. Otherwise the object identifier uniquely identifies this object as
    # an indirect object and can be used for referencing it (from possibly multiple places).
    #
    # Furthermore a PDF object may have an associated stream. However, this stream is only
    # accessible if the subclass Stream is used.
    #
    # A PDF object *should* be connected to a PDF document, otherwise some methods may not work.
    #
    # Most PDF objects in a PDF document are represented by subclasses of this class that provide
    # additional functionality.
    #
    # The methods #hash and #eql? are implemented so that objects of this class can be used as hash
    # keys. Furthermore the implementation is compatible to the one of Reference, i.e. the hash of a
    # PDF Object is the same as the hash of its corresponding Reference object.
    #
    # See: Dictionary, Stream, Reference, Document
    # See: PDF1.7 s7.3.10, s7.3.8
    class Object

      include Comparable

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

      # Ensures that an object of this class is *always* an indirect object once it is written. This
      # overrides any value set via #must_be_indirect=.
      def self.must_be_indirect
        define_method(:must_be_indirect?) { true }
      end

      define_validator(:validate_basic_object)


      # The wrapped PDFData value.
      #
      # This attribute is not part of the public API!
      attr_reader :data

      # Sets the associated PDF document.
      attr_writer :document

      # Sets whether the object has to be an indirect object once it is written.
      attr_writer :must_be_indirect

      # Creates a new PDF object wrapping the value.
      #
      # The +value+ can either be a PDFData object in which case it is used directly. If it is a PDF
      # Object, then its data is used. Otherwise the +value+ object is used as is. In all cases, the
      # oid, gen and stream values may be overridden by the corresponding keyword arguments.
      def initialize(value, document: nil, oid: nil, gen: nil, stream: nil)
        @data = case value
                when PDFData then value
                when Object then value.data
                else PDFData.new(value)
                end
        @data.oid = oid if oid
        @data.gen = gen if gen
        @data.stream = stream if stream
        self.document = document
        self.must_be_indirect = false
        after_data_change
      end

      # Returns the object number of the PDF object.
      def oid
        data.oid
      end

      # Sets the object number of the PDF object.
      def oid=(oid)
        data.oid = oid
        after_data_change
      end

      # Returns the generation number of the PDF object.
      def gen
        data.gen
      end

      # Sets the generation number of the PDF object.
      def gen=(gen)
        data.gen = gen
        after_data_change
      end

      # Returns the object value.
      def value
        data.value
      end

      # Sets the object value. Unlike in #initialize the value is used as is!
      def value=(val)
        data.value = val
        after_data_change
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
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
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

      # Compares this object to another object.
      #
      # If the other object does not respond to +oid+ or +gen+, +nil+ is returned. Otherwise objects
      # are ordered first by object number and then by generation number.
      def <=>(other)
        return nil unless other.respond_to?(:oid) && other.respond_to?(:gen)
        (oid == other.oid ? gen <=> other.gen : oid <=> other.oid)
      end

      # Returns +true+ if the other object is a Object and has the same object number, generation
      # number and value.
      def ==(other)
        other.kind_of?(Object) && oid == other.oid && gen == other.gen && value == other.value
      end

      # Returns +true+ if the other object references the same PDF object as this object.
      def eql?(other)
        other.respond_to?(:oid) && oid == other.oid && other.respond_to?(:gen) && gen == other.gen
      end

      # Computes the hash value based on the object and generation numbers.
      def hash
        oid.hash ^ gen.hash
      end

      def inspect #:nodoc:
        "#<#{self.class.name} [#{oid}, #{gen}] value=#{value.inspect}>"
      end

      private

      # This method is called whenever a part of the wrapped PDFData structure is changed.
      #
      # A subclass implementing this method has to call +super+! Otherwise things might not work
      # properly.
      def after_data_change
      end

      # Returns the configuration object of the PDF document.
      def config
        document.config
      end

      # Validates the basic object properties.
      def validate_basic_object
        # Validate that the object is indirect if #must_be_indirect? is +true+.
        if must_be_indirect? && !indirect?
          yield("Object must be an indirect object", true)
          document.add(self)
        end
      end

    end

  end
end
