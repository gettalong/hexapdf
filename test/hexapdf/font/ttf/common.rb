# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module TestHelper

  class TTFTestTable < HexaPDF::Font::TTF::Table
    attr_reader :data

    def parse_table
      @data = io.read(directory_entry.length)
    end

    def load_default
      @data = 'default'
    end
  end

end
