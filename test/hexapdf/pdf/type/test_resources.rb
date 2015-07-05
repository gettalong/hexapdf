# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/resources'

describe HexaPDF::PDF::Type::Resources do
  describe "validation" do
    it "assigns the default value if ProcSet is not set" do
      res = HexaPDF::PDF::Type::Resources.new({})
      res.validate
      assert_equal([:PDF, :Text, :ImageB, :ImageC, :ImageI], res[:ProcSet])
    end

    it "removes invalid procedure set names from ProcSet" do
      res = HexaPDF::PDF::Type::Resources.new({})
      res[:ProcSet] = [:PDF, :Unknown]
      res.validate
      assert_equal([:PDF], res[:ProcSet])
    end
  end
end
