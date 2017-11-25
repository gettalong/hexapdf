# -*- encoding: utf-8 -*-

require 'hexapdf/font/true_type/table'

module TestHelper

  class TrueTypeTestTable < HexaPDF::Font::TrueType::Table

    attr_reader :data

    def parse_table
      @data = io.read(directory_entry.length)
    end

  end

end
