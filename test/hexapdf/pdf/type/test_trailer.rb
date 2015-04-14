# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/trailer'

describe HexaPDF::PDF::Type::Trailer do

  before do
    @doc = Object.new
    def (@doc).deref(obj); obj; end
    @obj = HexaPDF::PDF::Type::Trailer.new({Size: 10}, document: @doc)
  end

  describe "ID field" do
    it "sets a random ID" do
      @obj.set_random_id
      assert_kind_of(Array, @obj[:ID])
      assert_equal(2, @obj[:ID].length)
      assert_kind_of(String, @obj[:ID][0])
      assert_kind_of(String, @obj[:ID][1])
    end

    it "validates and corrects a missing ID entry" do
      @obj.validate do |msg, correctable|
        assert(correctable)
        assert_match(/ID.*be set/, msg)
      end
      refute_nil(@obj[:ID])
    end

    it "validates and corrects a missing ID entry when an Encrypt dictionary is set" do
      @obj[:Encrypt] = {}
      @obj.validate do |msg, correctable|
        assert(correctable)
        assert_match(/ID.*Encrypt/, msg)
      end
      refute_nil(@obj[:ID])
    end
  end

end
