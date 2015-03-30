# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/filter'

module HexaPDF
  module PDF

    # Container for stream data from an existing PDF.
    #
    # This helper class wraps all information necessary to read the stream data from an existing IO
    # object.
    #
    # The +source+ can either be an IO stream which is read starting from a specific +offset+ for a
    # specific +length+, or a Fiber (see Filter) in which case the +offset+ and +length+ values are
    # ignored.
    #
    # The +filter+ and +decode_parms+ are automatically normalized to arrays on assignment to ease
    # further processing.
    class StreamData

      # The source of the stream, either an IO object or a Fiber.
      attr_accessor :source

      # The offset into the IO object where reading should start. Ignored if +source+ is a Fiber.
      attr_accessor :offset

      # The length of the stream data that should be read from the IO object. Ignored if +source+ is
      # a Fiber.
      attr_accessor :length

      # The filter(s) that need to be applied for getting the decoded stream data.
      attr_accessor :filter

      # The decoding parameters associated with the +filter+(s).
      attr_accessor :decode_parms

      # Creates a new StreamData object for the given +source+ and with the given options.
      def initialize(source, offset: nil, length: nil, filter: nil, decode_parms: nil)
        @source = source
        @offset = offset
        @length = length
        self.filter = filter
        self.decode_parms = decode_parms
      end

      # Returns a Fiber for getting at the data of the underlying IO object.
      def fiber(chunk_size = 0)
        if source.kind_of?(Fiber)
          source
        else
          HexaPDF::PDF::Filter.source_from_io(source, pos: offset || 0, length: length || -1,
                                              chunk_size: chunk_size)
        end
      end

      remove_method :filter=
      def filter=(filter) #:nodoc:
        @filter = [filter].flatten.compact
      end

      remove_method :decode_parms=
      def decode_parms=(parms) #:nodoc:
        @decode_parms = [parms].flatten.compact
      end

    end

    # Implements Stream objects of the PDF object system.
    #
    # == Stream Objects
    #
    # A stream may also be associated with a PDF object but only if the value is a PDF dictionary.
    # This associated dictionary further describes the stream, like its length or how it is encoded.
    #
    # Such a stream object in PDF contains string data but of possibly unlimited length. Therefore
    # it is used for large amounts of data like images, page descriptions or embedded files.
    #
    # The basic Object class cannot hold stream data, only this subclass contains the necessary
    # methods to conveniently work with the stream data!
    #
    # See: PDF1.7 s7.3.8, Dictionary
    class Stream < Dictionary

      define_field :Length, type: Integer # not required because it will be auto-filled when writing
      define_field :Filter, type: [Symbol, Array]
      define_field :DecodeParms, type: [Dictionary, Array]

      define_field :F, type: Dictionary, version: '1.2' #TODO: File specification
      define_field :FFilter, type: [Symbol, Array], version: '1.2'
      define_field :FDecodeParms, type: [Dictionary, Array], version: '1.2'

      define_field :DL, type: Integer

      # Creates a new Stream object.
      #
      # The +stream+ option may be used to assign a stream to this stream object on creation (see
      # #stream=).
      def initialize(value, stream: nil, **kwargs)
        super(value, **kwargs)
        self.stream = stream
      end

      # Assigns a new stream data object.
      #
      # The +stream+ argument can be a StreamData object, a String object or +nil+.
      #
      # If +stream+ is +nil+, an empty binary string is used instead.
      def stream=(stream)
        stream ||= ''.force_encoding(Encoding::BINARY)
        unless stream.kind_of?(StreamData) || stream.kind_of?(String)
          raise HexaPDF::Error, "An object of the given class #{stream.class} cannot be used as stream value"
        end

        @stream = stream
      end

      # Returns the (possibly decoded) stream data as string.
      #
      # After this method has been called, the original, possibly encoded stream data is not
      # available anymore!
      def stream
        unless @stream.kind_of?(String)
          @stream = HexaPDF::PDF::Filter.string_from_source(stream_decoder)
        end
        @stream
      end

      # Returns the raw stream object.
      #
      # The returned value can be of many different types (see #stream=). For working with the
      # decoded stream contents use #stream.
      def raw_stream
        @stream
      end

      # Returns the decoder Fiber for the stream data.
      #
      # See the Filter module for more information on how to work with the fiber.
      def stream_decoder
        source = stream_source

        if @stream.kind_of?(StreamData)
          @stream.filter.zip(@stream.decode_parms) do |filter, decode_parms|
            source = filter_for_name(filter).decoder(source, decode_parms)
          end
        end

        source
      end

      # Returns the encoder Fiber for the stream data.
      #
      # See the Filter module for more information on how to work with the fiber.
      def stream_encoder
        encoder_data = [document.unwrap(self[:Filter])].flatten.
          zip([document.unwrap(self[:DecodeParms])].flatten).
          delete_if {|f, d| f.nil?}
        source = stream_source

        if @stream.kind_of?(StreamData)
          decoder_data = @stream.filter.zip(@stream.decode_parms)

          while !decoder_data.empty? && !encoder_data.empty? && decoder_data.last == encoder_data.last
            decoder_data.pop
            encoder_data.pop
          end

          decoder_data.each do |filter, decode_parms|
            source = filter_for_name(filter).decoder(source, decode_parms)
          end
        end

        encoder_data.reverse!.each do |filter, decode_parms|
          source = filter_for_name(filter).encoder(source, decode_parms)
        end

        source
      end

      # Sets the filters that should be used for encoding the stream.
      #
      # The arguments +filter+ as well as +decode_parms+ can either be a single items or arrays.
      #
      # The filters have to be specified in the *decoding order*! For example, if the filters would
      # be [:A85, :Fl], the stream would first be encoded with the Flate and then with the ASCII85
      # filter.
      def set_filter(filter, decode_parms = nil)
        self[:Filter] = filter
        self[:DecodeParms] = decode_parms
      end

      private

      # Returns the Fiber representing the unprocessed content of the stream.
      def stream_source
        if @stream.kind_of?(String)
          HexaPDF::PDF::Filter.source_from_string(@stream)
        else
          @stream.fiber(config['io.chunk_size'])
        end
      end

      # Returns the filter object that corresponds to the given filter name.
      #
      # See: HexaPDF::PDF::Filter
      def filter_for_name(filter_name)
        filter_const_name = config['filter.map'][filter_name]
        unless filter_const_name
          raise HexaPDF::Error, "Unknown stream filter '#{filter_name}' encountered"
        end
        ::Object.const_get(filter_const_name)
      end

    end

  end
end
