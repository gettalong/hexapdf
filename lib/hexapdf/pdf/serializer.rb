# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/tokenizer'

module HexaPDF
  module PDF

    # Knows how to serialize Ruby objects for a PDF file.
    #
    # The stream of stream objects is not serialized by this class but every other object is!
    #
    # See: PDF1.7 s7.3
    class Serializer

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
      end

      # Returns the serialized form of the given object.
      def serialize(obj)
        send(@dispatcher[obj.class], obj).force_encoding(Encoding::BINARY)
      end

      private

      # See: PDF1.7 s7.3.9
      def serialize_nilclass(obj)
        "null"
      end

      # See: PDF1.7 s7.3.2
      def serialize_trueclass(obj)
        "true"
      end

      # See: PDF1.7 s7.3.2
      def serialize_falseclass(obj)
        "false"
      end

      # See: PDF1.7 s7.3.3
      def serialize_integer(obj)
        obj.to_s
      end

      # See: PDF1.7 s7.3.3
      def serialize_float(obj)
        obj.round(4).to_s
      end

      # The regexp matches all characters that need to be escaped and the substs hash contains the
      # mapping from these characters to their escaped form.
      #
      # See PDF1.7 s7.3.5
      NAME_SUBSTS = {}
      [0..32, 127..255, Tokenizer::DELIMITER.bytes, Tokenizer::WHITESPACE.bytes, [35]].each do |array|
        array.each {|c| NAME_SUBSTS[c.chr] = "##{c.to_s(16).rjust(2, "0")}"}
      end
      NAME_REGEXP = /[^!-~&&[^##{Regexp.escape(Tokenizer::DELIMITER)}#{Regexp.escape(Tokenizer::WHITESPACE)}]]/

      # See: PDF1.7 s7.3.5
      def serialize_symbol(obj)
        str = obj.to_s.force_encoding(Encoding::BINARY)
        str.gsub!(NAME_REGEXP) {|m| NAME_SUBSTS[m]}
        "/#{str}"
      end

      BYTE_IS_STARTING_DELIMITER = {40 => true, 47 => true, 60 => true, 91 => true} #:nodoc:

      # See: PDF1.7 s7.3.6
      def serialize_array(obj)
        str = "["
        index = 0
        while index < obj.size
          tmp = serialize(obj[index])
          str << " " unless BYTE_IS_STARTING_DELIMITER[tmp.getbyte(0)] || index == 0
          str << tmp
          index += 1
        end
        str << "]"
      end

      # See: PDF1.7 s7.3.7
      def serialize_hash(obj)
        str = "<<"
        obj.each do |k, v|
          str << serialize(k)
          tmp = serialize(v)
          str << " " unless BYTE_IS_STARTING_DELIMITER[tmp.getbyte(0)]
          str << tmp
        end
        str << ">>"
      end

      # See: PDF1.7 s7.3.4
      def serialize_string(obj)
        if obj.encoding != Encoding::BINARY && obj =~ /[^ -~\t\r\n]/
          obj = "\xFE\xFF".force_encoding(Encoding::UTF_16BE) << obj.encode(Encoding::UTF_16BE)
          obj.force_encoding(Encoding::BINARY)
        end
        "(" << obj.gsub(/[\(\)\\]/n) {|m| "\\#{m}"} << ")"
      end

      # Just serializes the objects value.
      def serialize_hexapdf_pdf_object(obj)
        serialize(obj.value)
      end

      # See: PDF1.7 s7.3.10
      def serialize_hexapdf_pdf_reference(obj)
        "#{obj.oid} #{obj.gen} R"
      end

    end

  end
end
