# -*- encoding: utf-8 -*-

require 'stringio'

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

  end
end
