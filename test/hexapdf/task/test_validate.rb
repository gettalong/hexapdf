# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/task/validate'

describe HexaPDF::Task::Validate do
  before do
    @doc = HexaPDF::Document.new
    @doc.trailer.validate # to create a valid document
  end

  it "validates indirect objects" do
    obj = @doc.add(Type: :XRef, Size: 100)
    assert(@doc.task(:validate, auto_correct: false))

    obj.delete(:Type)
    called = false
    assert(@doc.task(:validate) { called = true })
    assert(called)
  end

  it "validates the trailer object" do
    @doc.trailer[:ID] = :Symbol
    refute(@doc.task(:validate))
  end

  it "validates that the encryption key matches the trailer's Encrypt dictionary" do
    @doc.security_handler.set_up_encryption
    @doc.trailer[:Encrypt][:U] = 'a'.b * 32
    valid = @doc.task(:validate) do |msg, _|
      assert_match(/Encryption key/, msg)
    end
    refute(valid)
  end
end
