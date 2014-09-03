# -*- encoding: utf-8 -*-

require 'fiber'

module HexaPDF
  module PDF
    module Filter

      # See: PDF1.7 7.4.9
      module JPXDecode

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
