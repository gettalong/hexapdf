# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/tokenizer'

module HexaPDF
  module PDF

    # Knows how to serialize native Ruby objects for a PDF file.
    #
    # See: PDF1.7 s7.3
    class Serializer

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

      def serialize(obj)
        send(@dispatcher[obj.class], obj)
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

      # See: PDF1.7 s7.3.6
      def serialize_array(obj)
        str = "["
        obj.each {|o| str << serialize(o) << " "}
        str.chop! unless obj.empty?
        str << "]"
      end

      # See: PDF1.7 s7.3.7
      def serialize_hash(obj)
        str = "<<"
        obj.each {|k, v| str << serialize(k) << " " << serialize(v) << "\n"}
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

      def serialize_hexapdf_pdf_object(obj)
        serialize(obj.value)
      end

      def serialize_hexapdf_pdf_reference(obj)
        "#{obj.oid} #{obj.gen} R"
      end

    end

  end
end
