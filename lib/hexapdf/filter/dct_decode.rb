# -*- encoding: utf-8 -*-

module HexaPDF
  module Filter

    # The DCTDecode filter is currently only implemented as a pass-through filter, ie. the source
    # gets passed on unmodified. This also means that the :ColorTransform parameter is not
    # evaluated!
    #
    # See: HexaPDF::Filter, PDF1.7 s7.4.8
    module DCTDecode

      # See HexaPDF::Filter
      def self.decoder(source, _ = nil)
        source
      end

      # See HexaPDF::Filter
      def self.encoder(source, _ = nil)
        source
      end

    end

  end
end
