# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/importer'
require 'hexapdf/document'

describe HexaPDF::Importer::NullableWeakRef do
  it "returns nil instead of an error when the referred-to object is GCed" do
    refs = []
    obj = nil
    100.times do
      refs << HexaPDF::Importer::NullableWeakRef.new(Object.new)
      ObjectSpace.garbage_collect
      ObjectSpace.garbage_collect
      break if (obj = refs.find {|ref| !ref.weakref_alive? })
    end
    assert_equal("", obj.to_s)
  end
end

describe HexaPDF::Importer do
  before do
    @source = HexaPDF::Document.new
    obj = @source.add("test")
    @hash = @source.wrap({key: "value"})
    @obj = @source.add({hash: @hash, array: ["one", "two"],
                        ref: HexaPDF::Reference.new(obj.oid, obj.gen),
                        others: [:symbol, 5, 5.5, nil, true, false]})
    @source.pages.add
    @source.pages.root[:Rotate] = 90
    @dest = HexaPDF::Document.new
    @importer = HexaPDF::Importer.for(source: @source, destination: @dest)
  end

  describe "::for" do
    it "caches the importer" do
      assert_same(@importer, HexaPDF::Importer.for(source: @source, destination: @dest))
    end
  end

  describe "import" do
    it "updates the associated document" do
      obj = @importer.import(@obj)
      assert_same(obj.document, @dest)
      obj = @importer.import(@hash)
      assert_same(obj.document, @dest)
    end

    it "imports an object only once" do
      obj = @importer.import(@obj)
      assert_same(obj, @importer.import(@obj))
      assert_equal(2, @dest.each.to_a.size)
    end

    it "re-imports an object that was imported but then deleted" do
      obj = @importer.import(@obj)
      @dest.delete(obj)
      refute_same(obj, @importer.import(@obj))
    end

    it "can import a direct object" do
      obj = @importer.import(key: @obj)
      assert(@dest.object?(obj[:key]))
    end

    it "copies the data of the imported objects" do
      data = {key: @obj, str: "str"}
      obj = @importer.import(data)
      obj[:str].upcase!
      obj[:key][:hash][:key].upcase!
      obj[:key][:hash][:data] = :value
      obj[:key][:array].unshift
      obj[:key][:array][0].upcase!

      assert_equal("str", data[:str])
      assert_equal("value", @obj[:hash][:key])
      assert_equal(["one", "two"], @obj[:array])
    end

    it "duplicates the stream if it is a string" do
      src_obj = @source.add({}, stream: 'data')
      dst_obj = @importer.import(src_obj)
      refute_same(dst_obj.data.stream, src_obj.data.stream)
    end

    it "does not import objects of type Catalog or Pages" do
      @obj[:catalog] = @source.catalog
      @obj[:pages] = @source.catalog.pages
      obj = @importer.import(@obj)

      assert_nil(obj[:catalog])
      assert_nil(obj[:pages])
    end

    it "imports Page objects correctly by copying the inherited values" do
      page = @importer.import(@source.pages[0])
      assert_equal(90, page[:Rotate])
    end

    it "raise an error if the given object doesn't belong to the source document" do
      other_doc = HexaPDF::Document.new
      other_obj = other_doc.add("test")
      assert_raises(HexaPDF::Error) { @importer.import(other_obj) }
    end
  end
end
