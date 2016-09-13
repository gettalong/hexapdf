# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/ttf/table/cmap'

describe HexaPDF::Font::TTF::Table::Cmap do
  before do
    f0 = [0, 262, 0].pack('n3') + (0..255).to_a.pack('C*')
    data = [0, 2].pack('n2') << [[0, 1, 20],
                                 [3, 1, 20 + f0.length],
                                ].map {|a| a.pack('n2N')}.join('') << \
      f0 << f0
    io = StringIO.new(data)
    config = @config = {}
    @file = Object.new
    @file.define_singleton_method(:io) { io }
    @file.define_singleton_method(:config) { config }
    @entry = HexaPDF::Font::TTF::Table::Directory::Entry.new('cmap', 0, 0, io.length)
  end

  describe "initialize" do
    it "reads the data from the associated file" do
      table = HexaPDF::Font::TTF::Table::Cmap.new(@file, @entry)
      assert_equal(0, table.version)
      assert_equal(2, table.tables.length)
    end

    it "ignores unknown subtable when the config option is set to :ignore" do
      @file.io.string = [0, 1].pack('n2') << [3, 1, 12].pack('n2N') << "\x00\x03"
      table = HexaPDF::Font::TTF::Table::Cmap.new(@file, @entry)
      assert_equal(0, table.tables.length)
    end

    it "raises an error when an unsupported subtable is found and the option is set to :raise" do
      @file.io.string = [0, 1].pack('n2') << [3, 1, 12].pack('n2N') << "\x00\x03"
      @file.config['font.ttf.cmap.unknown_format'] = :raise
      assert_raises(HexaPDF::Error) { HexaPDF::Font::TTF::Table::Cmap.new(@file, @entry) }
    end

    it "loads some default values if no entry is given" do
      table = HexaPDF::Font::TTF::Table::Cmap.new(@file)
      assert_equal(0, table.version)
      assert_equal([], table.tables)
    end
  end

  it "returns the preferred table" do
    table = HexaPDF::Font::TTF::Table::Cmap.new(@file, @entry)
    assert_equal(table.tables[1], table.preferred_table)
  end
end
