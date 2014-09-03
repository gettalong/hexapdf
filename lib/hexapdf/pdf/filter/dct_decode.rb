# -*- encoding: utf-8 -*-

require 'fiber'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.8
      # TODO: what about paramter ColorTransform
      module DCTDecode

        def self.decoder(source, _ = nil)
          source
        end

        def self.encoder(source, _ = nil)
          source
        end

      end

    end
  end
end
