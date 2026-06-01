# # Text Shaping
#
# The built-in text shaping functionality is very limited. However, it is
# possible to switch to a HarfBuzz based implementation (using the
# `harfbuzz-ruby` gem) that supports many languages and scripts as well as
# OpenType features. Note that this only works with TrueType fonts!
#
# In general it is advised to use TrueType font files and enable HarfBuzz as the
# result is more correct and visually better. The disadvantage is that the
# additional processing requirements have a slight performance impact.
#
# By using the 'font_features' style property it is possible to selectively
# enable/disable OpenType features like discretionary ligatures. Note that fonts
# determine which features are on by default (like 'calt' for the Inter font
# used in this example).
#
# Usage:
# : `ruby text_shaping.rb`
#

require 'hexapdf'

sample_text = <<EOT.tr("\n", " ")
This sample shows some OpenType features, like contextual alternatives (2*3 and
-->), discretionary ligatures (difficult?!), fractions (15/157) or compositions
(5⃝ ×⃞ 3⃝ =⃞ 1⃝5⃝).
EOT

HexaPDF::Composer.create('text_shaping.pdf') do |composer|
  composer.style(:base, font: 'Inter')
  composer.style(:header, font_bold: true, margin: [10, 0, 0])
  composer.text('Without HarfBuzz', style: :header)
  composer.text(sample_text)
  composer.text('With HarfBuzz', style: :header)
  composer.text(sample_text, shaping_engine: :harfbuzz,
                font_features: {dlig: true, frac: true})
end
