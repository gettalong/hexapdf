# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/object'

describe HexaPDF::PDF::Object do

  describe "validation" do
    it "allows adding and retrieving class level validators for instance methods" do
      klass = Class.new(HexaPDF::PDF::Object)
      klass.define_validator(:validate_me)
      assert_equal([:validate_me], klass.each_validator.to_a)
    end

    it "allows adding and retrieving arbitrary class level validators" do
      klass = Class.new(HexaPDF::PDF::Object)
      validate_me = lambda {|obj, auto_correct:|}
      klass.define_validator(&validate_me)
      assert_equal([validate_me], klass.each_validator.to_a)
    end

    it "uses validators defined for the class or one of its superclasses" do
      klass = Class.new(HexaPDF::PDF::Object)
      klass.define_validator(:validate_me)
      subklass = Class.new(klass)
      subklass.define_validator(:validate_me_too)
      assert_equal([:validate_me, :validate_me_too], subklass.each_validator.to_a)
    end

    it "invokes the validators correctly via #validate" do
      invoked = {}
      klass = Class.new(HexaPDF::PDF::Object)
      klass.send(:define_method, :validate_me) do |&block|
        invoked[:method] = true
        block.call("error", true)
      end
      klass.define_validator(:validate_me)
      klass.define_validator do |obj|
        assert_kind_of(HexaPDF::PDF::Object, obj)
        invoked[:block] = true
      end
      assert(klass.new(:test).validate)
      assert_equal({method: true, block: true}, invoked)

      invoked = {}
      refute(klass.new(:test).validate(auto_correct: false))
      assert_equal({method: true}, invoked)

      invoked = {}
      klass.send(:undef_method, :validate_me)
      klass.send(:define_method, :validate_me) do |&block|
        invoked[:klass] = true
        block.call("error", false)
      end
      refute(klass.new(:test).validate(auto_correct: true))
      assert_equal({klass: true}, invoked)
    end
  end

end
