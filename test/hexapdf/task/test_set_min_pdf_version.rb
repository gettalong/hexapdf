# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/task/set_min_pdf_version'

describe HexaPDF::Task::SetMinPDFVersion do
  before do
    @doc = HexaPDF::Document.new(io: StringIO.new(MINIMAL_PDF))
  end

  it "updates the PDF version of the document if needed" do
    assert_equal('1.2', @doc.version)
    @doc.task(:set_min_pdf_version)
    assert_equal('1.2', @doc.version)

    @doc.security_handler = HexaPDF::Encryption::SecurityHandler.set_up_encryption(@doc, :Standard, algorithm: :aes)
    @doc.task(:set_min_pdf_version)
    assert_equal('1.6', @doc.version)
  end
end
