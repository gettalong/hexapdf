# -*- encoding: utf-8 -*-

require 'hexapdf/font/type1'
require 'hexapdf/font/encoding'
require 'hexapdf/error'

module HexaPDF
  module Font

    # This class wraps a generic Type1 font object and provides the methods needed for working with
    # the font in a PDF context.
    class Type1Wrapper

      # Represents a single glyph of the wrapped font.
      class Glyph

        # The name of the glyph.
        attr_reader :name
        alias_method :id, :name

        # Creates a new Glyph object.
        def initialize(font, name)
          @font = font
          @name = name
        end

        # Returns the width of the glyph.
        def width
          @width ||= @font.width(name)
        end

        # Returns +true+ if the glyph represents the space character.
        def space?
          @name == :space
        end

      end

      private_constant :Glyph


      # Represents a font encoding variant.
      #
      # This is similar to how font subsets work but in this case the same font is always used with
      # different encodings.
      class FontVariant

        # The PDF font dictionary for this variant.
        attr_reader :dict

        # Creates a new variant for the given font dictionary and the optionally given encoding.
        def initialize(dict, encoding: nil)
          @dict = dict
          if encoding
            @encoding = encoding
            @max_code = 255 # given encodings are not modified
          else
            @encoding = Encoding::Base.new
            @encoding.code_to_name[32] = :space
            @max_code = 32 # 32 = space
          end
        end

        # Encodes the glyph using the encoding of this variant and returns the resulting single byte
        # code.
        #
        # If there is no valid encoding for the given glyph but still space left in the encoding, a
        # new code to glyph mapping is automatically added to the encoding. Otherwise +nil+ is
        # returned.
        def encode(glyph)
          code = @encoding.code_to_name.key(glyph.name)
          if code
            code.chr.freeze
          elsif @max_code < 255
            @max_code += 1
            @encoding.code_to_name[@max_code] = glyph.name
            @max_code.chr.freeze
          else
            nil
          end
        end

        # Array of valid encoding names in PDF
        VALID_ENCODING_NAMES = [:WinAnsiEncoding, :MacRomanEncoding, :MacExpertEncoding]

        # Completes the font dictionary by filling in the values that depend on the used encoding.
        def complete_dict(wrapper)
          min, max = @encoding.code_to_name.keys.minmax
          @dict[:FirstChar] = min
          @dict[:LastChar] = max
          @dict[:Widths] = (min..max).map {|code| wrapper.glyph(@encoding.name(code)).width}

          if VALID_ENCODING_NAMES.include?(@encoding.encoding_name)
            @dict[:Encoding] = @encoding.encoding_name
          else
            differences = [min]
            (min..max).each {|code| differences << @encoding.name(code)}
            @dict[:Encoding] = {Differences: differences}
          end
        end

      end

      private_constant :FontVariant


      # Returns the wrapped Type1 font object.
      attr_reader :wrapped_font

      # Creates a new object wrapping the Type1 font for the PDF document.
      def initialize(document, font)
        @document = document
        @wrapped_font = font

        enc = (@wrapped_font.metrics.character_set == 'Special' ? nil :
               Encoding.for_name(:WinAnsiEncoding))
        @variants = [FontVariant.new(build_font_dict, encoding: enc)]
        @document.register_listener(:complete_objects) do
          @variants.each {|variant| variant.complete_dict(self)}
        end

        @zapf_dingbats_opt = {zapf_dingbats: (@wrapped_font.font_name == 'ZapfDingbats')}
        @name_to_glyph = {}
        @codepoint_to_glyph = {}
        @encoded_glyphs = {}
      end

      # Returns a Glyph object for the given glyph name.
      def glyph(name)
        @name_to_glyph[name] ||=
          begin
            unless @wrapped_font.metrics.character_metrics.key?(name)
              name = @document.config['font.on_missing_glyph'].call(name, @wrapped_font)
            end
            Glyph.new(@wrapped_font, name)
          end
      end

      # Returns an array of glyph objects representing the characters in the UTF-8 encoded string.
      def decode_utf8(str)
        str.each_codepoint.map do |c|
          @codepoint_to_glyph[c] ||=
            begin
              name = Encoding::GlyphList.unicode_to_name('' << c, @zapf_dingbats_opt)
              name = '' << c if name == :'.notdef'
              glyph(name)
            end
        end
      end

      # Encodes the glyph and returns the used PDF font dictionary and the code string.
      def encode(glyph)
        @encoded_glyphs[glyph.name] ||=
          begin
            result = nil
            @variants.each do |variant|
              code = variant.encode(glyph)
              (result = [variant.dict, code]) && break if code
            end
            unless result
              variant = FontVariant.new(build_font_dict)
              @variants << variant
              result = [variant.dict, variant.encode(glyph)]
            end
            result
          end
      end

      private

      # Builds a generic Type1 font dictionary for the wrapped font.
      #
      # Generic in the sense that no information regarding the encoding or widths is included.
      def build_font_dict
        unless defined?(@fd)
          @fd = @document.wrap(Type: :FontDescriptor,
                               FontName: @wrapped_font.font_name.intern,
                               FontBBox: @wrapped_font.bounding_box,
                               ItalicAngle: @wrapped_font.italic_angle || 0,
                               Ascent: @wrapped_font.ascender || 0,
                               Descent: @wrapped_font.descender || 0,
                               CapHeight: @wrapped_font.cap_height,
                               XHeight: @wrapped_font.x_height,
                               StemH: @wrapped_font.dominant_horizontal_stem_width,
                               StemV: @wrapped_font.dominant_vertical_stem_width || 0)
          @fd.flag(:fixed_pitch) if @wrapped_font.metrics.is_fixed_pitch
          @fd.flag(@wrapped_font.metrics.character_set == 'Special' ? :symbolic : :nonsymbolic)
          @fd.must_be_indirect = true
        end

        @document.wrap(Type: :Font, Subtype: :Type1,
                       BaseFont: @wrapped_font.font_name.intern, Encoding: :WinAnsiEncoding,
                       FontDescriptor: @fd)
      end

    end

  end
end
