# -*- encoding: utf-8 -*-

require 'yaml'
require 'hexapdf/error'

module HexaPDF
  module PDF

    # Manages the available configuration options for a HexaPDF document.
    #
    # == Overview
    #
    # HexaPDF allows detailed control over many aspects of PDF manipulation. If there is a need to
    # use a certain default value somewhere, it is defined as configuration options so that it can
    # easily be changed.
    #
    # A configuration option name is dot-separted to provide a hierarchy of option names. For
    # example, io.chunk_size.
    #
    #
    # == Available Configuration Options
    #
    # encryption.aes::
    #    The class that should be used for AES encryption. If the value is a String, it should
    #    contain the name of a constant to such a class.
    #
    #    See Encryption::AES for the general interface such a class must conform to and
    #    Encryption::RubyAES as well as Encryption::FastAES for implementations.
    #
    # encryption.arc4::
    #    The class that should be used for ARC4 encryption. If the value is a String, it should
    #    contain the name of a constant to such a class.
    #
    #    See Encryption::ARC4 for the general interface such a class must conform to and
    #    Encryption::RubyARC4 as well as Encryption::FastARC4 for implementations.
    #
    # encryption.filter_map::
    #    A mapping from a PDF name (a Symbol) to a security handler class (see
    #    Encryption::SecurityHandler). If the value is a String, it should contain the name of a
    #    constant to such a class.
    #
    #    PDF defines a standard security handler that is implemented
    #    (Encryption::StandardSecurityHandler) and assigned the :Standard name.
    #
    # encryption.sub_filter_map::
    #    A mapping from a PDF name (a Symbol) to a security handler class (see
    #    Encryption::SecurityHandler). If the value is a String, it should contain the name of a
    #    constant to such a class.
    #
    #    The sub filter map is used when the security handler defined by the encryption dictionary
    #    is not available, but a compatible implementation is.
    #
    # filter.map::
    #    A mapping from a PDF name (a Symbol) to a filter object (see Filter). If the value is a
    #    String, it should contain the name of a constant that contains a filter object.
    #
    #    The most often used filters are implemented and readily available.
    #
    #    See PDF1.7 s7.4.1, ADB sH.3 3.3
    #
    # io.chunk_size::
    #    The size of the chunks that are used when reading IO data.
    #
    #    This can be used to limit the memory needed for reading or writing PDF files with huge
    #    stream objects.
    #
    # object.type_map::
    #    A mapping from a PDF name (a Symbol) to PDF object classes which is based on the /Type
    #    field. If the value is a String, it should contain the name of a constant that contains a
    #    PDF object class.
    #
    #    This mapping is used to provide automatic wrapping of objects in the Document#wrap method.
    #
    # object.subtype_map::
    #    A mapping from a PDF name (a Symbol) to PDF object classes which is based on the /Subtype
    #    field. If the value is a String, it should contain the name of a constant that contains a
    #    PDF object class.
    #
    #    This mapping is used to provide automatic wrapping of objects in the Document#wrap method.
    #
    # parser.on_correctable_error::
    #    Callback hook when the parser encounters an error that can be corrected.
    #
    #    The value needs to be an object that responds to \#call(document, message, position) and
    #    returns +true+ if an error should be raised.
    #
    # task.map::
    #    A mapping from task names to callable task objects. See Task for more information.
    class Configuration

      # Returns the default configuration object.
      #
      # The configuration contains options that can change the built-in behavior of the base classes
      # on which a document is built or which are used to read or write it.
      #
      # See the Configuration documentation for details on the available options.
      def self.default
        new('encryption.aes' => 'HexaPDF::PDF::Encryption::FastAES',
            'encryption.arc4' => 'HexaPDF::PDF::Encryption::FastARC4',
            'encryption.filter_map' => {
              Standard: 'HexaPDF::PDF::Encryption::StandardSecurityHandler',
            },
            'encryption.sub_filter_map' => {
            },
            'filter.map' => {
              ASCIIHexDecode: 'HexaPDF::PDF::Filter::ASCIIHexDecode',
              AHx: 'HexaPDF::PDF::Filter::ASCIIHexDecode',
              ASCII85Decode: 'HexaPDF::PDF::Filter::ASCII85Decode',
              A85: 'HexaPDF::PDF::Filter::ASCII85Decode',
              LZWDecode: 'HexaPDF::PDF::Filter::LZWDecode',
              LZW: 'HexaPDF::PDF::Filter::LZWDecode',
              FlateDecode: 'HexaPDF::PDF::Filter::FlateDecode',
              Fl: 'HexaPDF::PDF::Filter::FlateDecode',
              RunLengthDecode: 'HexaPDF::PDF::Filter::RunLengthDecode',
              RL: 'HexaPDF::PDF::Filter::RunLengthDecode',
              CCITTFaxDecode: nil,
              CCF: nil,
              JBIG2Decode: nil,
              DCTDecode: 'HexaPDF::PDF::Filter::DCTDecode',
              DCT: 'HexaPDF::PDF::Filter::DCTDecode',
              JPXDecode: 'HexaPDF::PDF::Filter::JPXDecode',
              Crypt: nil
            },
            'object.type_map' => {
              :XRef => 'HexaPDF::PDF::Type::XRefStream',
              :ObjStm => 'HexaPDF::PDF::Type::ObjectStream',
            },
            'object.subtype_map' => {
            },
            'io.chunk_size' => 2**16,
            'parser.on_correctable_error' => proc { false },
            'task.map' => {
              set_min_pdf_version: 'HexaPDF::PDF::Task::SetMinPDFVersion',
              optimize: 'HexaPDF::PDF::Task::Optimize',
              dereference: 'HexaPDF::PDF::Task::Dereference',
            },
            ).freeze
      end

      # Creates a new Configuration object by merging the values into the default configuration
      # object.
      def self.with_defaults(values)
        default.merge(values)
      end


      # Creates a new Configuration object using the provided hash argument.
      def initialize(options = {})
        @options = options
      end

      # Returns +true+ if the given option exists.
      def key?(name)
        options.key?(name)
      end
      alias :option? :key?

      # Returns the value for the configuration option +name+.
      def [](name)
        options[name]
      end

      # Uses +value+ as the value for the configuration option +name+.
      def []=(name, value)
        options[name] = value
      end

      # Returns a new Configuration object containing the options from the given configuration
      # object (or hash) and this configuration object.
      #
      # If a key already has a value in this object, its value is overwritten by the one from
      # +config+. However, hash values are merged instead of being overwritten.
      def merge(config)
        config = (config.kind_of?(self.class) ? config.options : config)
        self.class.new(options.merge(config) do |k, old, new|
                         old.kind_of?(Hash) && new.kind_of?(Hash) ? old.merge(new) : new
                       end)
      end

      # :call-seq:
      #   config.constantize(name, key = nil)                  -> constant or nil
      #   config.constantize(name, key = nil) {|name| block}   -> obj
      #
      # Returns the constant the option +name+ is referring to. If +key+ is provided and the value
      # of the option +name+ is a Hash, the constant to which +key+ refers is returned.
      #
      # If no constant can be found and no block is provided, +nil+ is returned. If a block is
      # provided it is called with the option name and its result will be returned.
      #
      #   config.constantize('encryption.aes')      #=> HexaPDF::PDF::Encryption::FastAES
      #   config.constantize('filter.map', :Fl)     #=> HexaPDF::PDF::Filter::FlateDecode
      def constantize(name, key = :__unset)
        data = self[name]
        data = data[key] if key != :__unset && data.kind_of?(Hash)
        (data = ::Object.const_get(data) rescue nil) if data.kind_of?(String)
        data = yield(name) if block_given? && data.nil?
        data
      end

      protected

      # Returns the hash with the configuration options.
      attr_reader :options

    end

  end
end
