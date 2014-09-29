# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/filter'

module HexaPDF
  module PDF

    # Container for stream data from an existing PDF.
    #
    # This helper class wraps all information necessary to read the stream data from an existing
    # PDF.
    #
    # The +source+ can either be an IO stream which is read starting from a specific +offset+ for a
    # specific +length+, or a Fiber (in which case the +offset+ and +length+ values are ignored).
    #
    # The +filter+ and +decode_parms+ are automatically normalized to arrays on assignment to ease
    # further processing.
    class StreamData

      attr_accessor :source, :offset, :length, :filter, :decode_parms

      # Create a new StreamData object for the given +source+ and with the optional parameters.
      def initialize(source, offset: nil, length: nil, filter: nil, decode_parms: nil)
        @source = source
        @offset = offset
        @length = length
        self.filter = filter
        self.decode_parms = decode_parms
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
    # A stream may also be associated with a PDF object but only if the value is a PDF dictionary (a
    # Hash in the HexaPDF implementation). This associated dictionary further describes the stream,
    # like its length or how it is encoded.
    #
    # Such a stream object in PDF contains string data but of possibly unlimited length. Therefore
    # it is used for large amounts of data like images, page descriptions or embedded files.
    #
    # Note that the basic Object class cannot hold stream data, only the sub class Stream contains
    # the necessary methods to conveniently work with the stream data!
    #
    # See: PDF1.7 s7.3.8
    class Stream < HexaPDF::PDF::Object

      def initialize(document, value, stream: '', **kwargs) # :nodoc:
        super(document, value, **kwargs)
        unless value.kind_of?(Hash)
          raise HexaPDF::Error, "A PDF stream object needs a Dictionary value, not a #{value.class}"
        end

        self.stream = stream # reassign for checking
      end

      # Assign a new stream object.
      #
      # The given stream can be a StreamData object, a String object or +nil+.
      #
      # If +stream+ is a StreamData object and if the +stream.filter+ and +stream.decode_parms+
      # attributes are not already set, they are automatically set to the correct values from this
      # PDF object.
      #
      # If +stream+ is +nil+, an empty binary string is used instead.
      def stream=(stream)
        stream ||= ''.force_encoding('BINARY')
        unless stream.kind_of?(StreamData) || stream.kind_of?(String)
          raise HexaPDF::Error, "An object of the given class #{stream.class} cannot be used as stream value"
        end

        @stream = stream
      end

      # Return the (possibly decoded) stream data as string.
      #
      # Note that after this method has been called, the original, possibly encoded stream data is
      # not available anymore!
      def stream
        unless @stream.kind_of?(String)
          @stream = HexaPDF::PDF::Filter.string_from_source(stream_decoder)
        end
        @stream
      end

      # Return the decoder Fiber for the stream data.
      def stream_decoder
        source = stream_source

        if @stream.kind_of?(StreamData)
          @stream.filter.zip(@stream.decode_parms) do |filter, decode_parms|
            source = filter_for_name(filter).decoder(source, decode_parms)
          end
        end

        source
      end

      # Return the encoder Fiber for the stream data.
      def stream_encoder
        encoder_data = [document.store.deref!(value[:Filter])].flatten.compact.
          zip([document.store.deref!(value[:DecodeParms])].flatten.compact)
        source = stream_source

        if @stream.kind_of?(StreamData)
          decoder_data = @stream.filter.zip(@stream.decode_parms)

          until decoder_data.empty? || encoder_data.empty?
            i = decoder_data.length - 1
            j = encoder_data.length - 1
            if decoder_data[i] == encoder_data[j]
              decoder_data.delete_at(i)
              encoder_data.delete_at(j)
            else
              break
            end
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

      private

      # Return the Fiber representing the unprocessed content of the stream.
      def stream_source
        if @stream.kind_of?(String)
          HexaPDF::PDF::Filter.source_from_string(@stream)
        elsif @stream.source.kind_of?(Fiber)
          @stream.source
        else
          HexaPDF::PDF::Filter.source_from_io(@stream.source, pos: @stream.offset || 0, length: @stream.length || -1)
        end
      end

      # Return the filter object that corresponds to the given filter name.
      #
      # See: HexaPDF::PDF::Filter
      def filter_for_name(filter_name)
        filter_const_name = document.config['filter.map'][filter_name]
        unless filter_const_name
          raise HexaPDF::Error, "Unknown stream filter '#{filter_name}' encountered"
        end
        ::Object.const_get(filter_const_name)
      end

    end

  end
end
