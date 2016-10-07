# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf_wrapper'

module HexaPDF
  module FontLoader

    # This module uses the configuration option 'font.map' for loading a font.
    module FromConfiguration

      # Loads the given font by looking up the needed file in the 'font.map' configuration option.
      #
      # The file object representing the font file is *not* closed and if needed must be closed by
      # the caller once the font is not needed anymore.
      #
      # +document+::
      #     The PDF document to associate the font object with.
      #
      # +name+::
      #     The name of the font.
      #
      # +variant+::
      #     The font variant. Normally one of :none, :bold, :italic, :bold_italic.
      def self.call(document, name, variant: :none, **)
        file = document.config['font.map'].dig(name, variant)
        return nil if file.nil?

        unless File.file?(file)
          raise HexaPDF::Error, "The configured font file #{file} does not exist"
        end

        font = HexaPDF::Font::TTF::Font.new(io: File.open(file))
        HexaPDF::Font::TTFWrapper.new(document, font)
      end

    end

  end
end
