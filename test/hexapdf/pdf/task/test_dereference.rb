# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/task/dereference'

describe HexaPDF::PDF::Task::Dereference do

  before do
    @doc = HexaPDF::PDF::Document.new(io: StringIO.new(MINIMAL_PDF))
  end

  it "dereferences all references to objects" do
    obj = @doc.add(:test)
    checker = lambda do |val, done = {}|
      case val
      when Array then val.all? {|v| checker.call(v, done)}
      when Hash then val.all? {|k, v| checker.call(v, done)}
      when HexaPDF::PDF::Reference
        false
      when HexaPDF::PDF::Object
        if done.key?(val)
          true
        else
          done[val] = true if val.oid != 0
          checker.call(val.value, done)
        end
      else
        true
      end
    end
    refute(checker.call(@doc.trailer))
    assert_equal([obj], @doc.task(:dereference))
    assert(checker.call(@doc.trailer))
    assert_equal([obj], @doc.task(:dereference))
    assert(checker.call(@doc.trailer))
  end

  it "dereferences only a single object" do
    assert(@doc.object(5).value[:Font][:F1].kind_of?(HexaPDF::PDF::Reference))
    assert_nil(@doc.task(:dereference, object: @doc.object(5)))
    refute(@doc.object(5).value[:Font][:F1].kind_of?(HexaPDF::PDF::Reference))
  end

end
