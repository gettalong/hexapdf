require 'test_helper'
require 'hexapdf/type/names'

describe HexaPDF::Type::Names do
  it "uses a custom type" do
    obj = HexaPDF::Type::Names.new({})
    assert_equal(:XXNames, obj.type)
  end
end
