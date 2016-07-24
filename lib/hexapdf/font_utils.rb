# -*- encoding: utf-8 -*-

require 'hexapdf/configuration'
require 'hexapdf/font_loader'

module HexaPDF

  # This class provides utility functions for working with fonts. It is available through the
  # Document#fonts method.
  class FontUtils

    # Creates a new FontUtils object for the given PDF document.
    def initialize(document)
      @document = document
      @loaded_fonts_cache = {}
    end

    # :call-seq:
    #   fonts.load(name, **options)            -> font
    #
    # Loads and returns the font (using the loaders specified with the configuration option
    # 'font_loaders').
    #
    # If a font with the same parameters has been loaded before, the cached font object is used.
    def load(name, **options)
      font = @loaded_fonts_cache[[name, options]]
      return font if font

      each_font_loader do |loader|
        font = loader.call(@document, name, **options)
        break if font
      end

      @loaded_fonts_cache[[name, options]] = font if font
      font
    end

    private

    # :call-seq:
    #   fonts.each_font_loader {|loader| block}
    #
    # Iterates over all configured font loaders.
    def each_font_loader
      @document.config['font_loader'].each_index do |index|
        loader = @document.config.constantize('font_loader', index) do
          raise HexaPDF::Error, "Couldn't retrieve font loader ##{index} from configuration"
        end
        yield(loader)
      end
    end

  end

end
