require 'test_helper'
require 'hexapdf/type/embedded_file'

describe HexaPDF::Type::EmbeddedFile::MacInfo do
  it "uses a custom type" do
    obj = HexaPDF::Type::EmbeddedFile::MacInfo.new({})
    assert_equal(:XXEmbeddedFileParametersMacInfo, obj.type)
  end
end

describe HexaPDF::Type::EmbeddedFile::Parameters do
  it "uses a custom type" do
    obj = HexaPDF::Type::EmbeddedFile::Parameters.new({})
    assert_equal(:XXEmbeddedFileParameters, obj.type)
  end
end
