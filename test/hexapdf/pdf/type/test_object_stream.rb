# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/type/object_stream'

describe HexaPDF::PDF::Type::ObjectStream::Data do

  before do
    @data = HexaPDF::PDF::Type::ObjectStream::Data.new("5 [1 2]", [1, 5], [0, 2])
  end

  it "returns the correct [object, oid] pair for a given index" do
    assert_equal([5, 1], @data.object_by_index(0))
    assert_equal([[1, 2], 5], @data.object_by_index(1))
  end

  it "fails if the index is out of bounds" do
    assert_raises(HexaPDF::Error) { @data.object_by_index(5) }
    assert_raises(HexaPDF::Error) { @data.object_by_index(-1) }
  end

end


describe HexaPDF::PDF::Type::ObjectStream do

  before do
    @obj = HexaPDF::PDF::Type::ObjectStream.new({})
  end

  it "correctly parses stream data" do
    @obj.value = {N: 2, First: 8}
    @obj.stream = "1 0 5 2 5 [1 2]"
    data = @obj.parse_stream
    assert_equal([5, 1], data.object_by_index(0))
    assert_equal([[1, 2], 5], data.object_by_index(1))
  end

  it "allows adding and deleting object as well as determining their index" do
    @obj.add_object(5)
    @obj.add_object(7)
    @obj.add_object(9)
    assert_equal(0, @obj.object_index(5))
    assert_equal(1, @obj.object_index(7))
    assert_equal(2, @obj.object_index(9))

    @obj.delete_object(5)
    assert_equal(0, @obj.object_index(9))
    assert_equal(1, @obj.object_index(7))
    assert_equal(nil, @obj.object_index(5))

    @obj.delete_object(7)
    @obj.delete_object(9)
    assert_equal(nil, @obj.object_index(5))
  end

  it "allows writing the objects to the stream" do
    @obj.stream = 'something'
    @obj.add_object(HexaPDF::PDF::Object.new(5, oid: 1))
    @obj.add_object(HexaPDF::PDF::Object.new(:will_be_deleted, oid: 3, gen: 1))
    @obj.add_object(HexaPDF::PDF::Object.new([1, 2], oid: 5))
    @obj.add_object(HexaPDF::PDF::Object.new(nil, oid: 7))

    revision = Object.new
    def revision.object(obj); obj; end
    @obj.write_objects(revision)

    assert_equal(2, @obj.value[:N])
    assert_equal(8, @obj.value[:First])
    assert_equal("1 0 5 2 5 [1 2] ", @obj.stream)
  end

end
