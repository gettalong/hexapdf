# -*- encoding: utf-8 -*-

module HexaPDF

  # == Overview
  #
  # The Content module contains everything related to working with page content streams.
  module Content

    autoload(:Canvas, 'hexapdf/content/canvas')
    autoload(:Parser, 'hexapdf/content/parser')
    autoload(:Processor, 'hexapdf/content/processor')

  end

end
