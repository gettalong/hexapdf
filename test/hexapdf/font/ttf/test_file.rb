# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/ttf/file'
require_relative 'common'

describe HexaPDF::Font::TTF::File do
  before do
    @io = StringIO.new("TEST\x00\x01\x00\x00\x00\x00\x00\x00" \
                       "TEST----\x00\x00\x00\x1C\x00\x00\x00\x05ENTRY".b)
    @file = HexaPDF::Font::TTF::File.new(@io)
    @file.config['font.ttf.table_mapping'][:TEST] = TestHelper::TTFTestTable.name
  end

  describe "table" do
    it "returns a named table" do
      table = @file.table(:TEST)
      assert_equal('ENTRY', table.data)
    end

    it "always returns the same table instance" do
      assert_same(@file.table(:TEST), @file.table(:TEST))
    end

    it "returns a generic table if no mapping exists" do
      @file.config['font.ttf.table_mapping'].delete(:TEST)
      assert_kind_of(HexaPDF::Font::TTF::Table, @file.table(:TEST))
    end

    it "returns nil if the named table doesn't exist in the file" do
      assert_nil(@file.table(:OTHE))
    end
  end
end
