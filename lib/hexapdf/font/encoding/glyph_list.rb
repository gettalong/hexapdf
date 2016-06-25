# -*- encoding: utf-8 -*-

require 'hexapdf/data_dir'

module HexaPDF
  module Font
    module Encoding

      # Provides access to and mapping functionality for the Adobe Glyph List.
      #
      # The Adobe Glyph List is used for mapping glyph names to unicode values. The mapping itself
      # is not a one-to-one mapping because some glyphs are mapped to the same unicode sequence,
      # e.g. the glyph name for 'A' and the glyph name for 'small capital A'.
      #
      # A (not unique) reverse mapping is also available which allows mapping a unicode sequence to
      # a glyph name.
      #
      # See:
      # * https://github.com/adobe-type-tools/agl-aglfn
      # * https://github.com/adobe-type-tools/agl-specification
      class GlyphList

        # Creates and returns the single GlyphList instance.
        def self.new
          @instance ||= super
        end

        # See #name_to_unicode
        def self.name_to_unicode(name, zapf_dingbats: false)
          new.name_to_unicode(name, zapf_dingbats: zapf_dingbats)
        end

        # See #unicode_to_name
        def self.unicode_to_name(unicode, zapf_dingbats: false)
          new.unicode_to_name(unicode, zapf_dingbats: zapf_dingbats)
        end

        def initialize #:nodoc:
          load
        end

        # Maps the given name to a string by following the Adobe Glyph Specification. An empty
        # string is returned if the name has no correct mapping.
        #
        # If this method is invoked when dealing with the ZapfDingbats font, the +zapf_dingbats+
        # option needs to be set to +true+.
        #
        # Assumes that the name is a Symbol and that it includes just one component (no
        # underscores)!
        def name_to_unicode(name, zapf_dingbats: false)
          if zapf_dingbats && @zapf_name_to_uni.key?(name)
            @zapf_name_to_uni[name]
          elsif @standard_name_to_uni.key?(name)
            @standard_name_to_uni[name]
          else
            name = name.to_s
            if name =~ /\Auni([0-9A-F]{4})\Z/ || name =~ /\Au([0-9A-f]{4,6})\Z/
              '' << $1.hex
            else
              ''
            end
          end
        end

        # Maps the given unicode codepoint/string to a name in the Adobe Glyph List.
        #
        # If this method is invoked when dealing with the ZapfDingbats font, the +zapf_dingbats+
        # option needs to be set to +true+.
        def unicode_to_name(unicode, zapf_dingbats: false)
          zapf_dingbats ? @zapf_uni_to_name[unicode] : @standard_uni_to_name[unicode]
        end

        private

        # Loads the needed Adobe Glyph List files.
        def load
          @standard_name_to_uni, @standard_uni_to_name =
            load_file(File.join(HexaPDF.data_dir, 'encoding', 'glyphlist.txt'))
          @zapf_name_to_uni, @zapf_uni_to_name =
            load_file(File.join(HexaPDF.data_dir, 'encoding', 'zapfdingbats.txt'))
        end

        # Loads an Adobe Glyph List from the specified file and returns the name-to-unicode and
        # unicode-to-name mappings.
        #
        # Regarding the mappings:
        #
        # * The name-to-unicode mapping maps a name (Symbol) to an UTF-8 string consisting of one or
        #   more characters.
        #
        # * The unicode-to-name mapping is *not* unique! It only uses the first occurence of a
        #   unicode sequence.
        def load_file(file)
          name2uni = {}
          uni2name = {}
          File.open(file, 'rb') do |f|
            while (line = f.gets)
              next if line.start_with?('#'.freeze)
              index = line.index(';'.freeze)
              name = line[0, index].to_sym
              codes = line[index + 1, 50].split(" ".freeze).map(&:hex).pack('U*'.freeze)
              name2uni[name] = codes
              uni2name[codes] = name unless uni2name.key?(codes)
            end
          end
          [name2uni.freeze, uni2name.freeze]
        end

      end

    end
  end
end
