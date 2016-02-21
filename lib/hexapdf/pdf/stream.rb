# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/dictionary'
require 'hexapdf/filter'

module HexaPDF
  module PDF

    # Container for stream data that is more complex than a string.
    #
    # This helper class wraps all information necessary to read stream data by using a Fiber object
    # (see Filter). The underlying data either comes from an IO object, a file represented by its
    # file name or a Fiber defined via a Proc object.
    #
    # Additionally, the #filter and #decode_parms can be set to indicate that the data returned from
    # the Fiber needs to be post-processed. The +filter+ and +decode_parms+ are automatically
    # normalized to arrays on assignment to ease further processing.
    class StreamData

      # The filter(s) that need to be applied for getting the decoded stream data.
      attr_reader :filter

      # The decoding parameters associated with the +filter+(s).
      attr_reader :decode_parms

      # Creates a new StreamData object for the given +source+ and with the given options.
      #
      # The +source+ can be:
      #
      # * An IO stream which is read starting from a specific +offset+ for a specific +length+
      #
      # * A string which is interpreted as a file name and read starting from a specific +offset+
      # * and for a specific +length+
      #
      # * A Proc object (that is converted to a Fiber when needed) in which case the +offset+ and
      #   +length+ values are ignored.
      def initialize(source, offset: nil, length: nil, filter: nil, decode_parms: nil)
        @source = source
        @offset = offset
        @length = length
        @filter = [filter].flatten.compact
        @decode_parms = [decode_parms].flatten
        freeze
      end

      # Returns a Fiber for getting at the data of the stream represented by this object.
      def fiber(chunk_size = 0)
        if @source.kind_of?(Proc)
          FiberWithLength.new(@length, &@source)
        elsif @source.kind_of?(String)
          HexaPDF::Filter.source_from_file(@source, pos: @offset || 0, length: @length || -1,
                                                chunk_size: chunk_size)
        else
          HexaPDF::Filter.source_from_io(@source, pos: @offset || 0, length: @length || -1,
                                              chunk_size: chunk_size)
        end
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

      define_field :Length,       type: Integer # not required, will be auto-filled when writing
      define_field :Filter,       type: [Symbol, Array]
      define_field :DecodeParms,  type: [Dictionary, Hash, Array]
      define_field :F,            type: :FileSpec, version: '1.2'
      define_field :FFilter,      type: [Symbol, Array], version: '1.2'
      define_field :FDecodeParms, type: [Dictionary, Hash, Array], version: '1.2'
      define_field :DL,           type: Integer

      define_validator(:validate_stream_filter)

      # Stream objects must always be indirect.
      def must_be_indirect?
        true
      end

      # Assigns a new stream data object.
      #
      # The +stream+ argument can be a StreamData object, a String object or +nil+.
      #
      # If +stream+ is +nil+, an empty binary string is used instead.
      def stream=(stream)
        data.stream = stream
        after_data_change
      end

      # Returns the (possibly decoded) stream data as string.
      #
      # After this method has been called, the original, possibly encoded stream data is not
      # available anymore!
      def stream
        unless data.stream.kind_of?(String)
          data.stream = HexaPDF::Filter.string_from_source(stream_decoder)
        end
        data.stream
      end

      # Returns the raw stream object.
      #
      # The returned value can be of many different types (see #stream=). For working with the
      # decoded stream contents use #stream.
      def raw_stream
        data.stream
      end

      # Returns the Fiber representing the unprocessed content of the stream.
      def stream_source
        if data.stream.kind_of?(String)
          HexaPDF::Filter.source_from_string(data.stream)
        else
          data.stream.fiber(config['io.chunk_size'.freeze])
        end
      end

      # Returns the decoder Fiber for the stream data.
      #
      # See the Filter module for more information on how to work with the fiber.
      def stream_decoder
        source = stream_source

        if data.stream.kind_of?(StreamData)
          data.stream.filter.zip(data.stream.decode_parms) do |filter, decode_parms|
            source = filter_for_name(filter).decoder(source, decode_parms)
          end
        end

        source
      end

      # Returns the encoder Fiber for the stream data.
      #
      # The two arguments can be used to add additional filters for *only* this returned encoder
      # Fiber. They should normally *not* be used and are here for use by the encryption facilities.
      #
      # See the Filter module for more information on how to work with the fiber.
      def stream_encoder(additional_filter = nil, additional_decode_parms = nil)
        encoder_data = [additional_filter, document.unwrap(self[:Filter])].flatten.
          zip([additional_decode_parms, document.unwrap(self[:DecodeParms])].flatten).
          delete_if {|f, _| f.nil?}
        source = stream_source

        if data.stream.kind_of?(StreamData)
          decoder_data = data.stream.filter.zip(data.stream.decode_parms)

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
        if filter.nil? || (filter.kind_of?(Array) && filter.empty?)
          delete(:Filter)
        else
          self[:Filter] = filter
        end
        if decode_parms.nil? || (decode_parms.kind_of?(Array) && decode_parms.empty?) ||
            !key?(:Filter)
          delete(:DecodeParms)
        else
          self[:DecodeParms] = decode_parms
        end
      end

      private

      # Makes sure that the stream data is either a String or a StreamData object.
      def after_data_change
        super
        data.stream ||= ''.force_encoding(Encoding::BINARY)
        unless data.stream.kind_of?(StreamData) || data.stream.kind_of?(String)
          raise HexaPDF::Error, "Object of class #{data.stream.class} cannot be used as stream value"
        end
      end

      # Returns the filter object that corresponds to the given filter name.
      #
      # See: HexaPDF::PDF::Filter
      def filter_for_name(filter_name)
        GlobalConfiguration.constantize('filter.map', filter_name) do
          raise HexaPDF::Error, "Unknown stream filter '#{filter_name}' encountered"
        end
      end

      # :nodoc:
      # A mapping from short name to long name for filters.
      FILTER_MAP = {AHx: :ASCIIHexDecode, A85: :ASCII85Decode, LZW: :LZWDecode,
                    Fl: :FlateDecode, RL: :RunLengthDecode, CCF: :CCITTFaxDecode, DCT: :DCTDecode}

      # Validates the /Filter entry so that it contains only long-name filter names.
      def validate_stream_filter
        if value[:Filter].kind_of?(Symbol) && FILTER_MAP.key?(value[:Filter])
          yield("A stream's /Filter entry may only use long-form filter names", true)
          value[:Filter] = FILTER_MAP[value[:Filter]]
        elsif value[:Filter].kind_of?(Array)
          value[:Filter].map! do |filter|
            next filter unless FILTER_MAP.key?(filter)
            yield("A stream's /Filter entry may only use long-form filter names", true)
            FILTER_MAP[filter]
          end
        end
      end

    end

  end
end
