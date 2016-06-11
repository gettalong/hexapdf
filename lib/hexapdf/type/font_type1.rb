# -*- encoding: utf-8 -*-

require 'hexapdf/data_dir'
require 'hexapdf/stream'
require 'hexapdf/font/encoding'
require 'hexapdf/font/type1'
require 'hexapdf/font/cmap'

module HexaPDF
  module Type

    # Represents a Type1 font.
    #
    # PDF provides 14 built-in fonts that all PDF readers must understand. These 14 fonts are
    # known as the "Standard 14 Fonts" and are all Type1 fonts. HexaPDF supports theese fonts.
    class FontType1 < Dictionary

      # Provides the names and additional mappings of the Standard 14 Fonts.
      module StandardFonts

        # The mapping from font name to Standard 14 Font name, since Adobe allows some
        # additional names for the the Standard 14 Fonts.
        #
        # See: ADB1.7 sH.5.5.1
        @mapping = {
          %s(CourierNew) => %s(Courier),
          %s(CourierNew,Italic) => %s(Courier-Oblique),
          %s(CourierNew,Bold) => %s(Courier-Bold),
          %s(CourierNew,BoldItalic) => %s(Courier-BoldOblique),
          %s(Arial) => %s(Helvetica),
          %s(Arial,Italic) => %s(Helvetica-Oblique),
          %s(Arial,Bold) => %s(Helvetica-Bold),
          %s(Arial,BoldItalic) => %s(Helvetica-BoldOblique),
          %s(TimesNewRoman) => %s(Times-Roman),
          %s(TimesNewRoman,Italic) => %s(Times-Italic),
          %s(TimesNewRoman,Bold) => %s(Times-Bold),
          %s(TimesNewRoman,BoldItalic) => %s(Times-BoldItalic),
        }
        %i(Times-Roman Times-Bold Times-Italic Times-BoldItalic
           Helvetica Helvetica-Bold Helvetica-Oblique Helvetica-BoldOblique
           Courier Courier-Bold Courier-Oblique Courier-BoldOblique
           Symbol ZapfDingbats).each {|name| @mapping[name] = name}

        # Returns +true+ if the given name is the name of a standard font.
        def self.standard_font?(name)
          @mapping.include?(name)
        end

        # Returns the standard name of the font in case an additional name is used, or +nil+ if
        # the given name doesn't belong to a standard font.
        def self.standard_name(name)
          @mapping[name]
        end

        @cache = {}

        # Returns the Type1 font object for the given standard font name, or +nil+ if the given name
        # doesn't belong to a standard font.
        def self.font(name)
          name = @mapping[name]
          if !standard_font?(name)
            nil
          elsif @cache.key?(name)
            @cache[name]
          else
            file = File.join(HexaPDF.data_dir, 'afm', "#{name}.afm")
            @cache[name] = HexaPDF::Font::Type1::Font.from_afm(file)
          end
        end

      end

      define_field :Type, type: Symbol, required: true, default: :Font
      define_field :Subtype, type: Symbol, required: true, default: :Type1
      define_field :BaseFont, type: Symbol, required: true
      define_field :FirstChar, type: Integer
      define_field :LastChar, type: Integer
      define_field :Widths, type: Array
      define_field :FontDescriptor, type: :FontDescriptor, indirect: true
      define_field :Encoding, type: [Symbol, Dictionary]
      define_field :ToUnicode, type: Stream, version: '1.2'

      # Returns the encoding object used for this font.
      #
      # Note that the encoding is cached internally when accessed the first time.
      def encoding
        @encoding ||=
          begin
            case (val = self[:Encoding])
            when Symbol
              encoding = HexaPDF::Font::Encoding.for_name(val)
              encoding = encoding_from_font if encoding.nil?
              encoding
            when HexaPDF::Dictionary, Hash
              encoding = val[:BaseEncoding]
              encoding = HexaPDF::Font::Encoding.for_name(encoding) if encoding
              unless encoding
                if embedded? || symbolic?
                  encoding = encoding_from_font
                else
                  encoding = HexaPDF::Font::Encoding.for_name(:StandardEncoding)
                end
              end
              encoding = difference_encoding(encoding, val[:Differences]) if val.key?(:Differences)
              encoding
            when nil
              encoding_from_font
            else
              raise HexaPDF::Error, "Unknown value for font's encoding: #{self[:Encoding]}"
            end
          end
      end

      # Decodes the given string into an array of code points.
      def decode(string)
        string.unpack('C*'.freeze)
      end

      # Returns the UTF-8 string for the given code point.
      def to_utf8(code)
        if to_unicode_cmap
          to_unicode_cmap.to_unicode(code)
        elsif (name = encoding.name(code)) != :'.notdef'
          zapf_dingbats = (self[:BaseFont] == :ZapfDingbats)
          HexaPDF::Font::Encoding::GlyphList.new.name_to_unicode(name, zapf_dingbats: zapf_dingbats)
        else
          ''
        end
      end

      # Returns the writing mode which is always :horizontal for simple fonts like Type1.
      def writing_mode
        :horizontal
      end

      # Returns the unscaled width of the given code point in glyph units, or +0+ if the width for
      # the code point is not specified.
      def width(code)
        widths = self[:Widths]
        first_char = self[:FirstChar] || -1
        last_char = self[:LastChar] || -1

        if widths && code >= first_char && code <= last_char
          widths[code - first_char]
        elsif widths && key?(:FontDescriptor)
          self[:FontDescriptor][:MissingWidth]
        elsif StandardFonts.standard_font?(self[:BaseFont])
          StandardFonts.font(self[:BaseFont]).width(encoding.name(code)) || 0
        else
          raise HexaPDF::Error, "No valid glyph width information available"
        end
      end

      # Returns the bounding box of the font or raises an error if it is not found.
      def bounding_box
        if key?(:FontDescriptor) && value[:FontDescriptor].key?(:FontBBox)
          self[:FontDescriptor][:FontBBox].value
        elsif StandardFonts.standard_font?(self[:BaseFont])
          StandardFonts.font(self[:BaseFont]).bounding_box
        else
          raise HexaPDF::Error, "No bounding box information for font #{self} found"
        end
      end

      # Returns +true+ if the font is embedded.
      def embedded?
        dict = self[:FontDescriptor]
        dict && (dict[:FontFile] || dict[:FontFile2] || dict[:FontFile3])
      end

      # Returns +true+ if the font is a symbolic font, +false+ if it is not, and +nil+ if it is
      # not known.
      def symbolic?
        symbolic = self[:FontDescriptor] && self[:FontDescriptor].flagged?(:symbolic) || nil
        if !symbolic.nil?
          symbolic
        elsif StandardFonts.standard_font?(self[:BaseFont])
          name = StandardFonts.standard_name(self[:BaseFont])
          name == :ZapfDingbats || name == :Symbol
        else
          nil
        end
      end

      private

      # Tries to read the encoding from the embedded font.
      def encoding_from_font
        if StandardFonts.standard_font?(self[:BaseFont])
          StandardFonts.font(self[:BaseFont]).encoding
        elsif (obj = self[:FontDescriptor][:FontFile])
          HexaPDF::Font::Type1::PFBParser.encoding(obj.stream)
        else
          raise HexaPDF::Error, "Can't read encoding because Type1 font is not embedded"
        end
      end

      # Uses the given base encoding and the differences array to create a DifferenceEncoding
      # object.
      def difference_encoding(base_encoding, differences)
        unless differences[0].kind_of?(Integer)
          raise HexaPDF::Error, "Invalid /Differences array in Encoding dict"
        end

        encoding = HexaPDF::Font::Encoding::DifferenceEncoding.new(base_encoding)
        code = nil
        differences.each do |entry|
          case entry
          when Symbol
            encoding.code_to_name[code] = entry
            code += 1
          when Integer
            code = entry
          else
            raise HexaPDF::Error, "Invalid /Differences array in Encoding dict"
          end
        end
        encoding
      end

      # Parses and caches the ToUnicode CMap.
      def to_unicode_cmap
        @to_unicode_cmap ||= if key?(:ToUnicode)
                               HexaPDF::Font::CMap.parse(self[:ToUnicode].stream)
                             else
                               nil
                             end
      end

      # Validates the Type1 font dictionary.
      def perform_validation
        super
        return if StandardFonts.standard_font?(self[:BaseFont])

        [:FirstChar, :LastChar, :Widths, :FontDescriptor].each do |field|
          yield("Required field #{field} is not set", false) if self[field].nil?
        end
        if self[:Widths].length != (self[:LastChar] - self[:FirstChar] + 1)
          yield("Invalid number of entries in field Widths", false)
        end
      end

    end

  end
end
