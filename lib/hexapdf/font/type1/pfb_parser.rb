# -*- encoding: utf-8 -*-

require 'hexapdf/font/encoding'
require 'hexapdf/error'
require 'strscan'

module HexaPDF
  module Font
    module Type1

      # Parses files in the PFB file format.
      #
      # Note that this implementation isn't a full PFB parser. It is currently just used for
      # extracting the font encoding.
      class PFBParser

        # :call-seq:
        #   PFBParser.encoding(data)       -> encoding
        #
        # Parses the PFB data given as string and returns the found Encoding.
        def self.encoding(data)
          enc = Encoding::Base.new
          ss = StringScanner.new(data)
          if ss.skip_until(/\/Encoding\s+\d+\s+array.+?(?=\bdup\b)/m)
            while ss.skip(/dup\s+(\d+)\s+\/(\w+)\s+put\s+/)
              enc.code_to_name[ss[1].to_i] = ss[2].intern
            end
          elsif ss.skip_until(/\/Encoding\s+StandardEncoding\s+def/)
            enc = Encoding.for_name(:StandardEncoding)
          else
            raise HexaPDF::Error, "Unknown Type1 encoding"
          end
          enc
        end

      end

    end
  end
end
