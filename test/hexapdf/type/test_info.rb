require 'test_helper'
require 'hexapdf/type/info'

describe HexaPDF::Type::Info do
  it "uses a custom type" do
    obj = HexaPDF::Type::Info.new({})
    assert_equal(:XXInfo, obj.type)
  end
end
