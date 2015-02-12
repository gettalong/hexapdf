# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/xref_section'

describe HexaPDF::PDF::XRefSection do

  before do
    @xref_section = HexaPDF::PDF::XRefSection.new
  end

  describe "each_subsection" do

    def assert_subsections(result)
      assert_equal(result, @xref_section.each_subsection.map {|s| s.map(&:oid)})
    end

    it "works for newly initialized objects" do
      assert_subsections([[]])
    end

    it "works for a single subsection" do
      @xref_section.add_in_use_entry(1, 0, 0)
      @xref_section.add_in_use_entry(2, 0, 0)
      assert_subsections([[1, 2]])
    end

    it "works for multiple subsections" do
      @xref_section.add_in_use_entry(10, 0, 0)
      @xref_section.add_in_use_entry(11, 0, 0)
      @xref_section.add_in_use_entry(1, 0, 0)
      @xref_section.add_in_use_entry(2, 0, 0)
      @xref_section.add_in_use_entry(20, 0, 0)
      assert_subsections([[1, 2], [10, 11], [20]])
    end

  end

end
