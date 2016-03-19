# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/type/trailer'
require 'hexapdf/object'
require 'hexapdf/type'

describe HexaPDF::Type::Trailer do
  before do
    @doc = Object.new
    def (@doc).deref(obj); obj; end
    def (@doc).wrap(obj, *); HexaPDF::Dictionary.new(obj, oid: (obj.oid rescue 0)); end
    root = HexaPDF::Dictionary.new({}, oid: 3)
    @obj = HexaPDF::Type::Trailer.new({Size: 10, Root: root}, document: @doc)
  end

  describe "ID field" do
    it "sets a random ID" do
      @obj.set_random_id
      assert_kind_of(Array, @obj[:ID])
      assert_equal(2, @obj[:ID].length)
      assert_same(@obj[:ID][0], @obj[:ID][1])
      assert_kind_of(String, @obj[:ID][0])
    end

    it "updates the ID field" do
      @obj.update_id
      assert_same(@obj[:ID][0], @obj[:ID][1])

      @obj.update_id
      refute_same(@obj[:ID][0], @obj[:ID][1])
    end
  end

  describe "validation" do
    it "validates and corrects a missing ID entry" do
      @obj.validate do |msg, correctable|
        assert(correctable)
        assert_match(/ID.*be set/, msg)
      end
      refute_nil(@obj[:ID])
    end

    it "validates and corrects a missing ID entry when an Encrypt dictionary is set" do
      def (@doc).security_handler;
        obj = Object.new
        def obj.encryption_key_valid?; true; end
        obj
      end
      @obj[:Encrypt] = {}
      @obj.validate do |msg, correctable|
        assert(correctable)
        assert_match(/ID.*Encrypt/, msg)
      end
      refute_nil(@obj[:ID])
    end

    it "corrects a missing Catalog entry" do
      @obj.delete(:Root)
      @obj.set_random_id
      def (@doc).add(val) HexaPDF::Object.new(val, oid: 3) end

      message = ''
      refute(@obj.validate(auto_correct: false) {|m, _| message = m})
      assert_match(/Catalog/, message)
      assert(@obj.validate)
    end

    it "fails if the Encrypt dictionary is set but no security handler is available" do
      def (@doc).security_handler; nil; end
      @obj[:Encrypt] = {}
      refute(@obj.validate)
    end

    it "fails if the Encrypt dictionary is set but the security handler's key is wrong" do
      def (@doc).security_handler
        obj = Object.new
        def obj.encryption_key_valid?; false; end
        obj
      end
      @obj[:Encrypt] = {}
      refute(@obj.validate)
    end
  end
end
