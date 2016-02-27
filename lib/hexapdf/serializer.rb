# -*- encoding: utf-8 -*-

require 'time'
require 'hexapdf/tokenizer'
require 'hexapdf/filter'
require 'hexapdf/utils/lru_cache'

module HexaPDF

  # Knows how to serialize Ruby objects for a PDF file.
  #
  # For normal serialization purposes, the #serialize or #serialize_to_io methods should be used.
  # However, it the type of the object to be serialized is known, a specialized serialization
  # method like #serialize_float can be used.
  #
  # == How This Class Works
  #
  # The main public interface consists of the #serialize and #serialize_to_io methods which
  # accepts an object and returns its serialized form. During serialization of this object it is
  # accessible by individual serialization methods via the @object instance variable (useful if
  # the object is a composed object).
  #
  # Internally, the #__serialize method is used for invoking the correct serialization method
  # based on the class of a given object. It is also used for serializing individual parts of a
  # composed object.
  #
  # Therefore the serializer contains one serialization method for each class it needs to
  # serialize. The naming scheme of these methods is based on the class name: The full class name
  # is converted to lowercase, the namespace separator '::' is replaced with a single underscore
  # and the string "serialize_" is then prepended.
  #
  # Examples:
  #
  #   NilClass                 => serialize_nilclass
  #   TrueClass                => serialize_trueclass
  #   HexaPDF::Object          => serialize_hexapdf_object
  #
  # If no serialization method for a specific class is found, the ancestors classes are tried.
  #
  # See: PDF1.7 s7.3
  class Serializer

    # Specifies whether the serializer object should encrypt strings and streams. Default: false.
    attr_accessor :encrypt

    # Creates a new Serializer object.
    def initialize
      @dispatcher = Hash.new do |h, klass|
        method = nil
        klass.ancestors.each do |ancestor_klass|
          method = "serialize_#{ancestor_klass.name.downcase.gsub(/::/, '_')}"
          (h[klass] = method; break) if respond_to?(method, true)
        end
        method
      end
      @encrypt = false
      @io = nil
      @object = nil
    end

    # Returns the serialized form of the given object.
    #
    # For developers: While the object is serialized, methods can use the instance variable
    # @object to obtain information about or use the object in case it is a composed object.
    def serialize(obj)
      @object = obj
      __serialize(obj)
    ensure
      @object = nil
    end

    # Serializes the given object and writes it to the IO.
    #
    # Also see: #serialize
    def serialize_to_io(obj, io)
      @io = io
      @io << serialize(obj).freeze
    ensure
      @io = nil
    end

    # Serializes the +nil+ value.
    #
    # See: PDF1.7 s7.3.9
    def serialize_nilclass(_obj)
      "null"
    end

    # Serializes the +true+ value.
    #
    # See: PDF1.7 s7.3.2
    def serialize_trueclass(_obj)
      "true"
    end

    # Serializes the +false+ value.
    #
    # See: PDF1.7 s7.3.2
    def serialize_falseclass(_obj)
      "false"
    end

    # Serializes a Numeric object (either Integer or Float).
    #
    # This method should be used for cases where it is known that the object is either an Integer
    # or a Float.
    #
    # See: PDF1.7 s7.3.3
    def serialize_numeric(obj)
      obj.kind_of?(Integer) ? obj.to_s : serialize_float(obj)
    end

    # Serializes an Integer object.
    #
    # See: PDF1.7 s7.3.3
    def serialize_integer(obj)
      obj.to_s
    end

    # Serializes a Float object.
    #
    # See: PDF1.7 s7.3.3
    def serialize_float(obj)
      obj.abs < 0.0001 && obj != 0 ? sprintf("%.6f".freeze, obj) : obj.round(6).to_s
    end

    # The regexp matches all characters that need to be escaped and the substs hash contains the
    # mapping from these characters to their escaped form.
    #
    # See PDF1.7 s7.3.5
    NAME_SUBSTS = {}
    [0..32, 127..255, Tokenizer::DELIMITER.bytes, Tokenizer::WHITESPACE.bytes, [35]].each do |a|
      a.each {|c| NAME_SUBSTS[c.chr] = "##{c.to_s(16).rjust(2, "0")}"}
    end
    # :nodoc:
    NAME_REGEXP = /[^!-~&&[^##{Regexp.escape(Tokenizer::DELIMITER)}#{Regexp.escape(Tokenizer::WHITESPACE)}]]/
    # :nodoc:
    NAME_CACHE = Utils::LRUCache.new(1000)

    # Serializes a Symbol object (i.e. a PDF name object).
    #
    # See: PDF1.7 s7.3.5
    def serialize_symbol(obj)
      NAME_CACHE[obj] ||=
        begin
          str = obj.to_s.force_encoding(Encoding::BINARY)
          str.gsub!(NAME_REGEXP) {|m| NAME_SUBSTS[m]}
          "/#{str}"
        end
    end

    # :nodoc:
    BYTE_IS_DELIMITER = {40 => true, 47 => true, 60 => true, 91 => true,
                         41 => true, 62 => true, 93 => true}

    # Serializes an Array object.
    #
    # See: PDF1.7 s7.3.6
    def serialize_array(obj)
      str = "["
      index = 0
      while index < obj.size
        tmp = __serialize(obj[index])
        str << " ".freeze unless BYTE_IS_DELIMITER[tmp.getbyte(0)] ||
          BYTE_IS_DELIMITER[str.getbyte(-1)]
        str << tmp
        index += 1
      end
      str << "]".freeze
    end

    # Serializes a Hash object (i.e. a PDF dictionary object).
    #
    # See: PDF1.7 s7.3.7
    def serialize_hash(obj)
      str = "<<"
      obj.each do |k, v|
        next if v.nil? || (v.respond_to?(:null?) && v.null?)
        str << __serialize(k)
        tmp = __serialize(v)
        str << " ".freeze unless BYTE_IS_DELIMITER[tmp.getbyte(0)] ||
          BYTE_IS_DELIMITER[str.getbyte(-1)]
        str << tmp
      end
      str << ">>".freeze
    end

    # :nodoc:
    STRING_ESCAPE_MAP = {"(" => "\\(", ")" => "\\)", "\\" => "\\\\", "\r" => "\\r"}

    # Serializes a String object.
    #
    # See: PDF1.7 s7.3.4
    def serialize_string(obj)
      if @encrypt && @object.kind_of?(HexaPDF::Object) && @object.indirect?
        obj = @object.document.security_handler.encrypt_string(obj, @object)
      elsif obj.encoding != Encoding::BINARY && obj =~ /[^ -~\t\r\n]/
        obj = ("\xFE\xFF".force_encoding(Encoding::UTF_16BE) << obj.encode(Encoding::UTF_16BE)).
          force_encoding(Encoding::BINARY)
      elsif obj.encoding != Encoding::BINARY
        obj = obj.b
      end
      "(" << obj.gsub(/[\(\)\\\r]/n) {|m| STRING_ESCAPE_MAP[m]} << ")".freeze
    end

    # The ISO PDF specification differs in respect to the supported date format. When converting
    # to a date string, a format suitable for both is output.
    #
    # See: PDF1.7 s7.9.4, ADB1.7 3.8.3
    def serialize_time(obj)
      zone = obj.strftime("%z'")
      if zone == "+0000'"
        zone = ''
      else
        zone[3, 0] = "'"
      end
      serialize_string(obj.strftime("D:%Y%m%d%H%M%S#{zone}"))
    end

    # See: #serialize_time
    def serialize_date(obj)
      serialize_time(obj.to_time)
    end

    # See: #serialize_time
    def serialize_datetime(obj)
      serialize_time(obj.to_time)
    end

    private

    # Uses #serialize_hexapdf_reference if it is an indirect object, otherwise just serializes
    # the objects value.
    def serialize_hexapdf_object(obj)
      if obj.indirect? && obj != @object
        serialize_hexapdf_reference(obj)
      else
        __serialize(obj.value)
      end
    end

    # See: PDF1.7 s7.3.10
    def serialize_hexapdf_reference(obj)
      "#{obj.oid} #{obj.gen} R".freeze
    end

    # Serializes the streams dictionary and its stream.
    #
    # See: PDF1.7 s7.3.8
    def serialize_hexapdf_stream(obj)
      if !obj.indirect?
        raise HexaPDF::Error, "Can't serialize PDF stream without object identifier"
      elsif obj != @object
        return serialize_hexapdf_reference(obj)
      end

      fiber = if @encrypt
                @object.document.security_handler.encrypt_stream(obj)
              else
                obj.stream_encoder
              end

      if @io && fiber.respond_to?(:length) && fiber.length >= 0
        obj.value[:Length] = fiber.length
        @io << __serialize(obj.value)
        @io << "stream\n".freeze
        while fiber.alive? && (data = fiber.resume)
          @io << data.freeze
        end
        @io << "\nendstream".freeze

        nil
      else
        data = Filter.string_from_source(fiber)
        obj.value[:Length] = data.size

        str = __serialize(obj.value)
        str << "stream\n".freeze
        str << data
        str << "\nendstream".freeze
      end
    end

    # Invokes the correct serialization method for the object.
    def __serialize(obj)
      send(@dispatcher[obj.class], obj)
    end

  end

end
