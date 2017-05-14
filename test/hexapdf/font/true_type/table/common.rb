# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/true_type'

module TestHelper

  def set_up_stub_true_type_font(initial_data = ''.b)
    @font = Object.new
    @font.define_singleton_method(:io) { @io ||= StringIO.new(initial_data) }
    @font.define_singleton_method(:config) { @config ||= {} }
    @entry = HexaPDF::Font::TrueType::Table::Directory::Entry.new('mock', 0, 0, initial_data.length)
  end

  def create_table(name, data = nil)
    if data
      @font.io.string = data
      @entry.length = @font.io.length
    end
    HexaPDF::Font::TrueType::Table.const_get(name).new(@font, @entry)
  end

end
