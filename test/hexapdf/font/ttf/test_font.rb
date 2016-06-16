# -*- encoding: utf-8 -*-

require 'test_helper'
require 'stringio'
require 'hexapdf/font/ttf/font'
require_relative 'common'

describe HexaPDF::Font::TTF::Font do
  before do
    @io = StringIO.new("TEST\x00\x01\x00\x00\x00\x00\x00\x00" \
                       "TEST----\x00\x00\x00\x1C\x00\x00\x00\x05ENTRY".b)
    @font = HexaPDF::Font::TTF::Font.new(io: @io)
    @font.config['font.ttf.table_mapping'][:TEST] = TestHelper::TTFTestTable.name
  end

  describe "[]" do
    it "returns a named table" do
      table = @font[:TEST]
      assert_equal('ENTRY', table.data)
    end

    it "always returns the same table instance" do
      assert_same(@font[:TEST], @font[:TEST])
    end

    it "returns a generic table if no mapping exists" do
      @font.config['font.ttf.table_mapping'].delete(:TEST)
      assert_kind_of(HexaPDF::Font::TTF::Table, @font[:TEST])
    end

    it "returns nil if the named table doesn't exist in the file" do
      assert_nil(@font[:OTHE])
    end
  end
end
