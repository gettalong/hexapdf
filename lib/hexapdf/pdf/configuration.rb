# -*- encoding: utf-8 -*-

require 'hexapdf/error'

module HexaPDF
  module PDF

    # Manages both the global and document specific configuration options for HexaPDF.
    #
    # == Overview
    #
    # HexaPDF allows detailed control over many aspects of PDF manipulation. If there is a need to
    # use a certain default value somewhere, it is defined as configuration options so that it can
    # easily be changed.
    #
    # Some options are defined as global options because they are needed on the class level - see
    # GlobalConfiguration. Other options can be configured for individual documents as they allow to
    # fine-tune some behavior - see DefaultDocumentConfiguration.
    #
    # A configuration option name is dot-separted to provide a hierarchy of option names. For
    # example, io.chunk_size.
    class Configuration

      # Creates a new document specific Configuration object by merging the values into the default
      # configuration object.
      def self.with_defaults(values = {})
        DefaultDocumentConfiguration.merge(values)
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
        self.class.new(options.merge(config) do |_key, old, new|
                         old.kind_of?(Hash) && new.kind_of?(Hash) ? old.merge(new) : new
                       end)
      end

      # :call-seq:
      #   config.constantize(name, key = nil)                  -> constant or nil
      #   config.constantize(name, key = nil) {|name| block}   -> obj
      #
      # Returns the constant the option +name+ is referring to. If +key+ is provided and the value
      # of the option +name+ responds to +[]+, the constant to which +key+ refers is returned.
      #
      # If no constant can be found and no block is provided, +nil+ is returned. If a block is
      # provided it is called with the option name and its result will be returned.
      #
      #   config.constantize('encryption.aes')      #=> HexaPDF::PDF::Encryption::FastAES
      #   config.constantize('filter.map', :Fl)     #=> HexaPDF::PDF::Filter::FlateDecode
      def constantize(name, key = :__unset)
        data = self[name]
        data = data[key] if key != :__unset && data.respond_to?(:[])
        (data = ::Object.const_get(data) rescue nil) if data.kind_of?(String)
        data = yield(name) if block_given? && data.nil?
        data
      end

      protected

      # Returns the hash with the configuration options.
      attr_reader :options

    end

    # The default document specific configuration object.
    #
    # Modify this object if you want to globally change document specific options or if you want to
    # introduce new document specific options.
    #
    # The following options are provided:
    #
    # io.chunk_size::
    #    The size of the chunks that are used when reading IO data.
    #
    #    This can be used to limit the memory needed for reading or writing PDF files with huge
    #    stream objects.
    #
    # page.default_media_box::
    #    The media box that is used for new pages that don't define a media box. Default value is
    #    A4. See HexaPDF::PDF::Type::Page::PAPER_SIZE for a list of predefined paper sizes.
    #
    #    The value can either be a rectangle defining the paper size or a Symbol referencing one of
    #    the predefined paper sizes.
    #
    # parser.on_correctable_error::
    #    Callback hook when the parser encounters an error that can be corrected.
    #
    #    The value needs to be an object that responds to \#call(document, message, position) and
    #    returns +true+ if an error should be raised.
    #
    # sorted_tree.max_leaf_node_size::
    #    The maximum number of nodes that should be in a leaf node of a node tree.
    DefaultDocumentConfiguration =
      Configuration.new('io.chunk_size' => 2**16,
                        'page.default_media_box' => :A4,
                        'parser.on_correctable_error' => proc { false },
                        'sorted_tree.max_leaf_node_size' => 64)

    # The global configuration object, providing the following options:
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
    # filter.flate_compression::
    #    Specifies the compression level that should be used with the FlateDecode filter. The level
    #    can range from 0 (no compression), 1 (best speed) to 9 (best compression, default).
    #
    # filter.map::
    #    A mapping from a PDF name (a Symbol) to a filter object (see Filter). If the value is a
    #    String, it should contain the name of a constant that contains a filter object.
    #
    #    The most often used filters are implemented and readily available.
    #
    #    See PDF1.7 s7.4.1, ADB sH.3 3.3
    #
    # image_loader::
    #    An array with image loader implementations. When an image should be loaded, the array is
    #    iterated in sequence to find a suitable image loader.
    #
    #    If a value is a String, it should contain the name of a constant that is an image loader
    #    object.
    #
    #    See the ImageLoader module for information on how to implement an image loader object.
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
    # task.map::
    #    A mapping from task names to callable task objects. See Task for more information.
    GlobalConfiguration =
      Configuration.new('encryption.aes' => 'HexaPDF::PDF::Encryption::FastAES',
                        'encryption.arc4' => 'HexaPDF::PDF::Encryption::FastARC4',
                        'encryption.filter_map' => {
                          Standard: 'HexaPDF::PDF::Encryption::StandardSecurityHandler',
                        },
                        'encryption.sub_filter_map' => {
                        },
                        'filter.flate_compression' => 9,
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
                          Crypt: nil,
                          Encryption: 'HexaPDF::PDF::Filter::Encryption',
                        },
                        'image_loader' => [
                          'HexaPDF::PDF::ImageLoader::JPEG',
                          'HexaPDF::PDF::ImageLoader::PNG',
                        ],
                        'object.type_map' => {
                          XRef: 'HexaPDF::PDF::Type::XRefStream',
                          ObjStm: 'HexaPDF::PDF::Type::ObjectStream',
                          Catalog: 'HexaPDF::PDF::Type::Catalog',
                          ViewerPreferences: 'HexaPDF::PDF::Type::ViewerPreferences',
                          Pages: 'HexaPDF::PDF::Type::PageTreeNode',
                          Page: 'HexaPDF::PDF::Type::Page',
                          Names: 'HexaPDF::PDF::Type::Names',
                          Filespec: 'HexaPDF::PDF::Type::FileSpecification',
                          EmbeddedFile: 'HexaPDF::PDF::Type::EmbeddedFile',
                          Info: 'HexaPDF::PDF::Type::Info',
                          Resources: 'HexaPDF::PDF::Type::Resources',
                          ExtGState: 'HexaPDF::PDF::Type::GraphicsStateParameter',
                        },
                        'object.subtype_map' => {
                          Image: 'HexaPDF::PDF::Type::Image',
                        },
                        'task.map' => {
                          set_min_pdf_version: 'HexaPDF::PDF::Task::SetMinPDFVersion',
                          optimize: 'HexaPDF::PDF::Task::Optimize',
                          dereference: 'HexaPDF::PDF::Task::Dereference',
                          validate: 'HexaPDF::PDF::Task::Validate',
                        })

  end
end
