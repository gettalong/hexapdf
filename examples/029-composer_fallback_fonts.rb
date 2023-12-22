# # Composer - Fallback Fonts
#
# This example shows how to use the fallback font support of HexaPDF to replace
# invalid glyphs with ones from other fonts.
#
# While the examples shows the usage of a single fallback font, it can easily be
# generalized to support multiple fallback fonts.
#
# Usage:
# : `ruby composer_fallback_fonts.rb`
#

require 'hexapdf'

HexaPDF::Composer.create('composer_fallback_fonts.pdf') do |composer|
  zapf_dingbats = composer.document.fonts.add('ZapfDingbats')
  composer.document.config['font.on_invalid_glyph'] = lambda do |codepoint, invalid_glyph|
    [zapf_dingbats.decode_codepoint(codepoint)]
  end
  composer.text('This text contains the scissors symbol ✂ which is not available in ' \
                'the default font Times but available in the set ZapfDingbats fallback ' \
                'font. Other symbols from ZapfDingbats like ✐ and ✈ can also be used.' \
                "\n\n❤ HexaPDF")
end
