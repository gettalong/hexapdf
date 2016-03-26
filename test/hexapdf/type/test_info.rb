require 'test_helper'
require 'hexapdf/type/info'

describe HexaPDF::Type::Info do
  it "must always be indirect" do
    obj = HexaPDF::Type::Info.new({})
    assert(obj.must_be_indirect?)
  end

  it "uses a custom type" do
    obj = HexaPDF::Type::Info.new({})
    assert_equal(:XXInfo, obj.type)
  end
end
