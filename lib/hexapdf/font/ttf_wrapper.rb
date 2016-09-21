# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf'
require 'hexapdf/font/cmap'
require 'hexapdf/error'

module HexaPDF
  module Font

    # This class wraps a generic TrueType font object and provides the methods needed for working
    # with the font in a PDF context.
    #
    # TrueType fonts can be represented in two ways in PDF: As a simple font with Subtype TrueType
    # or as a composite font using a Type2 CIDFont. The wrapper only supports the composite font
    # case because:
    #
    # * By using a composite font more than 256 characters can be encoded with one font object.
    # * Fonts for vertical writing can potentially be used.
    # * The PDF specification recommends using a composite font (see PDF1.7 s9.9 at the end).
    #
    # Additionally, TrueType fonts are *always* embedded.
    class TTFWrapper

      # Represents a single glyph of the wrapped font.
      class Glyph

        # The glyph ID.
        attr_reader :id

        # Creates a new Glyph object.
        def initialize(font, id)
          @font = font
          @id = id
        end

        # Returns the width of the glyph.
        def width
          @width ||= @font[:hmtx][id].advance_width * 1000.0 / @font[:head].units_per_em
        end

        # Returns +true+ if the glyph represents the space character.
        def space?
          # Accoding to http://scripts.sil.org/iws-chapter08 and
          # https://www.microsoft.com/typography/otspec/recom.htm
          @id == 3
        end

      end

      private_constant :Glyph


      # Returns the wrapped TrueType font object.
      attr_reader :wrapped_font

      # Creates a new object wrapping the TrueType font for the PDF document.
      def initialize(document, font)
        @document = document
        @wrapped_font = font

        @cmap = font[:cmap].preferred_table
        if @cmap.nil?
          raise HexaPDF::Error, "No mapping table for Unicode characters found for TTF " \
            "font #{font.full_name}"
        end
        @font_dict = build_font_dict
        @document.register_listener(:complete_objects, &method(:complete_font_dict))

        @id_to_glyph = {}
        @codepoint_to_glyph = {}
        @encoded_glyphs = {}
      end

      # Returns a Glyph object for the given glyph ID.
      #
      # Note: Although this method is public, it should normally not be used by application code!
      def glyph(id)
        @id_to_glyph[id] ||=
          begin
            if id < 0 || id >= @wrapped_font[:maxp].num_glyphs
              id = @document.config['font.on_missing_glyph'].call(0xFFFD, @wrapped_font)
            end
            Glyph.new(@wrapped_font, id)
          end
      end

      # Returns an array of glyph objects representing the characters in the UTF-8 encoded string.
      def decode_utf8(str)
        str.each_codepoint.map do |c|
          @codepoint_to_glyph[c] ||=
            begin
              gid = @cmap[c] || @document.config['font.on_missing_glyph'].call(c, @wrapped_font)
              glyph(gid)
            end
        end
      end

      # Encodes the glyph and returns the used PDF font dictionary and the code string.
      def encode(glyph)
        @encoded_glyphs[glyph] ||= [@font_dict, [glyph.id].pack('n')]
      end

      private

      # Builds a Type0 font object representing the TrueType font.
      #
      # The returned font object contains only information available at build time, so no
      # information about glyph specific attributes like width.
      #
      # See: #complete_font_dict
      def build_font_dict
        scaling = 1000.0 / @wrapped_font[:head].units_per_em

        embedded_font = @document.add({Length1: @wrapped_font.io.size},
                                      stream: HexaPDF::StreamData.new(@wrapped_font.io))
        fd = @document.add(Type: :FontDescriptor,
                           FontName: @wrapped_font.font_name.intern,
                           FontWeight: @wrapped_font.weight,
                           Flags: 0,
                           FontBBox: @wrapped_font.bounding_box.map {|m| m * scaling},
                           ItalicAngle: @wrapped_font.italic_angle || 0,
                           Ascent: @wrapped_font.ascender * scaling,
                           Descent: @wrapped_font.descender * scaling,
                           StemV: @wrapped_font.dominant_vertical_stem_width,
                           FontFile2: embedded_font)
        if @wrapped_font[:'OS/2'].version >= 2
          fd[:CapHeight] = @wrapped_font.cap_height * scaling
          fd[:XHeight] = @wrapped_font.x_height * scaling
        else # estimate values
          # Estimate as per https://www.microsoft.com/typography/otspec/os2.htm#ch
          fd[:CapHeight] = if @cmap[0x0048] # H
                             @wrapped_font[:glyf][@cmap[0x0048]].y_max * scaling
                           else
                             @wrapped_font.ascender * 0.8 * scaling
                           end
          # Estimate as per https://www.microsoft.com/typography/otspec/os2.htm#xh
          fd[:XHeight] = if @cmap[0x0078] # x
                           @wrapped_font[:glyf][@cmap[0x0078]].y_max * scaling
                         else
                           @wrapped_font.ascender * 0.5 * scaling
                         end
        end

        fd.flag(:fixed_pitch) if @wrapped_font[:post].is_fixed_pitch? ||
          @wrapped_font[:hhea].num_of_long_hor_metrics == 1
        fd.flag(:italic) if @wrapped_font[:'OS/2'].selection_include?(:italic) ||
          @wrapped_font[:'OS/2'].selection_include?(:oblique)
        fd.flag(:symbolic)

        cid_font = @document.add(Type: :Font, Subtype: :CIDFontType2,
                                 BaseFont: @wrapped_font.font_name.intern, FontDescriptor: fd,
                                 CIDSystemInfo: {Registry: "Adobe", Ordering: "Identity",
                                                 Supplement: 0},
                                 CIDToGIDMap: :Identity)
        @document.add(Type: :Font, Subtype: :Type0, BaseFont: cid_font[:BaseFont],
                      Encoding: :"Identity-H", DescendantFonts: [cid_font])
      end

      # Makes sure that the Type0 font object as well as the CIDFont object contain all the needed
      # information.
      def complete_font_dict
        complete_width_information
        create_to_unicode_cmap
      end

      # Adds the /DW and /W fields to the CIDFont dictionary.
      def complete_width_information
        cid_font = @font_dict[:DescendantFonts].first
        cid_font[:DW] = default_width = glyph(3).width

        glyphs = @encoded_glyphs.keys.reject {|g| g.width == default_width}.sort_by(&:id)
        if glyphs.length > 0
          cid_font[:W] = widths = []
          last_id = -10
          cur_widths = nil
          glyphs.each do |glyph|
            gid = glyph.id
            if last_id + 1 != gid
              cur_widths = []
              widths << gid << cur_widths
            end
            cur_widths << glyph.width
            last_id = gid
          end
        end
      end

      # Creates the /ToUnicode CMap and updates the font dictionary so that text extraction works
      # correctly.
      def create_to_unicode_cmap
        stream = HexaPDF::StreamData.new do
          mapping = @encoded_glyphs.keys.sort_by(&:id).map do |glyph|
            # Using 0xFFFD as mentioned in Adobe #5411, last line before section 1.5
            [glyph.id, @cmap.gid_to_code(glyph.id) || 0xFFFD]
          end
          HexaPDF::Font::CMap.create_to_unicode_cmap(mapping)
        end
        stream_obj = @document.add({}, stream: stream)
        stream_obj.set_filter(:FlateDecode)
        @font_dict[:ToUnicode] = stream_obj
      end

    end

  end
end
